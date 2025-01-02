NAMESPACE=($(kubectl create -f ../namespace.yaml)[0])
NAMESPACE=${NAMESPACE:10}

kubectl exec -n spire spire-server-0 -- \
/opt/spire/bin/spire-server entry create \
-spiffeID spiffe://example.org/ns/${NAMESPACE}/sa/default \
-parentID spiffe://example.org/ns/spire/sa/spire-agent \
-selector k8s:ns:${NAMESPACE} \
-selector k8s:sa:default

NODES=($(kubectl get nodes -o go-template='{{range .items}}{{ if not .spec.taints  }}{{index .metadata.labels "kubernetes.io/hostname"}} {{end}}{{end}}'))

TEST_CLIENTS_N=1
mkdir ns-clients
RESOURCES_STR=""
PATCHES_STR=""
for (( i = 1; i <= TEST_CLIENTS_N; i++ )); do
    cp ../../../apps/nsc-kernel/nsc.yaml ./ns-clients/nsc-kernel-${i}.yaml
    gsed -i "s/nsc-kernel/nsc-kernel-${i}/g" ./ns-clients/nsc-kernel-${i}.yaml
    RESOURCES_STR="${RESOURCES_STR}- ./ns-clients/nsc-kernel-${i}.yaml"$'\n'
    PATCHES_STR="${PATCHES_STR}- patch-nsc-${i}.yaml"$'\n'
done
pow=1
val=2
while (( TEST_CLIENTS_N >= val )); do
    ((pow=pow+1))
    ((val=val*2))
done

#kubectl create configmap iperf-script --from-file=iperf.sh

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

for (( i = 1; i <= TEST_CLIENTS_N; i++ )); do
cat > patch-nsc-"${i}".yaml <<EOF
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nsc-kernel-${i}
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
          command: [ "/bin/bash", "-c" ]
          args:
            - apt-get update;
              apt-get install -y iproute2;
              apt-get install -y iperf3;

              IP_ADDRS_LEN_OLD=0;
              while [ true ];
              do IP_ADDRS=($(ip addr | egrep '172.16.1.[0-9]{1,3}/[0-9]{1,2}' -o));
              IP_ADDRS_LEN_NEW=${#IP_ADDRS[@]};
              echo $IP_ADDRS_LEN_NEW;

              IDX_START=0;
              if ((IP_ADDRS_LEN_OLD != 0));
              then IDX_START=$((IP_ADDRS_LEN_OLD - 1));
              fi;

              echo $IDX_START;

              IP_ADDRS_DIFF=$((IP_ADDRS_LEN_NEW - IP_ADDRS_LEN_OLD));
              echo $IP_ADDRS_DIFF;

              if (( IP_ADDRS_DIFF > 0));
              then for (( i = IDX_START; i < IP_ADDRS_LEN_NEW; i++ ));
              do IP_ADDR=$(echo "${IP_ADDRS[i]}" | sed 's=/[0-9]\{1,2\}==g');
              echo $IP_ADDR;
              iperf3 -s -D --pidfile /tmp/iperf.pid --bind ${IP_ADDR};
              sleep 5;
              if [ -f /tmp/iperf.pid ];
              then echo "iperf daemon sucesfully started on ${IP_ADDR}";
              rm /tmp/iperf.pid;
              fi;
              done;
              fi;
              sleep 5;

              IP_ADDRS_LEN_OLD=${IP_ADDRS_LEN_NEW};
              done;
      nodeSelector:
        kubernetes.io/hostname: ${NODES[1]}
EOF

kubectl apply -k .

kubectl wait --for=condition=ready --timeout=1m pod -l app=nsc-kernel-1 -n ${NAMESPACE}

kubectl wait --for=condition=ready --timeout=1m pod -l app=nse-kernel -n ${NAMESPACE}

NSC1=$(kubectl get pods -l app=nsc-kernel-1 -n ${NAMESPACE} --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}')

NSE=$(kubectl get pods -l app=nse-kernel -n ${NAMESPACE} --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}')

kubectl exec ${NSC1} -n ${NAMESPACE} -- ping -c 4 172.16.1.100

kubectl exec ${NSE} -n ${NAMESPACE} -- ping -c 4 172.16.1.101
