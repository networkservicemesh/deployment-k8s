# NSM + Istio interdomain example over kind clusters

## Setup Clusters

### KIND
Setup

```bash
go install sigs.k8s.io/kind@v0.13.0 

kind create cluster --config kind-cluster-config.yaml --name cluster-1
kind create cluster --config kind-cluster-config.yaml --name cluster-2


kind get kubeconfig --name cluster-1 > /tmp/config1
kind get kubeconfig --name cluster-2 > /tmp/config2

export KUBECONFIG1=/tmp/config1
export KUBECONFIG2=/tmp/config2 
```


#### Kind Load balancer

Make sure that CIDR is fine for your kind clusters

```bash
kubectl --kubeconfig=$KUBECONFIG1 apply -f https://raw.githubusercontent.com/metallb/metallb/v0.10.2/manifests/namespace.yaml
kubectl --kubeconfig=$KUBECONFIG1 create secret generic -n metallb-system memberlist --from-literal=secretkey="$(openssl rand -base64 128)" 
kubectl --kubeconfig=$KUBECONFIG1 apply -f https://raw.githubusercontent.com/metallb/metallb/v0.10.2/manifests/metallb.yaml
cat > metallb-config.yaml <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  namespace: metallb-system
  name: config
data:
  config: |
    address-pools:
    - name: default
      protocol: layer2
      addresses:
      - 172.18.1.128/25
EOF
kubectl --kubeconfig=$KUBECONFIG1 apply -f metallb-config.yaml
kubectl --kubeconfig=$KUBECONFIG1 wait --for=condition=ready --timeout=5m pod -l app=metallb -n metallb-system


kubectl --kubeconfig=$KUBECONFIG2 apply -f https://raw.githubusercontent.com/metallb/metallb/v0.10.2/manifests/namespace.yaml
kubectl --kubeconfig=$KUBECONFIG2 create secret generic -n metallb-system memberlist --from-literal=secretkey="$(openssl rand -base64 128)" 
kubectl --kubeconfig=$KUBECONFIG2 apply -f https://raw.githubusercontent.com/metallb/metallb/v0.10.2/manifests/metallb.yaml
cat > metallb-config.yaml <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  namespace: metallb-system
  name: config
data:
  config: |
    address-pools:
    - name: default
      protocol: layer2
      addresses:
      - 172.18.2.128/25
EOF
kubectl --kubeconfig=$KUBECONFIG2 apply -f metallb-config.yaml
kubectl --kubeconfig=$KUBECONFIG2 wait --for=condition=ready --timeout=5m pod -l app=metallb -n metallb-system

```


## DNS

Expose dns service for first cluster
```bash
kubectl --kubeconfig=$KUBECONFIG1 expose service kube-dns -n kube-system --port=53 --target-port=53 --protocol=TCP --name=exposed-kube-dns --type=LoadBalancer
```

Wait for assigning IP address (note: you should see IP address in logs. If you dont see repeat this):
```bash
kubectl --kubeconfig=$KUBECONFIG1 get services exposed-kube-dns -n kube-system -o go-template='{{index (index (index (index .status "loadBalancer") "ingress") 0) "ip"}}'
ip1=$(kubectl --kubeconfig=$KUBECONFIG1 get services exposed-kube-dns -n kube-system -o go-template='{{index (index (index (index .status "loadBalancer") "ingress") 0) "ip"}}')
if [[ $ip1 == *"no value"* ]]; then 
    ip1=$(kubectl --kubeconfig=$KUBECONFIG1 get services exposed-kube-dns -n kube-system -o go-template='{{index (index (index (index .status "loadBalancer") "ingress") 0) "hostname"}}')
    ip1=$(dig +short $ip1 | head -1)
fi
echo Selected externalIP: $ip1 for cluster1
```

Expose dns service for the second cluster:
```bash
kubectl --kubeconfig=$KUBECONFIG2 expose service kube-dns -n kube-system --port=53 --target-port=53 --protocol=TCP --name=exposed-kube-dns --type=LoadBalancer
```

