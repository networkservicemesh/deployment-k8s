## Setup spire for two clusters

This example shows how to simply configure two spire from clusters to know each other.


## Run

1. Make sure that you have two KUBECONFIG files.

Check `KUBECONFIG1` env:
```bash
[[ ! -z $KUBECONFIG1 ]]
```

Check `KUBECONFIG2` env:
```bash
[[ ! -z $KUBECONFIG2 ]]
```

2. Setup spire

**Apply spire resources for the first cluster:**
```bash
export KUBECONFIG=$KUBECONFIG1
```

Create spire server conf
```bash 
cat > server.conf <<EOF
server {
    bind_address = "0.0.0.0"
    bind_port = "8081"
    registration_uds_path = "/tmp/spire-registration.sock"
    trust_domain = "nsm.cluster1"
    data_dir = "/run/spire/data"
    log_level = "DEBUG"
    #AWS requires the use of RSA. EC cryptography is not supported
    ca_key_type = "rsa-2048"
    default_svid_ttl = "1h"
    ca_subject = {
        country = ["US"],
        organization = ["SPIFFE"],
        common_name = "",
    }
    federation {
        bundle_endpoint {
            address = "0.0.0.0"
            port = 8443
        }
        federates_with "nsm.cluster2" {
            bundle_endpoint {
                address = "172.18.0.4"
                port = 8443
            }
        }
    }
}

plugins {
    DataStore "sql" {
        plugin_data {
            database_type = "sqlite3"
            connection_string = "/run/spire/data/datastore.sqlite3"
        }
    }
    NodeAttestor "k8s_sat" {
        plugin_data {
            clusters = {
                # NOTE: Change this to your cluster name
                "nsm.cluster1" = {
                    use_token_review_api_validation = true
                    service_account_whitelist = ["spire:spire-agent"]
                }
            }
        }
    }
    NodeResolver "noop" {
        plugin_data {}
    }
    KeyManager "disk" {
        plugin_data {
            keys_path = "/run/spire/data/keys.json"
        }
    }
    Notifier "k8sbundle" {
        plugin_data {
        }
    }
}
EOF
```

```bash
cat > agent.conf <<EOF
agent {
    data_dir = "/run/spire"
    log_level = "DEBUG"
    server_address = "spire-server"
    server_port = "8081"
    socket_path = "/run/spire/sockets/agent.sock"
    trust_bundle_path = "/run/spire/bundle/bundle.crt"
    trust_domain = "nsm.cluster1"
}

plugins {
    NodeAttestor "k8s_sat" {
    plugin_data {
        # NOTE: Change this to your cluster name
        cluster = "nsm.cluster1"
    }
    }

    KeyManager "memory" {
    plugin_data {
    }
    }

    WorkloadAttestor "k8s" {
    plugin_data {
        # Defaults to the secure kubelet port by default.
        # Minikube does not have a cert in the cluster CA bundle that
        # can authenticate the kubelet cert, so skip validation.
        skip_kubelet_verification = true
    }
    }

    WorkloadAttestor "unix" {
        plugin_data {
        }
    }
}
EOF
```

```bash
kubectl apply -k .
```

Wait for PODs status ready:
```bash
kubectl wait -n spire --timeout=1m --for=condition=ready pod -l app=spire-agent
```
```bash
kubectl wait -n spire --timeout=1m --for=condition=ready pod -l app=spire-server
```

Register spire agents in the spire server:
```bash
kubectl exec -n spire spire-server-0 -- \
/opt/spire/bin/spire-server entry create \
-spiffeID spiffe://nsm.cluster1/ns/spire/sa/spire-agent \
-selector k8s_sat:cluster:nsm.cluster1 \
-selector k8s_sat:agent_ns:spire \
-selector k8s_sat:agent_sa:spire-agent \
-node
```

**Apply spire resources for the second cluster:**
```bash
export KUBECONFIG=$KUBECONFIG2
```

