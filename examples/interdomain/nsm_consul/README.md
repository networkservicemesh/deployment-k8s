# NSM + Consul interdomain example over kind clusters

This example shows how Consul can be used over NSM. 


## Requires

- [Load balancer](../loadbalancer)
- [Interdomain DNS](../dns)
- [Interdomain spire](../spire)
- [Interdomain nsm](../nsm)


## Run

Install Consul
```bash
brew tap hashicorp/tap
brew install hashicorp/tap/consul-k8s
```

Install Consul for the second cluster:
```bash
consul-k8s install -config-file=helm-consul-values.yaml -set global.image=hashicorp/consul:1.12.0 -auto-approve --kubeconfig=$KUBECONFIG2
```

Install networkservice for the second cluster::
```bash
kubectl --kubeconfig=$KUBECONFIG2 apply -f networkservice.yaml 
```

Start `dashboard` networkservicemesh client for the first cluster:

```bash
kubectl --kubeconfig=$KUBECONFIG1 apply -f client/dashboard.yaml 
```

Create kubernetes service for the networkservicemesh endpoint:
```bash
kubectl --kubeconfig=$KUBECONFIG2 apply -f service.yaml 
```

Start `auto-scale` networkservicemesh endpoint:
```bash
kubectl --kubeconfig=$KUBECONFIG2 apply -k nse-auto-scale
```

Install `counting` Consul workload on the second cluster:
```bash
kubectl --kubeconfig=$KUBECONFIG2 apply -f server/counting.yaml
```

Wait for the dashboard client to be ready
```bash
kubectl --kubeconfig=$KUBECONFIG1 wait --timeout=5m --for=condition=ready pod -l app=dashboard-nsc
```

Verify connection from networkservicemesh client to the consul counting service:
```bash
kubectl --kubeconfig=$KUBECONFIG1 exec pod/dashboard-nsc -c cmd-nsc -- apk add curl
```
```bash
kubectl --kubeconfig=$KUBECONFIG1 exec pod/dashboard-nsc -c cmd-nsc -- curl counting:9001 
```

Port forward and check connectivity from NSM+Consul by yourself!
```bash
kubectl --kubeconfig=$KUBECONFIG1 port-forward pod/dashboard-nsc 9002:9002 &
```
Now we're simulating that someting went wrong and counting from the consul cluster is down.
```bash
kubectl --kubeconfig=$KUBECONFIG2 delete deploy counting
```
Check UI and ensure that you see errors.
Now lets start counting on cluster1:
```bash
kubectl --kubeconfig=$KUBECONFIG1 apply -f server/counting_nsm.yaml
```
Check UI again and ensure that the dashboard sees a new counting pod. 
Congratulations! You have made a interdomain connection between via NSM + Consul!


## Cleanup


```bash
kubectl --kubeconfig=$KUBECONFIG1 delete deployment counting
```
```bash
kubectl --kubeconfig=$KUBECONFIG2 delete -k nse-auto-scale
```
```bash
kubectl --kubeconfig=$KUBECONFIG1 delete -f client/dashboard.yaml
```
```bash
kubectl --kubeconfig=$KUBECONFIG2 delete -f networkservice.yaml
```
```bash
kubectl --kubeconfig=$KUBECONFIG2 delete pods --all
```
```bash
consul-k8s uninstall --kubeconfig=$KUBECONFIG2 -auto-approve=true -wipe-data=true
```
