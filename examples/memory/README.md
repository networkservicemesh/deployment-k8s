# Memory examples

Memory example contains setup and tear down logic with default NSM infrastructure and memory based registry backend.

## Requires

- [spire](../spire/single_cluster)

## Includes

- [Memif to Memif Connection](./Memif2Memif)
- [Kernel to Kernel Connection](./Kernel2Kernel)
- [Kernel to Ethernet to Kernel Connection](./Kernel2Ethernet2Kernel)

## Run

Apply NSM resources for basic tests:

```bash
kubectl apply -k https://github.com/networkservicemesh/deployments-k8s/examples/memory?ref=9f073d0ee025f59f8ac526dbc19bbe7bbd825e37
```

Wait for admission-webhook-k8s:

```bash
WH=$(kubectl get pods -l app=admission-webhook-k8s -n nsm-system --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}')
kubectl wait --for=condition=ready --timeout=1m pod ${WH} -n nsm-system
```

## Cleanup

To free resources follow the next commands:

```bash
kubectl delete mutatingwebhookconfiguration nsm-mutating-webhook
kubectl delete ns nsm-system
```
