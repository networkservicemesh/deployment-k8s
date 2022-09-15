# Enable Jaeger Tracing for NSM Components

## OpenTelemetry Collector
NSM supports tracing via the [OpenTelemetry](https://opentelemetry.io/) Collector. Each NSM component is a "tracer" (OpenTelemetry
Span producer) and integrates with the `opentelemetry-go` library to export traces to OpenTelemery Collector.

By default, tracing is disabled in all NSM components. You can enable tracing for a specific NSM component by adding the environment variable `TELEMETRY`
with the value `true`. It can be done with a patch for this NSM component. For example, the following code is the patch for NSM forwarder:
```yaml
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: forwarder-vpp
spec:
  template:
    spec:
      containers:
        - name: forwarder-vpp
          env:
            - name: TELEMETRY
              value: "true"
```

You can configure OpenTelemetry Collector to send traces to Jaeger. To do it you should specify Jaeger service in OpenTelemetry Config:
```yaml
 jaeger:
    endpoint: "simplest-collector.observability.svc.cluster.local:14250"
    insecure: true
```

And use `jaeger` as a trace exporter:
```yaml
traces:
    receivers: [otlp]
    processors: [batch]
    exporters: [jaeger]
```

## Jaeger

Jaeger installation is not in the scope of NSM, however, the Jaeger community
has documented an all-in-one installation that is useful as a quick start for
Kubernetes and NSM examples.

[Jaeger All-in-one Installation](https://www.jaegertracing.io/docs/1.30/operator/#quick-start---deploying-the-allinone-image)

The following examples assume the Jaeger operator CRD was created with the
name `simplest` as in the all-in-one document shows:

```bash
kubectl apply -n observability -f - <<EOF
apiVersion: jaegertracing.io/v1
kind: Jaeger
metadata:
  name: simplest
EOF
```

**NOTE:**  Exposing the resulting `simplest-query` Kubernetes service's
`http-query` port (e.g. via port-forwarding) gives access to the Jaeger UI--
e.g. the following forwards `http://localhost:16686` to the Jaeger UI:

```bash
kubectl port-forward svc/simplest-query -n observability 16686:16686
```

## Requires

- [spire](../../spire)

## Run

Create namespace observability:
```bash
kubectl create ns observability
```

Apply Jaeger Operator
```bash
kubectl create -f https://github.com/jaegertracing/jaeger-operator/releases/download/v1.30.0/jaeger-operator.yaml -n observability
```

Wait for Jaeger Operator pod status ready:
```bash
kubectl wait -n observability --timeout=1m --for=condition=ready pod -l name=jaeger-operator
```

Apply Jaeger and OpenTelemetry Collector:
```bash
kubectl apply -k https://github.com/networkservicemesh/deployments-k8s/examples/features/jaeger/jaeger?ref=40eba2b9d535b7e3c0e3f7463af6227d863c5a32
```

Wait for Jaeger pod status ready:
```bash
kubectl wait -n observability --timeout=1m --for=condition=ready pod -l app=jaeger
```


Wait for Opentelemetry pods status ready:
```bash
kubectl wait -n observability --timeout=1m --for=condition=ready pod -l app=opentelemetry
```

Apply NSM resources:
```bash
kubectl apply -k https://github.com/networkservicemesh/deployments-k8s/examples/features/jaeger/nsm-system?ref=40eba2b9d535b7e3c0e3f7463af6227d863c5a32
```

Wait for admission-webhook-k8s:
```bash
WH=$(kubectl get pods -l app=admission-webhook-k8s -n nsm-system --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}')
kubectl wait --for=condition=ready --timeout=1m pod ${WH} -n nsm-system
```

Expose ports to access Jaeger UI:
```bash
kubectl port-forward service/simplest-query -n observability 16686:16686
```
You can see traces from the NSM manager and forwarder in Jaeger UI (`http://localhost:16686`) after their initialization.

## Clean up

Free NSM resources:
```bash
WH=$(kubectl get pods -l app=admission-webhook-k8s -n nsm-system --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}')
kubectl delete mutatingwebhookconfiguration ${WH}
kubectl delete ns nsm-system
```

Delete Jaeger Operator:
```bash
kubectl delete -n observability -f https://github.com/jaegertracing/jaeger-operator/releases/download/v1.30.0/jaeger-operator.yaml
```

Delete observability namespace:
```bash
kubectl delete ns observability
```
