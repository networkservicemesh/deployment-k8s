## Requires

- [spire](../spire)

## Includes

- [VFIO Connection](../use-cases/Vfio2Noop)
- [Kernel Connection](../use-cases/SriovKernel2Noop)
- [Memif to Memif Connection](../use-cases/Memif2Memif)
- [Kernel to Kernel Connection](../use-cases/Kernel2Kernel)
- [Kernel to VXLAN to Kernel Connection](../use-cases/Kernel2Vxlan2Kernel)
- [Kernel to Kernel Connection & VFIO Connection](../use-cases/Kernel2Kernel&Vfio2Noop)
- [Kernel to VXLAN to Kernel Connection & VFIO Connection](../use-cases/Kernel2Vxlan2Kernel&Vfio2Noop)

## Run

Create ns for deployments:
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

Create patch for the SR-IOV-chain forwarder:
```bash
cat > patch-forwarder-vpp.yaml <<EOF
---
- op: replace
  path: /metadata/name
  value: forwarder-sriov
- op: replace
  path: /metadata/labels/app
  value: forwarder-vpp
- op: replace
  path: /spec/selector/matchLabels/app
  value: forwarder-sriov
- op: replace
  path: /spec/template/metadata/labels/app
  value: forwarder-sriov
- op: add
  path: /spec/template/spec/containers/0/env/-
  value:
    name: NSM_SRIOV_CONFIG_FILE
    value: /var/lib/networkservicemesh/sriov.config
EOF
```

Apply NSM resources for basic tests:
```bash
kubectl apply -k .
```

Create patch for the VPP-chain forwarder:
```bash
cat > patch-forwarder-vpp.yaml <<EOF
---
- op: replace
  path: /metadata/name
  value: forwarder-vpp
- op: replace
  path: /metadata/labels/app
  value: forwarder-vpp
- op: replace
  path: /spec/selector/matchLabels/app
  value: forwarder-vpp
- op: replace
  path: /spec/template/metadata/labels/app
  value: forwarder-vpp
- op: add
  path: /spec/template/spec/containers/0/env/-
  value:
    name: NSM_SRIOV_CONFIG_FILE
    value: /dev/null
EOF
```

Apply NSM resources for basic tests:
```bash
kubectl apply -k .
```

## Cleanup

Delete ns:
```bash
kubectl delete ns nsm-system
```