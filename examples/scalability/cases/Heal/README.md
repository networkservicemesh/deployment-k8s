# Scalability heal test

This test has the following scenario:
1. Deploy endpoints
2. Deploy clients
3. Deploy new endpoints
4. Delete old endpoints
5. Wait for all connections to heal 
6. Delete clients
7. Delete endpoints
8. Gather statistics

## Run

Save test time, for drawing plots:
```bash
TEST_TIME_START=$(date -Iseconds)
```

Create test namespace:
```bash
NAMESPACE=($(kubectl create -f ../../namespace.yaml)[0])
NAMESPACE=${NAMESPACE:10}
```

Register namespace in `spire` server:
```bash
kubectl exec -n spire spire-server-0 -- \
/opt/spire/bin/spire-server entry create \
-spiffeID spiffe://example.org/ns/${NAMESPACE}/sa/default \
-parentID spiffe://example.org/ns/spire/sa/spire-agent \
-selector k8s:ns:${NAMESPACE} \
-selector k8s:sa:default
```

Create helper functions:
```bash
. ../define_helper_functions.sh
```

Set test parameters:
```bash
readParams ..
```

Select nodes to deploy NSC and NSE:
```bash
NODES=($(kubectl get nodes -o go-template='{{range .items}}{{ if not .spec.taints }}{{ .metadata.name }} {{end}}{{end}}'))
NSE_NODE=${NODES[0]}
if [[ "${TEST_REMOTE_CASE}" == "true" ]]; then
  NSC_NODE=${NODES[1]}
else
  NSC_NODE=${NODES[0]}
fi
echo NSE_NODE ${NSE_NODE}, NSC_NODE ${NSC_NODE}
```

Deploy network services:
```bash
generate_netsvc ${TEST_NS_COUNT}
```
```bash
kubectl apply -f netsvcs.yaml
```

Deploy endpoints:
```bash
create_endpoint_patches ${TEST_NSE_COUNT} ${NSE_NODE} endpoints-0 0
```
```bash
kubectl apply -k ./endpoints-0
```
```bash
timeout -v --kill-after=10s 3m kubectl -n ${NAMESPACE} wait pod --timeout=3m -l app=nse-kernel --for=condition=ready
```

Make sure that all endpoints have finished registration:
```bash
checkEndpointsStart ${NAMESPACE} endpoints-0
```
```bash
EVENT_LIST="${EVENT_LIST} ENDPOINTS_0_STARTED"
EVENT_TIME_ENDPOINTS_0_STARTED="$(date -Iseconds)"
EVENT_TEXT_ENDPOINTS_0_STARTED="All endpoints-0 started"
```

Deploy clients:
```bash
create_client_patches ${TEST_NSC_COUNT} ${NSC_NODE} clients
```
```bash
kubectl apply -k ./clients
```
```bash
timeout -v --kill-after=10s 3m kubectl -n ${NAMESPACE} wait pod --timeout=3m -l app=nsc-kernel --for=condition=ready
```

```bash
checkClientsSvid ${NAMESPACE}
```
```bash
EVENT_LIST="${EVENT_LIST} CLIENTS_GOT_SVID"
EVENT_TIME_CLIENTS_GOT_SVID="$(date -Iseconds)"
EVENT_TEXT_CLIENTS_GOT_SVID="All clients obtained svid"
```

```bash
checkConnectionsCount ${NAMESPACE} "10.0" ${TEST_NS_COUNT}
```
```bash
EVENT_LIST="${EVENT_LIST} CONNECTIONS_READY"
EVENT_TIME_CONNECTIONS_READY="$(date -Iseconds)"
EVENT_TEXT_CONNECTIONS_READY="Connections established"
```
```bash
sleep 15
```

Deploy second batch of endpoints:
```bash
create_endpoint_patches ${TEST_NSE_COUNT} ${NSE_NODE} endpoints-1 1
```
```bash
EVENT_LIST="${EVENT_LIST} RECREATE_ENDPOINTS"
EVENT_TIME_RECREATE_ENDPOINTS="$(date -Iseconds)"
EVENT_TEXT_RECREATE_ENDPOINTS="Create endpoints-1"
```
```bash
kubectl apply -k ./endpoints-1
```
```bash
timeout -v --kill-after=10s 3m kubectl -n ${NAMESPACE} wait pod --timeout=3m -l app=nse-kernel --for=condition=ready
```

