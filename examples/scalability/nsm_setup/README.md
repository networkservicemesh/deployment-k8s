# NSM setup

Contain NSM setup for scalability tests. Identical to basic setup, expect without limits. 

## Requires

- [spire](../../spire)

## Run

1. Register `nsm-system` namespace in spire:

```bash
kubectl exec -n spire spire-server-0 -- \
/opt/spire/bin/spire-server entry create \
-spiffeID spiffe://example.org/ns/nsm-system/sa/default \
-parentID spiffe://example.org/ns/spire/sa/spire-agent \
-selector k8s:ns:nsm-system \
-selector k8s:sa:default
```

2. Register `registry-k8s-sa` in spire:

```bash
kubectl exec -n spire spire-server-0 -- \
/opt/spire/bin/spire-server entry create \
-spiffeID spiffe://example.org/ns/nsm-system/sa/registry-k8s-sa \
-parentID spiffe://example.org/ns/spire/sa/spire-agent \
-selector k8s:ns:nsm-system \
-selector k8s:sa:registry-k8s-sa
```

3. Choose node for NSM components:
```bash
NODE=($(kubectl get nodes -o go-template='{{range .items}}{{ if not .spec.taints }}{{ .metadata.name }} {{end}}{{end}}')[0])
```

4. Create patches for registry and webhook:
```bash
cat > patch-registry-k8s.yaml <<EOF
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: registry-k8s
spec:
  template:
    spec:
      nodeName: ${NODE}
      containers:
        - name: registry
          resources:
            requests:
              memory: "0"
              cpu: "0"
            limits:
              memory: "0"
              cpu: "0"
EOF
```
```bash
cat > patch-admission-webhook.yaml <<EOF
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: admission-webhook-k8s
spec:
  template:
    spec:
      nodeName: ${NODE}
      containers:
        - name: admission-webhook-k8s
          resources:
            requests:
              memory: "0"
              cpu: "0"
            limits:
              memory: "0"
              cpu: "0"
EOF
```

5. Deploy NSM resources:
```bash
kubectl apply -k .
```

6. Wait for applications ready:
```bash
timeout -v --kill-after=10s 1m kubectl -n nsm-system wait pod --timeout=1m --all --for=condition=ready
```

## Cleanup

Free resources:
```bash
kubectl delete mutatingwebhookconfiguration --all
```
```bash
kubectl delete -k . --ignore-not-found
```