Create spire server conf
```bash 
cat > server.conf <<EOF
server {
    bind_address = "0.0.0.0"
    bind_port = "8081"
    registration_uds_path = "/tmp/spire-registration.sock"
    trust_domain = "nsm.cluster2"
    data_dir = "/run/spire/data"
    log_level = "DEBUG"
    #AWS requires the use of RSA. EC cryptography is not supported
    ca_key_type = "rsa-2048"
    default_svid_ttl = "1h"
    ca_subject = {
        country = ["US"],
        organization = ["SPIFFE"],
        common_name = "",
    }
    federation {
        bundle_endpoint {
            address = "0.0.0.0"
            port = 8443
        }
        federates_with "nsm.cluster1" {
            bundle_endpoint {
                address = "172.18.0.2"
                port = 8443
            }
        }
    }
}

plugins {
    DataStore "sql" {
        plugin_data {
            database_type = "sqlite3"
            connection_string = "/run/spire/data/datastore.sqlite3"
        }
    }
    NodeAttestor "k8s_sat" {
        plugin_data {
            clusters = {
                # NOTE: Change this to your cluster name
                "nsm.cluster2" = {
                    use_token_review_api_validation = true
                    service_account_whitelist = ["spire:spire-agent"]
                }
            }
        }
    }
    NodeResolver "noop" {
        plugin_data {}
    }
    KeyManager "disk" {
        plugin_data {
            keys_path = "/run/spire/data/keys.json"
        }
    }
    Notifier "k8sbundle" {
        plugin_data {
        }
    }
}
EOF
```

```bash
cat > agent.conf <<EOF
agent {
    data_dir = "/run/spire"
    log_level = "DEBUG"
    server_address = "spire-server"
    server_port = "8081"
    socket_path = "/run/spire/sockets/agent.sock"
    trust_bundle_path = "/run/spire/bundle/bundle.crt"
    trust_domain = "nsm.cluster2"
}

plugins {
    NodeAttestor "k8s_sat" {
    plugin_data {
        # NOTE: Change this to your cluster name
        cluster = "nsm.cluster2"
    }
    }

    KeyManager "memory" {
    plugin_data {
    }
    }

    WorkloadAttestor "k8s" {
    plugin_data {
        # Defaults to the secure kubelet port by default.
        # Minikube does not have a cert in the cluster CA bundle that
        # can authenticate the kubelet cert, so skip validation.
        skip_kubelet_verification = true
    }
    }

    WorkloadAttestor "unix" {
        plugin_data {
        }
    }
}
EOF
```

```bash
kubectl apply -k .
```

Wait for PODs status ready:
```bash
kubectl wait -n spire --timeout=1m --for=condition=ready pod -l app=spire-agent
```
```bash
kubectl wait -n spire --timeout=1m --for=condition=ready pod -l app=spire-server
```

Register spire agents in the spire server:
```bash
kubectl exec -n spire spire-server-0 -- \
/opt/spire/bin/spire-server entry create \
-spiffeID spiffe://nsm.cluster2/ns/spire/sa/spire-agent \
-selector k8s_sat:cluster:nsm.cluster2 \
-selector k8s_sat:agent_ns:spire \
-selector k8s_sat:agent_sa:spire-agent \
-node
```

3. Bootstrap Federation

To enable the SPIRE Servers to fetch the trust bundles from each other they need each other's trust bundle first, because they have to authenticate the SPIFFE identity of the federated server that is trying to access the federation endpoint. Once federation is bootstrapped, the trust bundle updates are fetched trough the federation endpoint API using the current trust bundle.

Switch to first cluster:

```bash
export KUBECONFIG=$KUBECONFIG1
```

Get and store bundle of the first cluster:
```bash
bundle=$(kubectl exec spire-server-0 -n spire -- bin/spire-server bundle show -format spiffe)
```

Switch to the second cluster:
```bash
export KUBECONFIG=$KUBECONFIG2
```

Set bundle for the second cluster:
```bash
echo $bundle | kubectl exec -i spire-server-0 -n spire -- bin/spire-server bundle set -format spiffe -id "spiffe://nsm.cluster1"
```

Get and store bundle of the second cluster:
```bash
bundle=$(kubectl exec spire-server-0 -n spire -- bin/spire-server bundle show -format spiffe)
```

Switch to the first cluster:
```bash
export KUBECONFIG=$KUBECONFIG1
```

Set bundle for the first cluster:
```bash
echo $bundle | kubectl exec -i spire-server-0 -n spire -- bin/spire-server bundle set -format spiffe -id "spiffe://nsm.cluster2"
```


## Cleanup

Cleanup spire for the first cluster:
```bash
export KUBECONFIG=$KUBECONFIG1
```

Delete ns:
```bash
kubectl delete ns spire
```

Cleanup spire for the second cluster:
```bash
export KUBECONFIG=$KUBECONFIG2
```

Delete ns:
```bash
kubectl delete ns spire
```
