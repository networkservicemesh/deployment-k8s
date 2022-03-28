# Client requests for postgresql service

This example demonstrates how Postgres-client can get connectivity to Postgres-server deployment via NSM.
Client pod and server deployment located on different nodes.


## Requires

Make sure that you have completed steps from [features](../)

## Run

1. Create test namespace:
```bash
NAMESPACE=($(kubectl create -f https://raw.githubusercontent.com/networkservicemesh/deployments-k8s/72400b337f4335396bb30165e8363ecbef026225/examples/features/namespace.yaml)[0])
NAMESPACE=${NAMESPACE:10}
```

3. Get all available nodes to deploy:
```bash
NODES=($(kubectl get nodes -o go-template='{{range .items}}{{ if not .spec.taints  }}{{index .metadata.labels "kubernetes.io/hostname"}} {{end}}{{end}}'))
```

4. Create postgres client deployment and set `nodeName` to the first node:
```bash
cat > postgres-cl.yaml <<EOF
---
apiVersion: v1
kind: Pod
metadata:
  name: postgres-cl
  annotations:
    networkservicemesh.io: kernel://my-postgres-service/nsm-1
  labels:
    app: postgres-cl
spec:
  containers:
  - name: postgres-cl
    image: postgres
    imagePullPolicy: IfNotPresent
    env:
      - name: POSTGRES_HOST_AUTH_METHOD
        value: trust
  nodeName: ${NODES[0]}
EOF
```

5. Add to nse-kernel the postgres container and set `nodeName` it to the second node:
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
        - name: postgres
          image: postgres
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 5432
          env:
            - name: POSTGRES_DB
              value: test
            - name: POSTGRES_USER
              value: admin
            - name: POSTGRES_PASSWORD
              value: admin
        - name: nse
          env:
            - name: NSM_SERVICE_NAMES
              value: my-postgres-service
            - name: NSM_CIDR_PREFIX
              value: 172.16.1.100/31
      nodeName: ${NODES[1]}
EOF
```

6. Create kustomization file:
```bash
cat > kustomization.yaml <<EOF
---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: ${NAMESPACE}

bases:
- https://github.com/networkservicemesh/deployments-k8s/apps/nse-kernel?ref=72400b337f4335396bb30165e8363ecbef026225

resources:
- postgres-cl.yaml

patchesStrategicMerge:
- patch-nse.yaml
EOF
```

7. Deploy postgres-nsc and postgres-nse
```bash
kubectl apply -k .
```

8. Wait for applications ready:
```bash
kubectl wait --for=condition=ready --timeout=5m pod -l app=nse-kernel -n ${NAMESPACE}
```
```bash
kubectl wait --for=condition=ready --timeout=1m pod postgres-cl -n ${NAMESPACE}
```

9. Find NSC and NSE pods by labels:
```bash
NSC=$(kubectl get pods -l app=postgres-cl -n ${NAMESPACE} --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}')
```
```bash
NSE=$(kubectl get pods -l app=nse-kernel -n ${NAMESPACE} --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}')
```

10. Try to connect from postgres-nsc to database from postgresql service:
```bash
kubectl exec ${NSC} -n ${NAMESPACE} -c postgres-cl -- sh -c 'PGPASSWORD=admin psql -h 172.16.1.100 -p 5432 -U admin test'
```

## Cleanup

Delete ns:
```bash
kubectl delete ns ${NAMESPACE}
```