Wait for assigning IP address (note: you should see IP address in logs. If you dont see repeat this):
```bash
kubectl --kubeconfig=$KUBECONFIG2 get services exposed-kube-dns -n kube-system -o go-template='{{index (index (index (index .status "loadBalancer") "ingress") 0) "ip"}}'
ip2=$(kubectl --kubeconfig=$KUBECONFIG2 get services exposed-kube-dns -n kube-system -o go-template='{{index (index (index (index .status "loadBalancer") "ingress") 0) "ip"}}')
if [[ $ip2 == *"no value"* ]]; then 
    ip2=$(kubectl --kubeconfig=$KUBECONFIG2 get services exposed-kube-dns -n kube-system -o go-template='{{index (index (index (index .status "loadBalancer") "ingress") 0) "hostname"}}')
    ip2=$(dig +short $ip2 | head -1)
fi
echo Selected externalIP: $ip2 for cluster2
```

Add DNS forwarding from cluster1 to cluster2:
```bash
cat > configmap.yaml <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns
  namespace: kube-system
data:
  Corefile: |
    .:53 {
        errors
        health {
            lameduck 5s
        }
        ready
        kubernetes cluster.local in-addr.arpa ip6.arpa {
            pods insecure
            fallthrough in-addr.arpa ip6.arpa
            ttl 30
        }
        k8s_external my.cluster1
        prometheus :9153
        forward . /etc/resolv.conf {
            max_concurrent 1000
        }
        loop
        reload 5s
    }
    my.cluster2:53 {
      forward . ${ip2}:53 {
        force_tcp
      }
    }
EOF
kubectl --kubeconfig=$KUBECONFIG1 apply -f configmap.yaml
```

Add DNS forwarding from cluster2 to cluster1:
```bash
cat > configmap.yaml <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns
  namespace: kube-system
data:
  Corefile: |
    .:53 {
        errors
        health {
            lameduck 5s
        }
        ready
        kubernetes cluster.local in-addr.arpa ip6.arpa {
            pods insecure
            fallthrough in-addr.arpa ip6.arpa
            ttl 30
        }
        k8s_external my.cluster2
        prometheus :9153
        forward . /etc/resolv.conf {
            max_concurrent 1000
        }
        loop
        reload 5s
    }
    my.cluster1:53 {
      forward . ${ip1}:53 {
        force_tcp
      }
    }
EOF

kubectl --kubeconfig=$KUBECONFIG2 apply -f configmap.yaml
```

## SPIRE

Install spire
```bash
kubectl --kubeconfig=$KUBECONFIG1 apply -k ./spire/cluster1
kubectl --kubeconfig=$KUBECONFIG2 apply -k ./spire/cluster2
```

Setup bundle federation for each cluster
```bash
bundle1=$(kubectl --kubeconfig=$KUBECONFIG1 exec spire-server-0 -n spire -- bin/spire-server bundle show -format spiffe)
bundle2=$(kubectl --kubeconfig=$KUBECONFIG2 exec spire-server-0 -n spire -- bin/spire-server bundle show -format spiffe)

echo $bundle2 | kubectl --kubeconfig=$KUBECONFIG1 exec -i spire-server-0 -n spire -- bin/spire-server bundle set -format spiffe -id "spiffe://nsm.cluster2"

echo $bundle1 | kubectl --kubeconfig=$KUBECONFIG2 exec -i spire-server-0 -n spire -- bin/spire-server bundle set -format spiffe -id "spiffe://nsm.cluster1"
```



## NSM SETUP

Install NSM for two clusters:
```bash
kubectl --kubeconfig=$KUBECONFIG1 apply -k ./nsm/cluster1
kubectl --kubeconfig=$KUBECONFIG2 apply -k ./nsm/cluster2
```


## Istio

