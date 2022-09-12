# vl3-NSE as external docker container

In this example we need to create a connection between the kubernetes cluster and an external NSE. All clients connected to this endpoint will be on the same vl3-network.
This NSE creates the required interface on the monolith:

![NSM  k8s_monolith](./k8s_monolith.png "NSM k8s + monolith")

## Requires

- [Docker container](./docker)
- [DNS](./dns)
- [spire](./spire)

## Includes

- [Kernel to Wireguard to Kernel Connection](./usecases/Kernel2Wireguard2Kernel)

## Run

```bash
kubectl create ns nsm-system
```

Apply NSM resources for basic tests:
```bash
kubectl apply -k https://github.com/networkservicemesh/deployments-k8s/examples/k8s_monolith/configuration/cluster?ref=c7e79aecc9db188cb6b5a858356e01b5f5329fec
```

Wait for registry service exposing:
```bash
kubectl get services registry -n nsm-system -o go-template='{{index (index (index (index .status "loadBalancer") "ingress") 0) "ip"}}'
```

## Cleanup

To free resources follow the next command:
```bash
kubectl delete ns nsm-system
```
