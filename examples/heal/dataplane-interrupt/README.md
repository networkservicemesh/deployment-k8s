# Dataplane Interruption

This example shows that NSM not only checks that control plane is fine (NSMgr, Registry, etc), but also catches that data plane is interrupted and performs healing when it's restored.

NSC and NSE are using the `kernel` mechanism to connect with each other.

## Requires

Make sure that you have completed steps from [basic](../../basic) or [memory](../../memory) setup.

## Run

Deploy NSC and NSE:
```bash
kubectl apply -k https://github.com/networkservicemesh/deployments-k8s/examples/heal/dataplane-interrupt?ref=05a9319b78acdb91b0d4d0ef6b21736d7b17602c
```

Wait for applications ready:
```bash
kubectl wait --for=condition=ready --timeout=1m pod -l app=alpine -n ns-dataplane-interrupt
```
```bash
kubectl wait --for=condition=ready --timeout=1m pod -l app=nse-kernel -n ns-dataplane-interrupt
```

Ping from NSC to NSE:
```bash
kubectl exec pods/alpine -n ns-dataplane-interrupt -- ping -c 4 172.16.1.100 -I 172.16.1.101
```

Ping from NSE to NSC:
```bash
kubectl exec deployments/nse-kernel -n ns-dataplane-interrupt -- ping -c 4 172.16.1.101 -I 172.16.1.100
```

Run a pinger process in the background. The pinger will run until it encounters missing packets.
```bash
PINGER_PATH=/tmp/done-${RANDOM}
kubectl exec pods/alpine -n ns-dataplane-interrupt -- sh -c '
  PINGER_PATH=$1; rm -f "$PINGER_PATH"
  seq=0
  ping -i 0.2 172.16.1.100 -I 172.16.1.101 | while :; do
    read -t 1 line || { echo ping timeout; touch $PINGER_PATH; break; }
    seq1=$(echo $line | sed -n "s/.* seq=\([0-9]\+\) .*/\1/p")
    [ "$seq1" ] || continue
    [ "$seq" -eq "$seq1" ] || { echo missing $((seq1 - seq)) pings; touch $PINGER_PATH; break; }
    seq=$((seq1+1))
  done
' - "$PINGER_PATH" &
sleep 5
kubectl exec pods/alpine -n ns-dataplane-interrupt -- test ! -f /tmp/done || { echo pinger is done; false; }
```

Simulate data plane interruption by shutting down the kernel interface:
```bash
kubectl exec pods/alpine -n ns-dataplane-interrupt -- ip link set nsm-1 down
```

Wait until the pinger process stops. This would be an indication that the data plane was temporarily interrupted.
```bash
kubectl exec pods/alpine -n ns-dataplane-interrupt -- sh -c 'timeout 10 sh -c "while ! [ -f \"$1\" ];do sleep 1; done"' - "$PINGER_PATH"
```

Ping from NSC to NSE:
```bash
kubectl exec pods/alpine -n ns-dataplane-interrupt -- ping -c 4 172.16.1.100 -I 172.16.1.101
```

Ping from NSE to NSC:
```bash
kubectl exec deployments/nse-kernel -n ns-dataplane-interrupt -- ping -c 4 172.16.1.101 -I 172.16.1.100
```

## Cleanup

Delete ns:
```bash
kubectl delete ns ns-dataplane-interrupt
```