Install Istio for second cluster:
```bash
curl -sL https://istio.io/downloadIstioctl | sh -
export PATH=$PATH:$HOME/.istioctl/bin
istioctl  install --set profile=minimal -y --kubeconfig=$KUBECONFIG2
istioctl --kubeconfig=$KUBECONFIG2 proxy-status
```

### Verify NSM+ISTIO

Install networkservice for the second cluster:
```bash
kubectl --kubeconfig=$KUBECONFIG2 apply -f networkservice.yaml
```

Start `productpage` networkservicemesh client for the first cluster:

```bash
kubectl --kubeconfig=$KUBECONFIG1 apply -f productpage/productpage.yaml
```

Start `auto-scale` networkservicemesh endpoint:
```bash
kubectl --kubeconfig=$KUBECONFIG2 apply -k nse-auto-scale 
```

Install istio booking example
```bash
kubectl --kubeconfig=$KUBECONFIG2 label namespace default istio-injection=enabled

kubectl --kubeconfig=$KUBECONFIG2 apply -f https://raw.githubusercontent.com/istio/istio/release-1.13/samples/bookinfo/platform/kube/bookinfo.yaml
```

Verify connectivity:
```bash
kubectl --kubeconfig=$KUBECONFIG1 exec deploy/productpage-v1 -c cmd-nsc -- apk add curl
kubectl --kubeconfig=$KUBECONFIG1 exec deploy/productpage-v1 -c cmd-nsc -- curl -s productpage.default:9080/productpage | grep -o "<title>.*</title>"
```
**Expected output** is `<title>Simple Bookstore App</title>`


Port forward and check connectivity from NSM+Istio  by yourself!
```bash
kubectl --kubeconfig=$KUBECONFIG1 port-forward deploy/productpage-v1  9080:9080
```

**Note:**
You should correctly see the page without errors.

Also, you should see different backend handlers for your requests:
If `reviews-v1` handles your query then you will not see reviews.
If `reviews-v2` handles your query then you will see black starts.
If `reviews-v3` handles your query then you will see red starts.
Otherwise you will see an error message.


Now we're simulating that someting went wrong and ratings-v1 from the istio cluster is down.
```bash
kubectl --kubeconfig=$KUBECONFIG2 delete deploy ratings-v1
```


Port forward and check that you see errors:
```bash
kubectl --kubeconfig=$KUBECONFIG1 port-forward deploy/productpage-v1  9080:9080
```

Now lets start ratings on cluster1:
```bash
kubectl --kubeconfig=$KUBECONFIG1 apply -f ratings/ratings.yaml
```

Port forward and check that you dont errors:
```bash
kubectl --kubeconfig=$KUBECONFIG2 port-forward deploy/productpage-v1  9080:9080
```

Congratulations! 
You have made a interdomain connection between GKE, AWS via NSM + Istio!

## Cleanup


```bash
WH=$(kubectl --kubeconfig=$KUBECONFIG1 get pods -l app=admission-webhook-k8s -n nsm-system --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}')
kubectl --kubeconfig=$KUBECONFIG1 delete mutatingwebhookconfiguration ${WH}

WH=$(kubectl --kubeconfig=$KUBECONFIG2 get pods -l app=admission-webhook-k8s -n nsm-system --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}')
kubectl --kubeconfig=$KUBECONFIG2 delete mutatingwebhookconfiguration ${WH}

kubectl --kubeconfig=$KUBECONFIG1 delete -k ./nsm/cluster1
kubectl --kubeconfig=$KUBECONFIG2 delete -k ./nsm/cluster2

kubectl --kubeconfig=$KUBECONFIG2 delete crd spiffeids.spiffeid.spiffe.io
kubectl --kubeconfig=$KUBECONFIG2 delete ns spire

kubectl --kubeconfig=$KUBECONFIG1 delete crd spiffeids.spiffeid.spiffe.io
kubectl --kubeconfig=$KUBECONFIG1 delete ns spire


gcloud container clusters delete "cluster-nsm" 
eksctl delete cluster --name "cluster-istio"
```