# Test Smart VF connections with VLAN Breakout

This example shows that NSCs are connected over single broadcasting domain with VLAN physical network,
The VLAN selection is done by a network service on which NS client connect to.

## Requires

Make sure that you have completed steps from [ovs remote vlan](../../ovsremotevlan) setup.

## Run

Create test namespace:
```bash
NAMESPACE=($(kubectl create -f https://raw.githubusercontent.com/networkservicemesh/deployments-k8s/a852347fbfd1c3c6b845580c16933872350a8530/examples/use-cases/namespace.yaml)[0])
NAMESPACE=${NAMESPACE:10}
```

Create customization file:
```bash
cat > kustomization.yaml <<EOF
---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: ${NAMESPACE}

bases:
- ../../../apps/nsc-kernel


patchesStrategicMerge:
- patch-nsc.yaml
EOF
```

Create NSC patch:
```bash
cat > patch-nsc.yaml <<EOF
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nsc-kernel
spec:
  replicas: 3
  template:
    spec:
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values:
                  - nsc-kernel
              topologyKey: kubernetes.io/hostname
      containers:
        - name: nsc
          env:
            - name: NSM_NETWORK_SERVICES
              value: kernel://finance-bridge/nsm-1?sriovToken=worker.domain/100G
          resources:
            limits:
              worker.domain/100G: 1
EOF
```

Deploy NSC:
```bash
kubectl apply -k .
```

Wait for NSC pods are ready:
```bash
kubectl -n ${NAMESPACE} wait --for=condition=ready --timeout=1m pod -l app=nsc-kernel
```

Get NSC pods:
```bash
NSC1=$((kubectl get pods -l app=nsc-kernel -n ${NAMESPACE} --template '{{range .items}}{{.metadata.name}}{{" "}}{{end}}') | cut -d' ' -f1)
TARGET_IP=$(kubectl exec -ti ${NSC1} -n ${NAMESPACE} -- ip route show | grep 172.10 | cut -d' ' -f1)
NSC2=$((kubectl get pods -l app=nsc-kernel -n ${NAMESPACE} --template '{{range .items}}{{.metadata.name}}{{" "}}{{end}}') | cut -d' ' -f2)
```

Ping from NSC2 to NSC1:
```bash
kubectl -n ${NAMESPACE} exec ${NSC2} -- ping -c 4 ${TARGET_IP}
```

## Cleanup

Delete ns:
```bash
kubectl delete ns ${NAMESPACE}
```
