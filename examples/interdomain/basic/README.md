# Basic interdomain examples

The NSM interdomain functionality provides the ability for clients in one domain to connect to endpoints in another domain. Each domain has its own installation of NSM and domain specific configuration such that all the NSM control-planes are able to communicate with the NSM components required for connection setup.


![NSM interdomain Scheme](./interdomain_concept.png "NSM interdomain Scheme")


## Requires

- [Interdomain-DNS](../dns)
- [Interdomain-spire](../spire)

## Includes

- [Kernel to VXLAN to Kernel Connection over two clusters](../usecases/Kernel2Vxlan2Kernel)

## Run

**1. Apply deployments for cluster1:**

```bash
export KUBECONFIG=$KUBECONFIG1
```

```bash
kubectl create ns nsm-system
```

Register `nsm-system` namespace in spire:

```bash
kubectl exec -n spire spire-server-0 -- \
/opt/spire/bin/spire-server entry create \
-spiffeID spiffe://example.org/ns/nsm-system/sa/default \
-parentID spiffe://example.org/ns/spire/sa/spire-agent \
-selector k8s:ns:nsm-system \
-selector k8s:sa:default
```

Register `registry-k8s-sa` in spire:

```bash
kubectl exec -n spire spire-server-0 -- \
/opt/spire/bin/spire-server entry create \
-spiffeID spiffe://example.org/ns/nsm-system/sa/registry-k8s-sa \
-parentID spiffe://example.org/ns/spire/sa/spire-agent \
-selector k8s:ns:nsm-system \
-selector k8s:sa:registry-k8s-sa
```

Register `nsmgr-proxy-sa` in spire:

```bash
kubectl exec -n spire spire-server-0 -- \
/opt/spire/bin/spire-server entry create \
-spiffeID spiffe://example.org/ns/nsm-system/sa/nsmgr-proxy-sa \
-parentID spiffe://example.org/ns/spire/sa/spire-agent \
-selector k8s:ns:nsm-system \
-selector k8s:sa:nsmgr-proxy-sa
```

Apply NSM resources for basic tests:

```bash
kubectl apply -k .
```

Wait for admission-webhook-k8s:

```bash
WH=$(kubectl get pods -l app=admission-webhook-k8s -n nsm-system --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}')
kubectl wait --for=condition=ready --timeout=1m pod ${WH} -n nsm-system
```

**1.1. Add externalIP for services**

*Note: If your cluster is already exposed to public this point can be skipped.*

Find node where `registry-k8s` has been deployed:

```bash
node=$(kubectl get pods -n nsm-system -l app=registry -o go-template='{{index (index (index  .items 0) "spec") "nodeName"}}')
```

Get IP of the node:

```bash
ip=$(kubectl get nodes $node -o go-template='{{range .status.addresses}}{{if eq .type "ExternalIP"}}{{.address}}{{end}}{{end}}')
echo Selected node IP: ${ip:=$(kubectl get nodes $node -o go-template='{{range .status.addresses}}{{if eq .type "InternalIP"}}{{.address}}{{end}}{{end}}')}
```

Now we need to expose `externalIP` of the cluster for the each service. 
Note: this step can be skipped if your cluster is exposed to the public.

```bash
cat > registry-service.yaml <<EOF
---
apiVersion: v1
kind: Service
metadata:
  namespace: nsm-system
  name: registry
spec:
  externalIPs:
    - $ip
  selector:
    app: registry
  ports:
    - name: registry
      protocol: TCP
      port: 5002
      targetPort: 5002
EOF
```

```bash
kubectl apply -f registry-service.yaml
```

Find node where `nsmgr-proxy` has been deployed:
```bash
node=$(kubectl get pods -n nsm-system -l app=nsmgr-proxy -o go-template='{{index (index (index  .items 0) "spec") "nodeName"}}')
```

Get IP of the node:

```bash
ip=$(kubectl get nodes $node -o go-template='{{range .status.addresses}}{{if eq .type "ExternalIP"}}{{.address}}{{end}}{{end}}')
echo Selected node IP: ${ip:=$(kubectl get nodes $node -o go-template='{{range .status.addresses}}{{if eq .type "InternalIP"}}{{.address}}{{end}}{{end}}')}
```

```bash
cat > nsmgr-proxy-service.yaml <<EOF
---
apiVersion: v1
kind: Service
metadata:
  namespace: nsm-system
  name: nsmgr-proxy
spec:
  externalIPs:
    - $ip
  selector:
    app: nsmgr-proxy
  ports:
    - protocol: TCP
      port: 5004
      targetPort: 5004

EOF
```
```bash
kubectl apply -f nsmgr-proxy-service.yaml
```

