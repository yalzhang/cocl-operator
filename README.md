# Confidential Cluster Operator (cocl-operator)

This repository provides downstream customizations for the `trusted-execution-clusters` operator. Customizations are applied via command-line variable overrides and a manifest customization script.

## Prerequisites

- `git`
- `go` (version 1.25+)
- `rust` & `cargo`
- `kind` (v0.17.0+)
- `kubectl`
- A container runtime CLI (`podman` or `docker`).

## Workflow

### 1. Configure Upstream Source

The `upstream-ref.txt` file defines the specific upstream commit to be used. You can modify this file to target a different version of the upstream operator.

### 2. Set Up Local Cluster & Deploy

The following steps will sync the source code, apply customizations, and deploy the operator to a local `kind` cluster.

```bash
# 1. Sync the upstream source code
source upstream-ref.txt
./hack/sync-source.sh "${UPSTREAM_REF}"

# 2. Install build tools and create the kind cluster
export CONTAINER_CLI=docker  # Skip this if you use podman
export RUNTIME=docker        # Skip this if you use podman
make -C operator build-tools
make -C operator cluster-up

# 3. Generate the deployment manifests with customized names
export NAMESPACE=confidential-clusters
export REGISTRY=localhost:5000
export TAG=latest
make -C operator \
  NAMESPACE=${NAMESPACE} \
  REGISTRY=${REGISTRY} \
  OPERATOR_IMAGE=${REGISTRY}/cocl-operator:${TAG} \
  manifests
./hack/customize-manifests.sh

# 4. Build and push the images
make -C operator \
  REGISTRY=${REGISTRY} \
  OPERATOR_IMAGE=${REGISTRY}/cocl-operator:${TAG} \
  push

# 5. Deploy the operator
# Replace TRUSTEE_ADDR with the IP address that the libvirt VM can access.
make -C operator \
  NAMESPACE=${NAMESPACE} \
  TRUSTEE_ADDR=192.168.122.1 \
  install
```

### Cleaning Up

To tear down the `kind` cluster and remove all deployed resources, run:

```bash
make -C operator cluster-down
```
