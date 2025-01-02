# Test runtime log level change via signals

This example shows how log level can be set, and reset to and from TRACE level

## Requires

Make sure that you have completed steps from [basic](../../basic) setup.


## Run

Ensure log level is not set to TRACE
```bash
kubectl apply -k ../https://github.com/networkservicemesh/deployments-k8s/examples/features/runtime-loglevel-change?ref=a93498171537efbfcfb704c5272519cc771c5ff0
```

Wait for forwarders to get ready
```bash
kubectl rollout status --timeout=3m -n nsm-system daemonset forwarder-vpp
```

Select a forwarder pod, get the pid of the running forwarder, and send SIGUSR1 to switch on TRACE
```bash
forwarder="$(kubectl get pods -n nsm-system --selector=app=forwarder-vpp --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}' | head -1)"
kubectl exec "$forwarder"  -n nsm-system -i -- bash <<'EOF'
  kill -s SIGUSR1 "$(pgrep 'forwarder')"
EOF
```

Check if signal has arrived
```bash
kubectl logs --selector=app=forwarder-vpp -n nsm-system --tail -1 --since=1m | grep "SetupLevelChangeOnSignal"
```

Check if there are TRACE logs
```bash
sleep 1m
kubectl logs --selector=app=forwarder-vpp -n nsm-system --tail -1 --since=1m | grep "TRAC"
```

Select a forwarder pod, get the pid of the running forwarder, and send SIGUSR2 to restore original log level
```bash
forwarder="$(kubectl get pods -n nsm-system --selector=app=forwarder-vpp --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}' | head -1)"
kubectl exec "$forwarder"  -n nsm-system -i -- bash <<'EOF'
  kill -s SIGUSR2 "$(pgrep 'forwarder')"
EOF
```

Check if signal has arrived
```bash
kubectl logs --selector=app=forwarder-vpp -n nsm-system --tail -1 --since=1m | grep "SetupLevelChangeOnSignal"
  ```

Check if there are no TRACE logs
```bash
sleep 1m
! kubectl logs --selector=app=forwarder-vpp -n nsm-system --tail -1 --since=1m | grep "TRAC"
```

//---------------------------------------------------------------------------//
## Cleanup

Reset original basic example
```bash
kubectl apply -k https://github.com/networkservicemesh/deployments-k8s/examples/basic?ref=a93498171537efbfcfb704c5272519cc771c5ff0
kubectl rollout status --timeout=3m -n nsm-system daemonset forwarder-vpp
```
