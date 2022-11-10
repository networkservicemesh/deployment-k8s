## Setup spire for k8s + docker

This example shows how to simply configure spire servers to know each other.
Docker container uses binary spire server.

## Run

1. Setup spire on the k8s cluster

```bash
kubectl apply -k https://github.com/networkservicemesh/deployments-k8s/examples/k8s_monolith/configuration/spire?ref=0d9869f4040068f554db54306eb463bb2358e3c7
```

Wait for PODs status ready:
```bash
kubectl wait -n spire --timeout=1m --for=condition=ready pod -l app=spire-agent
```
```bash
kubectl wait -n spire --timeout=1m --for=condition=ready pod -l app=spire-server
```


2. Bootstrap Federation

To enable the SPIRE Servers to fetch the trust bundles from each other they need each other's trust bundle first, because they have to authenticate the SPIFFE identity of the federated server that is trying to access the federation endpoint. Once federation is bootstrapped, the trust bundle updates are fetched through the federation endpoint API using the current trust bundle.

Get and store bundles of the k8s cluster and the docker container:
```bash
bundlek8s=$(kubectl exec spire-server-0 -n spire -- bin/spire-server bundle show -format spiffe)
bundledock=$(docker exec nsc-simple-docker bin/spire-server bundle show -format spiffe)
echo $bundledock | kubectl exec -i spire-server-0 -n spire -- bin/spire-server bundle set -format spiffe -id "spiffe://docker.nsm/cmd-nsc-simple-docker"
echo $bundlek8s | docker exec -i nsc-simple-docker bin/spire-server bundle set -format spiffe -id "spiffe://k8s.nsm"
```

## Cleanup

Cleanup spire resources for k8s cluster

```bash
kubectl delete crd spiffeids.spiffeid.spiffe.io
kubectl delete ns spire
```
