# Alpine requests for CoreDNS service

This example demonstrates how an external client configures DNS from the connected endpoint. 
Note: NSE provides DNS by itself. Also, NSE could provide configs for any other external DNS servers(that are not located as sidecar with NSE).

## Requires

Make sure that you have completed steps from [features](../)

## Run

Deploy alpine and nse
```bash
kubectl apply -k https://github.com/networkservicemesh/deployments-k8s/examples/features/dns?ref=17e6ce5be94dbf409e616c304359499ccbcd903f
```

Wait for applications ready:
```bash
kubectl wait --for=condition=ready --timeout=5m pod dnsutils -n ns-dns
```
```bash
kubectl wait --for=condition=ready --timeout=5m pod -l app=nse-kernel -n ns-dns
```

Find NSC and NSE pods by labels:
```bash
NSC=$(kubectl get pods -l app=dnsutils -n ns-dns --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}')
```
```bash
NSE=$(kubectl get pods -l app=nse-kernel -n ns-dns --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}')
```

Ping from dnsutils to NSE by domain name:
```bash
kubectl exec ${NSC} -c dnsutils -n ns-dns -- nslookup -norec -nodef my.coredns.service
```
```bash
kubectl exec ${NSC} -c dnsutils -n ns-dns -- ping -c 4 my.coredns.service
```

Validate that default DNS server is working:
```bash
kubectl exec ${NSC} -c dnsutils -n ns-dns -- dig kubernetes.default A kubernetes.default AAAA | grep "kubernetes.default.svc.cluster.local"
```

## Cleanup

Delete ns:
```bash
kubectl delete ns ns-dns
```
