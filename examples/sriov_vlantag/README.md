# SR-IOV VLAN tagged connection examples

## Requires

- [spire](../spire/single_cluster)

## Includes

- [VLAN tagged VFIO Connection](../use-cases/Vfio2NoopVlanTag)
- [VLAN tagged Kernel Connection](../use-cases/SriovKernel2NoopVlanTag)

## SR-IOV config

These tests require [SR-IOV config](../../doc/SRIOV_config.md) created on both `master` and `worker` nodes and located
under `/var/lib/networkservicemesh/sriov.config`.

Required service domains and capabilities for the `master` node are:
```yaml
    capabilities:
      - 10G
    serviceDomains:
      - worker.domain
```
For the `worker` node:
```yaml
    capabilities:
      - 10G
    serviceDomains:
      - master.domain
```

## Run

Apply NSM resources for sriov tests:
```bash
kubectl apply -k https://github.com/networkservicemesh/deployments-k8s/examples/sriov?ref=b95b9f08053635f1309b35bb032a5ab3aa2b1cf6
```

## Cleanup

To free resources follow the next commands:

```bash
kubectl delete mutatingwebhookconfiguration nsm-mutating-webhook
kubectl delete ns nsm-system
```
