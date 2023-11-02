# Test kernel to remote vlan connection

This example shows that NSCs can connect to a cluster external entity by a VLAN interface.
NSCs are using the `kernel` mechanism to connect to local forwarder.
Forwarders are using the `vlan` remote mechanism to set up the VLAN interface.

## Requires

Make sure that you have completed steps from [remotevlan_ovs](../../remotevlan_ovs) or [remotevlan_vpp](../../remotevlan_vpp) setup.

## Run

Deploy iperf server:

```bash
kubectl apply -k https://github.com/networkservicemesh/deployments-k8s/examples/use-cases/Kernel2RVlanBreakout?ref=5bb6afc5f5199a63e470b3552803d06f6b70cc61
```

Wait for applications ready:

```bash
kubectl -n ns-kernel2rvlan-breakout wait --for=condition=ready --timeout=1m pod -l app=iperf1-s
```

Get the iperf-NSC pods:

```bash
NSCS=($(kubectl get pods -l app=iperf1-s -n ns-kernel2rvlan-breakout --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}'))
```

Create a docker image for test external connections:

```bash
cat > Dockerfile <<EOF
FROM networkstatic/iperf3

RUN apt-get update \
    && apt-get install -y ethtool iproute2 \
    && rm -rf /var/lib/apt/lists/*

ENTRYPOINT [ "tail", "-f", "/dev/null" ]
EOF
docker build . -t rvm-tester-breakout
```

Setup a docker container for traffic test:

```bash
docker run --cap-add=NET_ADMIN --rm -d --network bridge-2 --name rvm-tester-breakout rvm-tester-breakout tail -f /dev/null
docker exec rvm-tester-breakout ip link set eth0 down
docker exec rvm-tester-breakout ip link add link eth0 name eth0.1000 type vlan id 1000
docker exec rvm-tester-breakout ip link set eth0 up
docker exec rvm-tester-breakout ip addr add 172.10.0.254/24 dev eth0.1000
docker exec rvm-tester-breakout ethtool -K eth0 tx off
```

Start iperf client on tester:

1. TCP

    ```bash
    status=0
    for nsc in "${NSCS[@]}"
    do
      IP_ADDRESS=$(kubectl exec ${nsc} -c cmd-nsc -n ns-kernel2rvlan-breakout -- ip -4 addr show nsm-1 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
      kubectl exec ${nsc} -c iperf-server -n ns-kernel2rvlan-breakout -- iperf3 -sD -B ${IP_ADDRESS} -1
      docker exec rvm-tester-breakout iperf3 -i0 -t 25 -c ${IP_ADDRESS}
      if test $? -ne 0
      then
        status=1
      fi
    done
    if test ${status} -eq 1
    then
      false
    fi
    ```

2. UDP

    ```bash
    status=0
    for nsc in "${NSCS[@]}"
    do
      IP_ADDRESS=$(kubectl exec ${nsc} -c cmd-nsc -n ns-kernel2rvlan-breakout -- ip -4 addr show nsm-1 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
      kubectl exec ${nsc} -c iperf-server -n ns-kernel2rvlan-breakout -- iperf3 -sD -B ${IP_ADDRESS} -1
      docker exec rvm-tester-breakout iperf3 -i0 -t 5 -u -c ${IP_ADDRESS}
      if test $? -ne 0
      then
        status=1
      fi
    done
    if test ${status} -eq 1
    then
      false
    fi
    ```

Start iperf server on tester:

1. TCP

    ```bash
    status=0
    for nsc in "${NSCS[@]}"
    do
      docker exec rvm-tester-breakout iperf3 -sD -B 172.10.0.254 -1
      kubectl exec ${nsc} -c iperf-server -n ns-kernel2rvlan-breakout -- iperf3 -i0 -t 5 -c 172.10.0.254
      if test $? -ne 0
      then
        status=1
      fi
    done
    if test ${status} -eq 1
    then
      false
    fi
    ```

2. UDP

    ```bash
    status=0
    for nsc in "${NSCS[@]}"
    do
      docker exec rvm-tester-breakout iperf3 -sD -B 172.10.0.254 -1
      kubectl exec ${NSCS[1]} -c iperf-server -n ns-kernel2rvlan-breakout -- iperf3 -i0 -t 5 -u -c 172.10.0.254
      if test $? -ne 0
      then
        status=1
      fi
    done
    if test ${status} -eq 1
    then
      false
    fi
    ```

## Cleanup

Delete the tester container and image:

```bash
docker stop rvm-tester-breakout
docker image rm rvm-tester-breakout:latest
true
```

Delete the test namespace:

```bash
kubectl delete ns ns-kernel2rvlan-breakout
```
