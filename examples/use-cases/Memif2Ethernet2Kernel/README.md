# Test memif to Ethernet to kernel connection

This example shows that NSC and NSE on the different nodes could find and work with each other.


NSC is using the `memif` mechanism to connect to its local forwarder.
NSE is using the `kernel` mechanism to connect to its local forwarder.
Forwarders are using the `Ethernet` payload to connect with each other.

## Requires

Make sure that you have completed steps from [basic](../../basic) or [memory](../../memory) setup.

## Run

Deploy NSC and NSE:
```bash
kubectl apply -k https://github.com/networkservicemesh/deployments-k8s/examples/use-cases/Memif2Ethernet2Kernel?ref=17e6ce5be94dbf409e616c304359499ccbcd903f
```

Wait for applications ready:
```bash
kubectl wait --for=condition=ready --timeout=1m pod -l app=nsc-memif -n ns-memif2ethernet2kernel
```
```bash
kubectl wait --for=condition=ready --timeout=1m pod -l app=nse-kernel -n ns-memif2ethernet2kernel
```

Find NSC and NSE pods by labels:
```bash
NSC=$(kubectl get pods -l app=nsc-memif -n ns-memif2ethernet2kernel --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}')
```
```bash
NSE=$(kubectl get pods -l app=nse-kernel -n ns-memif2ethernet2kernel --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}')
```

Ping from NSC to NSE:
```bash
result=$(kubectl exec "${NSC}" -n "ns-memif2ethernet2kernel" -- vppctl ping 172.16.1.100 repeat 4)
echo ${result}
! echo ${result} | grep -E -q "(100% packet loss)|(0 sent)|(no egress interface)"
```

Ping from NSE to NSC:
```bash
kubectl exec ${NSE} -n ns-memif2ethernet2kernel -- ping -c 4 172.16.1.101
```

## Cleanup

Delete ns:
```bash
kubectl delete ns ns-memif2ethernet2kernel
```
