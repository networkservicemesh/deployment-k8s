# Test kernel to vxlan to kernel connection

This example shows that NSC and NSE on the different nodes could find and work with each other.

NSC and NSE are using the `kernel` mechanism to connect to its local forwarder.
Forwarders are using the `vxlan` mechanism to connect with each other.

## Requires

Make sure that you have completed steps from [basic](../../basic) or [memory](../../memory) setup.

## Run

Create test namespace:
```bash
NAMESPACE=($(kubectl create -f ../namespace.yaml)[0])
NAMESPACE=${NAMESPACE:10}
```

Register namespace in `spire` server:
```bash
kubectl exec -n spire spire-server-0 -- \
/opt/spire/bin/spire-server entry create \
-spiffeID spiffe://example.org/ns/${NAMESPACE}/sa/default \
-parentID spiffe://example.org/ns/spire/sa/spire-agent \
-selector k8s:ns:${NAMESPACE} \
-selector k8s:sa:default
```

Get nodes exclude control-plane:
```bash
NODES=($(kubectl get nodes -o go-template='{{range .items}}{{ if not .spec.taints  }}{{index .metadata.labels "kubernetes.io/hostname"}} {{end}}{{end}}'))
```

Setup for multiple clients
```bash
TEST_CLIENTS_N=8
mkdir ns-clients
RESOURCES_STR=""
PATCHES_STR=""
for (( i = 1; i <= TEST_CLIENTS_N; i++ )); do
    cp ../../../apps/nsc-kernel/nsc.yaml ./ns-clients/nsc-kernel-${i}.yaml
    sed -i "s/nsc-kernel/nsc-kernel-${i}/g" ./ns-clients/nsc-kernel-${i}.yaml
    RESOURCES_STR="${RESOURCES_STR}- ./ns-clients/nsc-kernel-${i}.yaml"$'\n'
    PATCHES_STR="${PATCHES_STR}- patch-nsc-${i}.yaml"$'\n'
    echo "$RESOURCES_STR"
    echo "$PATCHES_STR"
done
pow=1 
val=2
while (( TEST_CLIENTS_N >= val )); do
    let pow=pow+1
    let val=val*2
done
echo "$val"
echo "$pow"
```

Create customization file:
```bash
cat > kustomization.yaml <<EOF
---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: ${NAMESPACE}

resources:
${RESOURCES_STR}
bases:
- ../../../apps/nse-kernel

patchesStrategicMerge:
- patch-nse.yaml
${PATCHES_STR}
EOF
```

Create NSCs patches:
```bash
for (( i = 1; i <= TEST_CLIENTS_N; i++ )); do
cat > patch-nsc-${i}.yaml <<EOF
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nsc-kernel-{i}
spec:
  template:
    spec:
      containers:
        - name: nsc
          env:
            - name: NSM_NETWORK_SERVICES
              value: kernel://icmp-responder/nsm-1
        - name: iperf3
          image: ubuntu
          imagePullPolicy: IfNotPresent
          command: [ "/bin/bash" ]
          args: [ "-c", "while true; do echo hello; sleep 10;done" ]
      nodeSelector:
        kubernetes.io/hostname: ${NODES[0]}
EOF
done
```
Create NSE patch:
```bash
cat > patch-nse.yaml <<EOF
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nse-kernel
spec:
  template:
    spec:
      containers:
        - name: nse
          env:
            - name: NSM_CIDR_PREFIX
              value: 172.16.1.100/$((32-pow))
        - name: iperf3
          image: ubuntu
          imagePullPolicy: IfNotPresent
          command: [ "/bin/bash" ]
          args: [ "-c", "while true; do echo hello; sleep 10;done" ]
      nodeSelector:
        kubernetes.io/hostname: ${NODES[1]}
EOF
```

Deploy NSC and NSE:
```bash
kubectl apply -k .
```

Wait for applications ready:
```bash
kubectl wait --for=condition=ready --timeout=1m pod -l app=nsc-kernel -n ${NAMESPACE}
```
```bash
kubectl wait --for=condition=ready --timeout=1m pod -l app=nse-kernel -n ${NAMESPACE}
```

Find NSC and NSE pods by labels:
```bash
NSC=$(kubectl get pods -l app=nsc-kernel -n ${NAMESPACE} --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}')
```
```bash
NSE=$(kubectl get pods -l app=nse-kernel -n ${NAMESPACE} --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}')
```

Ping from NSC to NSE:
```bash
kubectl exec ${NSC} -n ${NAMESPACE} -- ping -c 4 172.16.1.100
```

Ping from NSE to NSC:
```bash
kubectl exec ${NSE} -n ${NAMESPACE} -- ping -c 4 172.16.1.101
```

## Cleanup

Delete ns:
```bash
kubectl delete ns ${NAMESPACE}
```