**2. Apply deployments for cluster2:**

```bash
export KUBECONFIG=$KUBECONFIG2
```

```bash
kubectl create ns nsm-system
```

Register `nsm-system` namespace in spire:

```bash
kubectl exec -n spire spire-server-0 -- \
/opt/spire/bin/spire-server entry create \
-spiffeID spiffe://example.org/ns/nsm-system/sa/default \
-parentID spiffe://example.org/ns/spire/sa/spire-agent \
-selector k8s:ns:nsm-system \
-selector k8s:sa:default
```

Register `registry-k8s-sa` in spire:

```bash
kubectl exec -n spire spire-server-0 -- \
/opt/spire/bin/spire-server entry create \
-spiffeID spiffe://example.org/ns/nsm-system/sa/registry-k8s-sa \
-parentID spiffe://example.org/ns/spire/sa/spire-agent \
-selector k8s:ns:nsm-system \
-selector k8s:sa:registry-k8s-sa
```

Register `nsmgr-proxy-sa` in spire:

```bash
kubectl exec -n spire spire-server-0 -- \
/opt/spire/bin/spire-server entry create \
-spiffeID spiffe://example.org/ns/nsm-system/sa/nsmgr-proxy-sa \
-parentID spiffe://example.org/ns/spire/sa/spire-agent \
-selector k8s:ns:nsm-system \
-selector k8s:sa:nsmgr-proxy-sa
```

Apply NSM resources for basic tests:

```bash
kubectl apply -k .
```

**2.1. Add externalIP for services**

*Note: If your cluster is already exposed to public this point can be skipped.*

Find node where `registry-k8s` has been deployed:

```bash
node=$(kubectl get pods -n nsm-system -l app=registry -o go-template='{{index (index (index  .items 0) "spec") "nodeName"}}')
```

Get IP of the node:

```bash
ip=$(kubectl get nodes $node -o go-template='{{range .status.addresses}}{{if eq .type "ExternalIP"}}{{.address}}{{end}}{{end}}')
echo Selected node IP: ${ip:=$(kubectl get nodes $node -o go-template='{{range .status.addresses}}{{if eq .type "InternalIP"}}{{.address}}{{end}}{{end}}')}
```

Now we need to expose `externalIP` of the cluster for the each service. 
Note: this step can be skipped if your cluster is exposed to the public.

```bash
cat > registry-service.yaml <<EOF
---
apiVersion: v1
kind: Service
metadata:
  namespace: nsm-system
  name: registry
spec:
  externalIPs:
    - $ip
  selector:
    app: registry
  ports:
    - name: registry
      protocol: TCP
      port: 5002
      targetPort: 5002
EOF
```
```bash
kubectl apply -f registry-service.yaml
```

Find node where `nsmgr-proxy` has been deployed:
```bash
node=$(kubectl get pods -n nsm-system -l app=nsmgr-proxy -o go-template='{{index (index (index  .items 0) "spec") "nodeName"}}')
```

Get IP of the node:

```bash
ip=$(kubectl get nodes $node -o go-template='{{range .status.addresses}}{{if eq .type "ExternalIP"}}{{.address}}{{end}}{{end}}')
echo Selected node IP: ${ip:=$(kubectl get nodes $node -o go-template='{{range .status.addresses}}{{if eq .type "InternalIP"}}{{.address}}{{end}}{{end}}')}
```

```bash
cat > nsmgr-proxy-service.yaml <<EOF
---
apiVersion: v1
kind: Service
metadata:
  namespace: nsm-system
  name: nsmgr-proxy
spec:
  externalIPs:
    - $ip
  selector:
    app: nsmgr-proxy
  ports:
    - protocol: TCP
      port: 5004
      targetPort: 5004

EOF
```
```bash
kubectl apply -f nsmgr-proxy-service.yaml
```


## Cleanup

To free resouces follow the next command:

1. Switch to *cluster1*

```bash
export KUBECONFIG=$KUBECONFIG1
```

2. Delete `nsm-system` namespace
```bash
kubectl delete ns nsm-system
```


3. Switch to *cluster2*

```bash
export KUBECONFIG=$KUBECONFIG2
```

4. Delete `nsm-system` namespace

```bash
kubectl delete ns nsm-system
```