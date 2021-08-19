#!/bin/bash

createGnuplotFile "${RESULT_DIR}" "${EVENT_LIST}" "EVENT_TEXT" "EVENT_TIME" "${TEST_TIME_START}" "${TEST_TIME_END}"

CONT_REPLACE='s/\{container_label_io_kubernetes_container_name="([^"]*)",kubernetes_io_hostname="([^"]*)"}/\1 on \2/g'
POD_REPLACE='s/\{kubernetes_io_hostname="([^"]*)",pod="([^"]*)"}/\2 on \1/g'

saveData nsm-cpu "NSM CPU Usage in cores, ${PARAM_ANNOTATION}" "${CONT_REPLACE}" "
sum by (container_label_io_kubernetes_container_name, kubernetes_io_hostname) (
  rate(container_cpu_usage_seconds_total{
    container_label_io_kubernetes_pod_namespace=~'nsm-system|spire',
    container_label_io_kubernetes_container_name!='',
    container_label_io_kubernetes_container_name!='POD',
    id!~'/docker.*',
    kubernetes_io_hostname=~'${NSC_NODE}|${NSE_NODE}'
  }[5s])
)" || return $((10 + $?))

saveData nsm-mem "NSM Memory Usage in megabytes, ${PARAM_ANNOTATION}" "${CONT_REPLACE}" "
sum by (container_label_io_kubernetes_container_name, kubernetes_io_hostname) (
  container_memory_working_set_bytes{
    container_label_io_kubernetes_pod_namespace=~'nsm-system|spire',
    container_label_io_kubernetes_container_name!='',
    container_label_io_kubernetes_container_name!='POD',
    id!~'/docker.*',
    kubernetes_io_hostname=~'${NSC_NODE}|${NSE_NODE}'
  }
) / 1024 / 1024" || return $((20 + $?))

saveData test-cpu "Test CPU Usage in cores, ${PARAM_ANNOTATION}" "${POD_REPLACE}" "
  sum by (pod, kubernetes_io_hostname) (
  label_replace(
    rate(container_cpu_usage_seconds_total{
      container_label_io_kubernetes_pod_namespace='${NAMESPACE}',
      container_label_io_kubernetes_container_name!='',
      container_label_io_kubernetes_container_name!='POD',
      id!~'/docker.*',
      kubernetes_io_hostname=~'${NSC_NODE}|${NSE_NODE}'
    }[5s]),
    'uid', '\$1', 'id', '.*/pod(.*)/.*'
  ) * on(uid) group_left(pod) kube_pod_info
)" || return $((30 + $?))

saveData test-mem "Test Memory Usage in megabytes, ${PARAM_ANNOTATION}" "${POD_REPLACE}" "
sum by (pod, kubernetes_io_hostname) (
  label_replace(
    container_memory_working_set_bytes{
      container_label_io_kubernetes_pod_namespace='${NAMESPACE}',
      container_label_io_kubernetes_container_name!='',
      container_label_io_kubernetes_container_name!='POD',
      id!~'/docker.*',
      kubernetes_io_hostname=~'${NSC_NODE}|${NSE_NODE}'
    },
    'uid', '\$1', 'id', '.*/pod(.*)/.*'
  ) * on(uid) group_left(pod) kube_pod_info
) / 1024 / 1024" || return $((40 + $?))

saveData test-cpu-average "Averaged Test CPU Usage in cores, ${PARAM_ANNOTATION}" "${CONT_REPLACE}" "
avg by (container_label_io_kubernetes_container_name, kubernetes_io_hostname) (
  rate(container_cpu_usage_seconds_total{
    container_label_io_kubernetes_pod_namespace='${NAMESPACE}',
    container_label_io_kubernetes_container_name!='',
    container_label_io_kubernetes_container_name!='POD',
    id!~'/docker.*',
    kubernetes_io_hostname=~'${NSC_NODE}|${NSE_NODE}'
  }[5s])
)" || return $((50 + $?))

saveData test-mem-average "Averaged Test Memory Usage in megabytes, ${PARAM_ANNOTATION}" "${CONT_REPLACE}" "
avg by (container_label_io_kubernetes_container_name, kubernetes_io_hostname) (
  container_memory_working_set_bytes{
    container_label_io_kubernetes_pod_namespace='${NAMESPACE}',
    container_label_io_kubernetes_container_name!='',
    container_label_io_kubernetes_container_name!='POD',
    id!~'/docker.*',
    kubernetes_io_hostname=~'${NSC_NODE}|${NSE_NODE}'
  }
) / 1024 / 1024" || return $((60 + $?))

saveData test-cpu-sum "Summarized Test CPU Usage in cores, ${PARAM_ANNOTATION}" "${CONT_REPLACE}" "
sum by (container_label_io_kubernetes_container_name, kubernetes_io_hostname) (
  rate(container_cpu_usage_seconds_total{
    container_label_io_kubernetes_pod_namespace='${NAMESPACE}',
    container_label_io_kubernetes_container_name!='',
    container_label_io_kubernetes_container_name!='POD',
    id!~'/docker.*',
    kubernetes_io_hostname=~'${NSC_NODE}|${NSE_NODE}'
  }[5s])
)" || return $((70 + $?))

saveData test-mem-sum "Summarized Test Memory Usage in megabytes, ${PARAM_ANNOTATION}" "${CONT_REPLACE}" "
sum by (container_label_io_kubernetes_container_name, kubernetes_io_hostname) (
  container_memory_working_set_bytes{
    container_label_io_kubernetes_pod_namespace='${NAMESPACE}',
    container_label_io_kubernetes_container_name!='',
    container_label_io_kubernetes_container_name!='POD',
    id!~'/docker.*',
    kubernetes_io_hostname=~'${NSC_NODE}|${NSE_NODE}'
  }
) / 1024 / 1024" || return $((80 + $?))
