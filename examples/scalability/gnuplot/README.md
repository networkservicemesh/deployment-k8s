# Gnuplot

Contains setup for gnuplot.

## Run

Deploy gnuplot:
```bash
kubectl apply -k .
```

Wait till gnuplot pod is up and running:
```bash
kubectl -n gnuplot --timeout=1m wait pod --for=condition=ready -l app=gnuplot
```

## Cleanup

```bash
kubectl delete -k .
```
