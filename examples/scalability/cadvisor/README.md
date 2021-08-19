# cAdvisor

Contains setup for cAdvisor.

## Run

Deploy cAdvisor:
```bash
kubectl apply -k .
```

Wait for application ready:
```bash
kubectl -n cadvisor --timeout=1m wait pod --for=condition=ready -l app=cadvisor
```

## Cleanup

```bash
kubectl delete -k .
```
