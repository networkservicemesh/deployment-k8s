# IPSec remote mechanism examples

Contain a setup for NSM that includes `nsmgr`, `forwarder-vpp`, `registry-k8s`. This setup can be used to check mechanisms combination.\
\
Unlike the [basic setup](../basic), which uses `Wireguard` as the default IP remote mechanism, we prioritize `IPSec` here.

## Requires

- [spire](../spire/single_cluster/)

## Includes

- [Kernel to IP to Kernel Connection](../use-cases/Kernel2IP2Kernel)
- [Memif to IP to Memif Connection](../use-cases/Memif2IP2Memif)
- [Kernel to IP to Memif Connection](../use-cases/Kernel2IP2Memif)
- [Memif to IP to Kernel Connection](../use-cases/Memif2IP2Kernel)

## Run

Apply NSM resources for basic tests:

```bash
kubectl apply -k https://github.com/networkservicemesh/deployments-k8s/examples/ipsec_mechanism?ref=af37254626d3d641d35b3fd0bc507aaf0a5ab3c4
```

Wait for admission-webhook-k8s:

```bash
WH=$(kubectl get pods -l app=admission-webhook-k8s -n nsm-system --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}')
kubectl wait --for=condition=ready --timeout=1m pod ${WH} -n nsm-system
```

## Cleanup

To free resources follow the next commands:

```bash
WH=$(kubectl get pods -l app=admission-webhook-k8s -n nsm-system --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}')
kubectl delete mutatingwebhookconfiguration ${WH}
kubectl delete ns nsm-system
```
