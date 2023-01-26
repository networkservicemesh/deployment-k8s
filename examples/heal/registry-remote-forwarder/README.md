# Registry + Remote Forwarder restart

This example shows that NSM keeps working after the Registry + remote Forwarder restart.

NSC and NSE are using the `kernel` mechanism to connect to its local forwarder.
Forwarders are using the `vxlan` mechanism to connect with each other.

## Requires

Make sure that you have completed steps from [basic](../../basic) or [memory](../../memory) setup.

## Run

Deploy NSC and NSE:
```bash
kubectl apply -k https://github.com/networkservicemesh/deployments-k8s/examples/heal/registry-remote-forwarder?ref=17e6ce5be94dbf409e616c304359499ccbcd903f
```

Wait for applications ready:
```bash
kubectl wait --for=condition=ready --timeout=1m pod -l app=alpine -n ns-registry-remote-forwarder
```
```bash
kubectl wait --for=condition=ready --timeout=1m pod -l app=nse-kernel -n ns-registry-remote-forwarder
```

Find NSC and NSE pods by labels:
```bash
NSC=$(kubectl get pods -l app=alpine -n ns-registry-remote-forwarder --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}')
```
```bash
NSE=$(kubectl get pods -l app=nse-kernel -n ns-registry-remote-forwarder --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}')
```

Ping from NSC to NSE:
```bash
kubectl exec ${NSC} -n ns-registry-remote-forwarder -- ping -c 4 172.16.1.100
```

Ping from NSE to NSC:
```bash
kubectl exec ${NSE} -n ns-registry-remote-forwarder -- ping -c 4 172.16.1.101
```

Find nse node:
```bash
NSE_NODE=$(kubectl get pods -l app=nse-kernel -n ns-registry-remote-forwarder --template '{{range .items}}{{.spec.nodeName}}{{"\n"}}{{end}}')
```

Find Registry:
```bash
REGISTRY=$(kubectl get pods -l app=registry -n nsm-system --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}')
```

Find remote Forwarder:
```bash
FORWARDER=$(kubectl get pods -l app=forwarder-vpp --field-selector spec.nodeName==${NSE_NODE} -n nsm-system --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}')
```

Restart Registry and remote Forwarder:
```bash
kubectl delete pod ${REGISTRY} -n nsm-system
```
```bash
kubectl delete pod ${FORWARDER} -n nsm-system
```

Waiting for new ones:
```bash
kubectl wait --for=condition=ready --timeout=1m pod -l app=registry -n nsm-system
```
```bash
kubectl wait --for=condition=ready --timeout=1m pod -l app=forwarder-vpp --field-selector spec.nodeName==${NSE_NODE} -n nsm-system
```

Ping from NSC to NSE:
```bash
kubectl exec ${NSC} -n ns-registry-remote-forwarder -- ping -c 4 172.16.1.100
```

Ping from NSE to NSC:
```bash
kubectl exec ${NSE} -n ns-registry-remote-forwarder -- ping -c 4 172.16.1.101
```

## Cleanup

Delete ns:
```bash
kubectl delete ns ns-registry-remote-forwarder
```
