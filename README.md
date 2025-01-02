# deployment-k8s

![GithubActions Build Status](https://github.com/networkservicemesh/integration-k8s-kind/actions/workflows/ci.yaml/badge.svg)
[![Weekly minutes](https://img.shields.io/badge/Weekly%20Meeting%20Minutes-Tue%208am%20PT-blue.svg?style=plastic")](https://docs.google.com/document/d/1C9NKjo0PWNWypROEO9-Y6haw5h9Xmurvl14SXpciz2Y/edit#heading=h.rc9df0a6n3ng)
[![Mailing list](https://img.shields.io/badge/Mailing%20List-networkservicemesh-blue.svg?style=plastic")](https://groups.google.com/forum/#!forum/networkservicemesh)
[![GitHub license](https://img.shields.io/badge/license-Apache%20license%202.0-blue.svg)](https://github.com/networkservicemesh/cloudtest/blob/master/LICENSE)
[![Slack Channel](https://img.shields.io/badge/Slack:-%23nsm%20on%20CNCF%20Slack-blue.svg?style=plastic&logo=slack)](https://cloud-native.slack.com/messages/CHQNNUPN1/files/FHU5KB3PW/#nsm)
[![Slack Invite](https://img.shields.io/badge/Slack-CNCF%20Slack%20Invite-blue.svg?style=plastic&logo=slack)](https://slack.cncf.io/)
[![CII Best Practices](https://bestpractices.coreinfrastructure.org/projects/2725/badge)](https://bestpractices.coreinfrastructure.org/projects/2725)

<p align="center">
  <a href="https://www.networkservicemesh.io/"><img src="https://raw.githubusercontent.com/cncf/artwork/refs/heads/main/projects/networkservicemesh/horizontal/color/networkservicemesh-horizontal-color.png" width="70%" height="70%"></a>
</p>

**deployments-k8s** repository provides native kubernetes yaml deployments and markdown examples for Network Service Mesh.

## Contents

* [Applications](./apps)
* Examples
    * [Basic examples](./examples/basic) 
    * [Interdomain and floating interdomain examples](./examples/interdomain/suites)
        * [NSM and Istio interdomain example](./examples/interdomain/usecases/nsm_istio_booking/)
        * [NSM and Monolith interdomain example](./examples/k8s_monolith/)
        * [NSM and floating interdomain vl3 example](./examples/interdomain/usecases/floating_vl3-basic/)
        * [And other usecases](./examples/interdomain/usecases/)
    * [Open telemetry examples](./examples/observability/)
    * [Features examples](./examples/features)
        * [NSM+Istio example](./examples/nsm+istio)
        * [OPA example](./examples/features/opa)
        * [IPv6 examples](./examples/features/ipv6)
        * [Dual stack example](./examples/features/dual-stack)
        * [Jaeger example](./examples/features/jaeger)
        * [DNS Example](./examples/features/dns)
        * [Admisson webhook Example](./examples/features/webhook)
        * [Policy based routing Example](./examples/features/policy-based-routing/)
        * [NSM Webhook Example](./examples/features/webhook)
        * [Mutually aware nses Example](./examples/features/mutually-aware-nses/)
        * [vl3 + Topology aware scale from zero Example](./examples/features/vl3-scale-from-zero/)     
        * [Select forwarder Example](./examples/features/select-forwarder/) 
        * [Exclude prefixes Example](./examples/features/exclude-prefixes/)
        * [Topology aware scale from zero](./examples/features/scale-from-zero)
        * [And other features](./examples/features)
    * [SRIOV examples](./examples/sriov)
    * [OVS examples](./examples/ovs)
    * [Memory registry backend examples](./examples/memory)
    * [Heal and resilience examples](./examples/heal)

## Requirements
Minimum required ```kubectl``` client version is ```v1.21.0```

## Using local applications

By default `deployments-k8s` uses applications in github ref format. For local development you can use [`to-local.sh`](./to-local.sh)
script:
```
$ ./to-local.sh
```
It translates all github refs to local paths. If you want to switch back to github refs, you can use [`to-ref.sh`](./to-ref.sh)
script:
```
$ ./to-ref.sh
```
For some cases you may probably need to share your local changes with someone else. In such case please use [`to-export.sh`](./to-export.sh)
instead of `to-local.sh`:
```
$ ./to-export.sh
```
IMPORTANT: `to-export.sh` cannot be undone back to github refs format with `to-ref.sh`. Please don't use it for local
development, use it only for sharing your branch with someone else.