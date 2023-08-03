# Remote NSMgr + Remote NSE restart

This example shows that NSM keeps working after the remote NSMgr + remote NSE restart.

NSC and NSE are using the `kernel` mechanism to connect to its local forwarder.
Forwarders are using the `vxlan` mechanism to connect with each other.

## Requires

Make sure that you have completed steps from [basic](../../basic) or [memory](../../memory) setup.

## Run

Deploy NSC and NSE:
```bash
kubectl apply -k https://github.com/networkservicemesh/deployments-k8s/examples/heal/remote-nsmgr-remote-endpoint/nsmgr-before-death?ref=b7a0736c9257da4c7e0880b8338f254f94097d4c
```

Wait for applications ready:
```bash
kubectl wait --for=condition=ready --timeout=1m pod -l app=alpine -n ns-remote-nsmgr-remote-endpoint
```
```bash
kubectl wait --for=condition=ready --timeout=1m pod -l app=nse-kernel -n ns-remote-nsmgr-remote-endpoint
```

Ping from NSC to NSE:
```bash
kubectl exec pods/alpine -n ns-remote-nsmgr-remote-endpoint -- ping -c 4 172.16.1.100
```

Ping from NSE to NSC:
```bash
kubectl exec deployments/nse-kernel -n ns-remote-nsmgr-remote-endpoint -- ping -c 4 172.16.1.101
```

Find nse node:
```bash
NSE_NODE=$(kubectl get pods -l app=nse-kernel -n ns-remote-nsmgr-remote-endpoint --template '{{range .items}}{{.spec.nodeName}}{{"\n"}}{{end}}')
```

Find remote NSMgr pod:
```bash
NSMGR=$(kubectl get pods -l app=nsmgr --field-selector spec.nodeName==${NSE_NODE} -n nsm-system --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}')
```

Restart remote NSMgr and NSE:
```bash
kubectl delete pod ${NSMGR} -n nsm-system
```
```bash
kubectl apply -k https://github.com/networkservicemesh/deployments-k8s/examples/heal/remote-nsmgr-remote-endpoint/nsmgr-after-death?ref=b7a0736c9257da4c7e0880b8338f254f94097d4c
```

Waiting for new ones:
```bash
kubectl wait --for=condition=ready --timeout=1m pod -l app=nsmgr --field-selector spec.nodeName==${NSE_NODE} -n nsm-system
```
```bash
kubectl wait --for=condition=ready --timeout=1m pod -l app=nse-kernel -l version=new -n ns-remote-nsmgr-remote-endpoint
```

Find new NSE pod:
```bash
NEW_NSE=$(kubectl get pods -l app=nse-kernel -l version=new -n ns-remote-nsmgr-remote-endpoint --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}')
```

Ping from NSC to new NSE:
```bash
kubectl exec pods/alpine -n ns-remote-nsmgr-remote-endpoint -- ping -c 4 172.16.1.102
```

Ping from new NSE to NSC:
```bash
kubectl exec ${NEW_NSE} -n ns-remote-nsmgr-remote-endpoint -- ping -c 4 172.16.1.103
```

## Cleanup

Delete ns:
```bash
kubectl delete ns ns-remote-nsmgr-remote-endpoint
```
