# Nsm system restart (local case)

This example shows that NSM keeps working after restarting all management resources.

NSC and NSE are using the `kernel` mechanism to connect to its local forwarder.

## Requires

Make sure that you have completed steps from [basic](../../basic).

## Run

Create test namespace:
```bash
kubectl create ns ns-local-nsm-system-restart
```

Deploy NSC and NSE:
```bash
kubectl apply -k https://github.com/networkservicemesh/deployments-k8s/examples/heal/local-nsm-system-restart?ref=0ac1af83b8560efa7d52ab7acb97bd7952429025
```

Wait for applications ready:
```bash
kubectl wait --for=condition=ready --timeout=1m pod -l app=nsc-kernel -n ns-local-nsm-system-restart
```
```bash
kubectl wait --for=condition=ready --timeout=1m pod -l app=nse-kernel -n ns-local-nsm-system-restart
```

Find nsc and nse pods by labels:
```bash
NSC=$(kubectl get pods -l app=nsc-kernel -n ns-local-nsm-system-restart --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}')
```
```bash
NSE=$(kubectl get pods -l app=nse-kernel -n ns-local-nsm-system-restart --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}')
```

Ping from NSC to NSE:
```bash
kubectl exec ${NSC} -n ns-local-nsm-system-restart -- ping -c 4 172.16.1.100
```

Ping from NSE to NSC:
```bash
kubectl exec ${NSE} -n ns-local-nsm-system-restart -- ping -c 4 172.16.1.101
```

Restart nsm-system:
```bash
WH=$(kubectl get pods -l app=admission-webhook-k8s -n nsm-system --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}')
kubectl delete mutatingwebhookconfiguration ${WH}
kubectl delete ns nsm-system
```
```bash
kubectl create ns nsm-system
```
```bash
kubectl apply -k https://github.com/networkservicemesh/deployments-k8s/examples/basic?ref=0ac1af83b8560efa7d52ab7acb97bd7952429025
```

Ping from NSC to NSE:
```bash
kubectl exec ${NSC} -n ns-local-nsm-system-restart -- ping -c 4 172.16.1.100
```

Ping from NSE to NSC:
```bash
kubectl exec ${NSE} -n ns-local-nsm-system-restart -- ping -c 4 172.16.1.101
```

## Cleanup

Delete ns:
```bash
kubectl delete ns ns-local-nsm-system-restart
```
