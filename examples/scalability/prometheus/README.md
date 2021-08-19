# Prometheus

Contains setup for Prometheus.

## Requires

- [cAdvisor](../cadvisor)
- [kube-state-metrics](../kube_state_metrics)

## Run

Deploy prometheus:
```bash
kubectl apply -k .
```

Wait for application ready:
```bash
kubectl -n prometheus --timeout=1m wait pod --for=condition=ready $(kubectl -n prometheus get pod --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}' -l app=prometheus-server)
```

Disable terminal interactive mode.
This is needed for stability of automated tests, omit this if you are doing manual testing.
```bash
set +m
```

Open proxy connection to Prometheus:
```bash
kubectl -n prometheus port-forward $(kubectl -n prometheus get pod --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}' -l app=prometheus-server) 9090:9090 >port_forwarder_out.log 2>&1 &
```

Make sure the proxy is working, and we can access Prometheus through it:
```bash
curl "http://localhost:9090/-/healthy" --silent --show-error
```

## Cleanup

Kill proxy to prometheus:
```bash
PORT_FORWARDER_JOB=$(jobs | grep "prometheus port-forward" | cut -d] -f1 | cut -c 2-)
if [[ "${PORT_FORWARDER_JOB}" != "" ]]; then
  kill %${PORT_FORWARDER_JOB}
  cat port_forwarder_out.log
  rm port_forwarder_out.log
fi
```

Remove Prometheus:
```bash
kubectl delete -k .
```
