# Spire

This is a part of the Spire setup that installs Spire to the second cluster in a multi-cluster scenarios.

This example assumes [interdomain](../../interdomain/) or [multi-cluster](../../multicluster/) scenario.
If your cluster setup differs from these scenarios you may need to adjust spire configs (rename trust domains, change URLS, etc.).

## Run

Check that we have config for the cluster:
```bash
[[ ! -z $KUBECONFIG2 ]]
```

Apply spire deployments:
```bash
kubectl --kubeconfig=$KUBECONFIG2 apply -k https://github.com/networkservicemesh/deployments-k8s/examples/spire/cluster2?ref=0fde6d2cd380f5c4ed9124beae618e34463f6032
```

Wait for PODs status ready:
```bash
kubectl --kubeconfig=$KUBECONFIG2 wait -n spire --timeout=1m --for=condition=ready pod -l app=spire-server
```
```bash
kubectl --kubeconfig=$KUBECONFIG2 wait -n spire --timeout=1m --for=condition=ready pod -l app=spire-agent
```

## Cleanup

Delete ns:
```bash
kubectl --kubeconfig=$KUBECONFIG2 delete crd spiffeids.spiffeid.spiffe.io
kubectl --kubeconfig=$KUBECONFIG2 delete ns spire
```
