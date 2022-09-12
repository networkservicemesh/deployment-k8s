# Test kernel to wireguard to kernel connection

NSC and docker-NSE are using the `kernel` local mechanism.
`Wireguard` is used as remote mechanism.

## Requires

Make sure that you have completed steps from [external NSE](../../)

## Run

Create test namespace:
```bash
kubectl create ns ns-kernel2wireguard2kernel-monolith-nse
```

Deploy NSC:
```bash
kubectl apply -k https://github.com/networkservicemesh/deployments-k8s/examples/k8s_monolith/external_nse/usecases/Kernel2Wireguard2Kernel?ref=0ac1af83b8560efa7d52ab7acb97bd7952429025
```

Wait for applications ready:
```bash
kubectl wait --for=condition=ready --timeout=1m pod -l app=nsc-kernel -n ns-kernel2wireguard2kernel-monolith-nse
```

Find all NSCs:
```bash
nscs=$(kubectl  get pods -l app=nsc-kernel -o go-template --template="{{range .items}}{{.metadata.name}} {{end}}" -n ns-kernel2wireguard2kernel-monolith-nse)
[[ ! -z $nscs ]]
```

Ping each client by each client:
```bash
for nsc in $nscs
do
    ipAddr=$(kubectl exec -n ns-kernel2wireguard2kernel-monolith-nse $nsc -- ifconfig nsm-1)
    ipAddr=$(echo $ipAddr | grep -Eo 'inet addr:[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}'| cut -c 11-)
    for pinger in $nscs
    do
        echo $pinger pings $ipAddr
        kubectl exec $pinger -n ns-kernel2wireguard2kernel-monolith-nse -- ping -c4 $ipAddr
    done
done
```

Ping docker-nse by each client:
```bash
for nsc in $nscs
do
    echo $nsc pings docker-nse
    kubectl exec -n ns-kernel2wireguard2kernel-monolith-nse $nsc -- ping 169.254.0.1 -c4
done
```

Ping each client by docker-nse:
```bash
for nsc in $nscs
do
    ipAddr=$(kubectl exec -n ns-kernel2wireguard2kernel-monolith-nse $nsc -- ifconfig nsm-1)
    ipAddr=$(echo $ipAddr | grep -Eo 'inet addr:[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}'| cut -c 11-)
    docker exec nse-simple-vl3-docker ping -c4 $ipAddr
done
```

## Cleanup

Delete ns:

```bash
kubectl delete ns ns-kernel2wireguard2kernel-monolith-nse
```
