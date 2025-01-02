# Continuous NSC and NSE scaling

This scenario checks memory, goroutine and `vpp` interface leaks. We continuously scale up and down NSCs and NSEs.
Between scaling up and down we also check that all NSCs connections are alive. 

## Requires

Make sure that you have completed steps from [basic](../../basic) setup.

## Run

Deploy metrics server:
```bash
kubectl apply -f https://raw.githubusercontent.com/networkservicemesh/deployments-k8s/4b42afefaf090a724f79767ed6b3f2d61643a726/examples/highload/nsc-nse-scaling/metrics-server.yaml
```

Wait for metrics server's readiness:
```bash
kubectl wait --for=condition=ready --timeout=1m pod -l k8s-app=metrics-server -n kube-system
```

Collect pod metrics before scaling:
```bash
mkdir -p $ARTIFACTS_DIR/highload/nsc-nse-scaling
kubectl top pod -A > $ARTIFACTS_DIR/highload/nsc-nse-scaling/metrics-before
```

Deploy NSCs and NSEs, 0 replicas each:
```bash
kubectl apply -k https://github.com/networkservicemesh/deployments-k8s/examples/highload/nsc-nse-scaling?ref=4b42afefaf090a724f79767ed6b3f2d61643a726
```

A function to check connectivity between NSCs and NSEs:
```bash
function ping() {
    nscs=$(kubectl get pods -l app=nsc-kernel -o go-template --template="{{range .items}}{{.metadata.name}} {{end}}" -n ns-nsc-nse-scaling)
    for nsc in $nscs; do
        ipv4=$(kubectl exec $nsc -n ns-nsc-nse-scaling -- ip route | grep -Eo '172\.16\.0\.[0-9]{1,3}')
        kubectl exec $nsc -n ns-nsc-nse-scaling -- ping -c2 -i0.5 $ipv4 || return 1
    done
    return 0
}
```

Define the number of scaling iterations:
```bash
SCALING_COUNT=100
NSC_COUNT=5
NSE_COUNT=5
```

Main loop function:
```bash
function scaling() {
    for i in $(seq 1 $SCALING_COUNT); do
        kubectl scale deployment -n ns-nsc-nse-scaling nsc-kernel --replicas=$NSC_COUNT
        kubectl scale deployment -n ns-nsc-nse-scaling nse-kernel --replicas=$NSE_COUNT
        sleep 60

        ping || return 1

        kubectl scale deployment -n ns-nsc-nse-scaling nsc-kernel --replicas=0
        kubectl scale deployment -n ns-nsc-nse-scaling nse-kernel --replicas=0
        sleep 60
    done
    return 0
}
```


Run the loop:
```bash
scaling
```

Collect metrics after the test:
```bash
kubectl top pod -A > $ARTIFACTS_DIR/highload/nsc-nse-scaling/metrics-after
```

Collect `vpp` interfaces from the forwarders:
```bash
fwds=$(kubectl get pods -l app=forwarder-vpp -n nsm-system --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}')
for fwd in $fwds; do
    kubectl exec -n nsm-system $fwd -- vppctl show int > $ARTIFACTS_DIR/highload/nsc-nse-scaling/$fwd-ifaces
done
```

## Cleanup

Delete ns:
```bash
kubectl delete ns ns-nsc-nse-scaling
kubectl delete -f https://raw.githubusercontent.com/networkservicemesh/deployments-k8s/4b42afefaf090a724f79767ed6b3f2d61643a726/examples/highload/nsc-nse-scaling/metrics-server.yaml
```
