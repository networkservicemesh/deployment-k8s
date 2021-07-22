#!/bin/bash

function generate_netsvc() {
  local ns_count=$1

  local ns_list=
  local ns_url_list=
  cat /dev/null > netsvcs.yaml
  for (( i = 0; i < ns_count; i++ ))
  do
    ns=scalability-local-ns-$i
    nsIfName=nsm-$i
    cat >> netsvcs.yaml <<EOF
---
apiVersion: networkservicemesh.io/v1
kind: NetworkService
metadata:
  name: ${ns}
  namespace: nsm-system
spec:
  payload: ETHERNET
  name: ${ns}
EOF
      ns_list=${ns_list},${ns}
      ns_url_list=${ns_url_list},kernel://$ns/$nsIfName
  done

  NS_LIST="${ns_list:1}"
  NS_URL_LIST="${ns_url_list:1}"
}

function create_endpoint_patches() {
  local nse_count=$1
  local nse_node=$2
  local batch_name=$3
  local ip_interfix=$4

  mkdir -p "./${batch_name}"

  cat > "./${batch_name}/kustomization.yaml" <<EOF
---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: ${NAMESPACE}

namePrefix: ${batch_name}-

commonLabels:
  scalability-batch: ${batch_name}

resources:
  - nse.yaml

patchesStrategicMerge:
  - patch-nse.yaml
EOF

  cat /dev/null >"./${batch_name}/patch-nse.yaml"
  cat /dev/null >"./${batch_name}/nse.yaml"
  for ((i = 0; i < nse_count; i++)); do
    sed "s/name: nse-kernel/name: nse-kernel-$i/g" ../../../../apps/nse-kernel/nse.yaml >>"./${batch_name}/nse.yaml"
    local cidr_prefix=10.${ip_interfix}.$i.0/24
    cat >>"./${batch_name}/patch-nse.yaml" <<EOF
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nse-kernel-$i
spec:
  replicas: 1
  template:
    spec:
      nodeName: ${nse_node}
      containers:
        - name: nse
          env:
            - name: NSM_CIDR_PREFIX
              value: ${cidr_prefix}
            - name: NSM_SERVICE_NAMES
              value: ${NS_LIST}
          resources:
            limits:
              memory: 0Mi
              cpu: 0m
EOF
  done
}

function create_client_patches() {
  local nsc_count=$1
  local nsc_node=$2
  local batch_name=$3

  mkdir -p "./${batch_name}"

  cat > "./${batch_name}/kustomization.yaml" <<EOF
---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: ${NAMESPACE}

namePrefix: ${batch_name}-

commonLabels:
  scalability-batch: ${batch_name}

bases:
  - ../../../../../apps/nsc-kernel

patchesStrategicMerge:
  - patch-nsc.yaml
EOF

  cat >"./${batch_name}/patch-nsc.yaml" <<EOF
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nsc-kernel
spec:
  replicas: ${nsc_count}
  template:
    spec:
      nodeName: ${nsc_node}
      containers:
        - name: nsc
          env:
            - name: NSM_NETWORK_SERVICES
              value: ${NS_URL_LIST}
            - name: NSM_REQUEST_TIMEOUT
              value: 1m
          resources:
            limits:
              memory: 0Mi
              cpu: 0m
EOF
}

function waitEndpointsStart() {
  local namespace=$1
  local batch_label=$2
  for endpoint in $(kubectl -n "${namespace}" get pods -o go-template='{{range .items}}{{ .metadata.name }} {{end}}' -l "scalability-batch=${batch_label}"); do
    if [[ "$(kubectl -n "${namespace}" logs "${endpoint}" | grep "startup completed in" -c)" -ne 1 ]]; then
      echo "endpoint has not yet finished startup: ${endpoint}"
      return 1
    else
      echo "endpoint is good to do: ${endpoint} "
    fi
  done
}

function waitClientsSvid() {
  local namespace=$1
  for client in $(kubectl -n "${namespace}" get pods -o go-template='{{range .items}}{{ .metadata.name }} {{end}}' -l app=nsc-kernel); do
    if [[ "$(kubectl -n "${namespace}" logs "${client}" | grep "sVID: " -c)" -ne 1 ]]; then
      echo "client ${client} has not obtained svid yet"
      return 1
    else
      echo "client ${client} is good to do"
    fi
  done
}

