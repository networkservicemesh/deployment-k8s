#!/bin/bash

function readParams() {
  local params_folder=$1

  if [[ -f "${params_folder}/set_params.sh" ]]; then
    . "${params_folder}/set_params.sh"
  fi

  if [[ "${TEST_NS_COUNT}" == "" ]]; then
    TEST_NS_COUNT=1
  fi

  if [[ "${TEST_NSE_COUNT}" == "" ]]; then
    TEST_NSE_COUNT=1
  fi

  if [[ "${TEST_NSC_COUNT}" == "" ]]; then
    TEST_NSC_COUNT=1
  fi

  if [[ "${TEST_REMOTE_CASE}" == "" ]]; then
    TEST_REMOTE_CASE=false
  fi
}

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

function checkEndpointsStart() {
  local namespace=$1
  local batch_label=$2
  local wait_list
  for endpoint in $(kubectl -n "${namespace}" get pods -o go-template='{{range .items}}{{ .metadata.name }} {{end}}' -l "scalability-batch=${batch_label}"); do
    [[ "$(kubectl -n "${namespace}" logs "${endpoint}" | grep "startup completed in" -c)" -eq 1 ]] &
    wait_list="${wait_list} $!"
  done

  local result_code=0
  for pid in ${wait_list}; do
    if wait "${pid}"; then
      echo "endpoint is good to do: ${endpoint} "
    else
      echo "endpoint hasn't finished startup yet: ${endpoint}"
      result_code=1
    fi
  done
  return ${result_code}
}

function checkClientsSvid() {
  local namespace=$1

  local wait_list

  for client in $(kubectl -n "${namespace}" get pods -o go-template='{{range .items}}{{ .metadata.name }} {{end}}' -l app=nsc-kernel); do
    [[ "$(kubectl -n "${namespace}" logs "${client}" | grep "sVID: " -c)" -eq 1 ]] &
    wait_list="${wait_list} $!"
  done

  local result_code=0
  for pid in ${wait_list}; do
    if wait "${pid}"; then
      echo "client has svid: ${client}"
    else
      echo "client hasn't obtained svid yet: ${client}"
      result_code=1
    fi
  done
  return ${result_code}
}

function getClientConnections() {
  local namespace=$1
  local podName=$2
  local grep_pattern=$3

  local routes
  routes="$(kubectl -n "${namespace}" exec "${podName}" -- ip route)"

  local count
  count="$(echo "${routes}" | grep "dev nsm" | grep "${grep_pattern}" -c)"

  return "${count}"
}

function checkConnectionsCount() {
  local namespace=$1
  local grep_pattern=$2
  local grepDesiredCount=$3

  local wait_list

  for client in $(kubectl -n "${namespace}" get pods -l app=nsc-kernel -o go-template='{{range .items}}{{ .metadata.name }} {{end}}'); do
    getClientConnections "${namespace}" "${client}" "${grep_pattern}" &
    wait_list="${wait_list} $!"
  done

  local result_code=0
  for pid in ${wait_list}; do
    wait "${pid}"
    local count=$?
    if [[ "${count}" -eq "${grepDesiredCount}" ]]; then
      echo "client has ${count} connection(s): ${client}"
    else
      echo "client has ${count} connection(s), need ${grepDesiredCount}: ${client}"
      result_code=1
    fi
  done
  return ${result_code}
}

function createGnuplotFile() {
  local result_dir=$1
  local event_list=$2
  local event_text_prefix=$3
  local event_time_prefix=$4
  local test_time_start=$5
  local test_time_end=$6

  local test_time_start_u=$(date --date="${test_time_start}" -u +%s)
  local test_time_end_u=$(date --date="${test_time_end}" -u +%s)
  local test_time_end_relative=$((test_time_end_u - test_time_start_u))

  mkdir -p "${result_dir}" || return 1

  cat > "${result_dir}/plot.gp" <<EOF
set terminal pngcairo dashed size 1600,900
set output 'result.png'

set datafile separator ';'
stats "data.csv" skip 1 nooutput

set title ""
set grid
set xtics time format "%tM:%tS"
set xrange [0:${test_time_end_relative}]
set key center bmargin horizontal

set for [i=5:300:9] linetype i linecolor rgb "dark-orange"

EOF

  local i=1
  for event in ${event_list}
  do
    event_text_var=${event_text_prefix}_${event}
    event_time_var=${event_time_prefix}_${event}
    event_time_relative=$(($(date --date="${!event_time_var}" -u +%s) - test_time_start_u))
    cat >> "${result_dir}/plot.gp" <<EOF
set arrow from ${event_time_relative}, graph 0 to ${event_time_relative}, graph 1 nohead linetype ${i} linewidth 2 dashtype 2
set label "${!event_text_var}" at ${event_time_relative}, graph 1 textcolor lt ${i} offset 1,-${i}

EOF
    i=$((i + 1))
  done

  cat >> "${result_dir}/plot.gp" <<EOF
plot for [col=2:STATS_columns] "data.csv" using (\$1-${test_time_start_u}):col with lines linewidth 2 title columnheader
EOF

  local gnuplot_pod
  gnuplot_pod=$(kubectl -n gnuplot get pod --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}' -l app=gnuplot)
  kubectl -n gnuplot exec "${gnuplot_pod}" -i -- cp /dev/stdin plot.gp <"${result_dir}/plot.gp" || return 2
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
  local prom_url="http://localhost:9090"

  styx --duration $(($(date -u +%s)-${test_time_start} + 5))s --prometheus "${prom_url}" "${query}" > "${RESULT_DIR}/${name}.csv" || return 2

  sed -E -i "${name_replacement}" "${RESULT_DIR}/${name}.csv"

  local gnuplot_pod
  gnuplot_pod=$(kubectl -n gnuplot get pod --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}' -l app=gnuplot)
  <"${RESULT_DIR}/${name}.csv" kubectl -n gnuplot exec "${gnuplot_pod}" -i -- cp /dev/stdin data.csv || return 3
  sed 's/set title ""/set title "'"${title}"'"/' "${RESULT_DIR}/plot.gp" | kubectl -n gnuplot exec "${gnuplot_pod}" -i -- gnuplot || return 4
  kubectl -n gnuplot exec "${gnuplot_pod}" -- cat result.png >"${RESULT_DIR}/${name}.png" || return 5

  echo "${name} saved successfully"
}
