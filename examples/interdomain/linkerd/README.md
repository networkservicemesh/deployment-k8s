# NSM + linkerd interdomain example over kind clusters

This diagram shows that we have 2 clusters with NSM and also linkerd deployed on the Cluster-2.

In this example, we deploy an http-server (**Workload-2**) on the Cluster-2 and show how it can be reached from Cluster-1.

The client will be `alpine` (**Workload-1**), we will use curl.

## Requires

- [Load balancer](../loadbalancer)
- [Interdomain DNS](../dns)
- Interdomain spire
    - [Spire on first cluster](../../spire/cluster1)
    - [Spire on second cluster](../../spire/cluster2)
    - [Spiffe Federation](../spiffe_federation)
- [Interdomain nsm](../nsm)


## Run

```bash
export KUBECONFIG=$KUBECONFIG2
linkerd check --pre
linkerd install --crds | kubectl apply -f -
linkerd install | kubectl apply -f -
linkerd check
```

Install networkservice for the second cluster:
```bash
kubectl create ns ns-nsm-linkerd
kubectl apply -f ./networkservice.yaml
```

Start `alpine` with networkservicemesh client on the first cluster:

```bash
kubectl --kubeconfig=$KUBECONFIG1 apply -f ./greeting/client.yaml
```

Start `auto-scale` networkservicemesh endpoint:
```bash
kubectl --kubeconfig=$KUBECONFIG2 apply -k ./nse-auto-scale
```

Install http-server for the second cluster:
```bash
export KUBECONFIG=$KUBECONFIG2
kubectl apply -f ./greeting/server.yaml
kubectl get deploy greeting -o yaml | linkerd inject - | kubectl apply -f -
```


Wait for the `alpine` client to be ready:
```bash
kubectl --kubeconfig=$KUBECONFIG1 wait --timeout=2m --for=condition=ready pod -l app=alpine
```

Install everything for client:
```bash
kubectl --kubeconfig=$KUBECONFIG1 exec deploy/alpine -c alpine -- apk add curl
kubectl --kubeconfig=$KUBECONFIG1 exec deploy/alpine -c alpine -- apk add iproute2
kubectl --kubeconfig=$KUBECONFIG1 exec deploy/alpine -c alpine -- apk add iptables
```

```bash
kubectl --kubeconfig=$KUBECONFIG1 exec deploy/alpine -c alpine -- iptables -t mangle -A OUTPUT -p tcp -d 199.0.0.0/8 -j MARK --set-mark 8
kubectl --kubeconfig=$KUBECONFIG1 exec deploy/alpine -c alpine -- iptables -t nat -A OUTPUT -m mark --mark 8 -j NETMAP --to 10.0.0.0/8
kubectl --kubeconfig=$KUBECONFIG1 exec deploy/alpine -c alpine -- iptables -t nat -A POSTROUTING -m mark --mark 8 -j SNAT --to 172.16.1.3
```

```bash
kubectl --kubeconfig=$KUBECONFIG1 exec deploy/alpine -c alpine -- echo 201 nsm_table >> /etc/iproute2/rt_tables
kubectl --kubeconfig=$KUBECONFIG1 exec deploy/alpine -c alpine -- ip ru add fwmark 8 lookup nsm_table pref 3333
kubectl --kubeconfig=$KUBECONFIG1 exec deploy/alpine -c alpine -- ip ro add default via 172.16.1.3 table nsm_table
```

Verify connectivity:
```bash
kubectl --kubeconfig=$KUBECONFIG1 exec deploy/alpine -c alpine -- curl -s greeting.default:9080 | grep -o "hello world from linkerd"
```
**Expected output** is "hello world from linkerd"

Congratulations! 
You have made a interdomain connection between two clusters via NSM + linkerd!

## Cleanup

```bash
export KUBECONFIG=$KUBECONFIG2
kubectl delete deployment greeting
kubectl delete ns ns-nsm-linkerd
linkerd uninstall | kubectl delete -f -
```

```bash
kubectl --kubeconfig=$KUBECONFIG1 delete deployment alpine
```