Make sure that all endpoints have finished registration:
```bash
checkEndpointsStart ${NAMESPACE} endpoints-1
```
```bash
EVENT_LIST="${EVENT_LIST} ENDPOINTS_1_STARTED"
EVENT_TIME_ENDPOINTS_1_STARTED="$(date -Iseconds)"
EVENT_TEXT_ENDPOINTS_1_STARTED="All endpoints-1 started"
```

Delete first batch of endpoints:
```bash
EVENT_LIST="${EVENT_LIST} DELETE_ENDPOINTS"
EVENT_TIME_DELETE_ENDPOINTS="$(date -Iseconds)"
EVENT_TEXT_DELETE_ENDPOINTS="Delete endpoints-0..."
```
```bash
kubectl -n ${NAMESPACE} delete -k ./endpoints-0 --cascade=foreground
```
```bash
EVENT_LIST="${EVENT_LIST} ENDPOINTS_DELETED"
EVENT_TIME_ENDPOINTS_DELETED="$(date -Iseconds)"
EVENT_TEXT_ENDPOINTS_DELETED="Endpoints-0 deleted"
```

Wait for all connections to heal:
```bash
checkConnectionsCount ${NAMESPACE} "10.1" ${TEST_NS_COUNT}
```
```bash
EVENT_LIST="${EVENT_LIST} HEAL_FINISHED"
EVENT_TIME_HEAL_FINISHED="$(date -Iseconds)"
EVENT_TEXT_HEAL_FINISHED="Heal finished"
```
```bash
sleep 15
```

Delete everything:
```bash
EVENT_LIST="${EVENT_LIST} DELETE_NAMESPACE"
EVENT_TIME_DELETE_NAMESPACE="$(date -Iseconds)"
EVENT_TEXT_DELETE_NAMESPACE="Delete namespace..."
```
```bash
kubectl -n ${NAMESPACE} delete -k ./clients --cascade=foreground
```
```bash
kubectl delete ns ${NAMESPACE}
```
```bash
EVENT_LIST="${EVENT_LIST} NAMESPACE_DELETED"
EVENT_TIME_NAMESPACE_DELETED="$(date -Iseconds)"
EVENT_TEXT_NAMESPACE_DELETED="Namespace deleted"
```

## Cleanup

Save possible test fail event:
```bash
if [[ "${EVENT_TIME_NAMESPACE_DELETED}" == "" ]]; then
    EVENT_LIST="${EVENT_LIST} TEST_FAIL"
    EVENT_TIME_TEST_FAIL="$(date -Iseconds)"
    EVENT_TEXT_TEST_FAIL="Fail"
fi
```

Delete resources:
```bash
kubectl delete ns ${NAMESPACE} --ignore-not-found
```
```bash
kubectl delete -f netsvcs.yaml --ignore-not-found
```

Wait few seconds to capture performance after test end:
```bash
sleep 15
```

Mark test end:
```bash
TEST_TIME_END="$(date -Iseconds)"
```

Save statistics:
```bash
RESULT_DIR="./${RESULTS_PARENT_DIR}/results-$(date --date="${TEST_TIME_START}" -u +%FT%H-%M-%S%z)-netsvc=${TEST_NS_COUNT}-nse=${TEST_NSE_COUNT}-nsc=${TEST_NSC_COUNT}"
PARAM_ANNOTATION="heal case, ${TEST_NS_COUNT} service(s), ${TEST_NSE_COUNT} NSE(s), ${TEST_NSC_COUNT} NSC(s)"
if [[ "${TEST_REMOTE_CASE}" == "true" ]]; then
  PARAM_ANNOTATION="${PARAM_ANNOTATION}, remote case"
  RESULT_DIR="${RESULT_DIR}-remote"
else
  PARAM_ANNOTATION="${PARAM_ANNOTATION}, local case"
  RESULT_DIR="${RESULT_DIR}-local"
fi
PARAM_ANNOTATION="${PARAM_ANNOTATION}, run at ${TEST_TIME_START}"
```
```bash
. ../save_metrics.sh
```