function waitConnectionsCount() {
  local namespace=$1
  local grep_pattern=$2
  local grepDesiredCount=$3
  for client in $(kubectl -n "${namespace}" get pods -l app=nsc-kernel -o go-template='{{range .items}}{{ .metadata.name }} {{end}}'); do
    local count
    count="$(kubectl -n "${namespace}" exec "${client}" -- ip route | grep "dev nsm" -c)"
    if [[ "${grepDesiredCount}" -ne ${count} ]]; then
      echo "client have ${count} open NSM connections, need ${grepDesiredCount}: ${client}"
      return 1
    else
      echo "client is good to go: ${client}"
    fi
  done
}

function waitHealFinish() {
  local namespace=$1
  local grep_pattern=$2
  local grepDesiredCount=$3
  for client in $(kubectl -n "${namespace}" get pods -l app=nsc-kernel -o go-template='{{range .items}}{{ .metadata.name }} {{end}}'); do
    echo checking client "${client}"
    local routes
    routes=$(kubectl -n "${namespace}" exec "${client}" -- ip route)
    echo "${routes}"
    if [[ "${grepDesiredCount}" -ne $(echo "${routes}" | grep "${grep_pattern}" | grep "dev nsm" -c) ]]; then
      echo "client has not healed yet: ${client}"
      return 1
    else
      echo "client is good to go: ${client}"
    fi
  done
}

function saveData() {
  local name=$1
  local title=$2
  local name_replacement=$3
  local query=$4

  echo "saving ${name}"
  echo "query: ${query}"

  mkdir -p "${RESULT_DIR}" || return 1

  local test_time_start=$(date --date="${TEST_TIME_START}" -u +%s)
  local test_time_end=$(date --date="${TEST_TIME_END}" -u +%s)
  local test_time_end_relative=$((${test_time_end} - ${test_time_start}))
  local prom_url="http://localhost:9090"

  styx --duration $(($(date -u +%s)-${test_time_start} + 5))s --prometheus "${prom_url}" "${query}" > "${RESULT_DIR}/${name}.csv" || return 2

  sed -E -i "${name_replacement}" "${RESULT_DIR}/${name}.csv"

  cat > "${RESULT_DIR}/${name}.gnu" <<EOF
set terminal pngcairo dashed size 1600,900
set output '${RESULT_DIR}/${name}.png'

set datafile separator ';'
stats "${RESULT_DIR}/${name}.csv" skip 1 nooutput

set title "${title}"
set grid
set xtics time format "%tM:%tS"
set xrange [0:${test_time_end_relative}]
set key center bmargin horizontal

set for [i=5:300:9] linetype i linecolor rgb "dark-orange"

EOF

  local i=1
  for event in ${EVENT_LIST}
  do
    event_text_var=EVENT_TEXT_${event}
    event_time_var=EVENT_TIME_${event}
    event_time_relative=$(($(date --date="${!event_time_var}" -u +%s) - ${test_time_start}))
    cat >> "${RESULT_DIR}/${name}.gnu" <<EOF
set arrow from ${event_time_relative}, graph 0 to ${event_time_relative}, graph 1 nohead linetype ${i} linewidth 2 dashtype 2
set label "${!event_text_var}" at ${event_time_relative}, graph 1 textcolor lt ${i} offset 1,-${i}

EOF
    i=$((${i} + 1))
  done

  cat >> "${RESULT_DIR}/${name}.gnu" <<EOF
plot for [col=2:STATS_columns] "${RESULT_DIR}/${name}.csv" using (\$1-${test_time_start}):col with lines linewidth 2 title columnheader
EOF

  gnuplot "${RESULT_DIR}/${name}.gnu" || return 3

  curl \
    --silent \
    --show-error \
    "${prom_url}/api/v1/query_range" \
    --data-urlencode "query=${query}" \
    --data-urlencode "start=${TEST_TIME_START}" \
    --data-urlencode "end=${TEST_TIME_END}" \
    --data-urlencode "step=1s" \
    >"${RESULT_DIR}/${name}.json" \
    || return 4

    echo "${name} saved successfully"
}
