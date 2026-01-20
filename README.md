# Confidential Cluster Operator (cocl-operator)

A Kubernetes operator that introduces a TrustedExecutionCluster Custom Resource Definition (CRD) for declaratively managing confidential clusters and the Trustee server, which handles remote attestation. The operator ensures proper configuration of KBS, attestation policies, and resource policies within the cluster.

Downstream customization of the [trusted-execution-clusters operator](https://github.com/trusted-execution-clusters/operator) for Red Hat. Uses git submodules to track upstream and applies minimal downstream branding changes.

## Prerequisites

- `git`
- `podman` or `docker`
- `kubectl`
- `operator-sdk` (v1.38.0+)
- Kubernetes 1.24+ or OpenShift 4.12+
- Access to container registry (e.g., quay.io)

## Quick Start with kind cluster (Development)

### 1. Setup Environment

Initialize the submodule, create a local cluster, and install OLM:

```bash
# Initialize submodule
git submodule update --init

# Create local Kubernetes cluster
make -C operator cluster-up

# Install OLM
operator-sdk olm install
```

### 2. Build and Push All Images

Set your registry and tag:

```bash
export REGISTRY=quay.io/<your-username>
export TAG=0.1.0
export NAMESPACE=confidential-clusters # you can install to any namespace
export CONTAINER_CLI=docker  # or podman
```

Build and push operator and operand images:

```bash
${CONTAINER_CLI} build --build-arg build_type=release \
  -t ${REGISTRY}/cocl-operator:${TAG} \
  -f Containerfile.operator .
${CONTAINER_CLI} push ${REGISTRY}/cocl-operator:${TAG}

${CONTAINER_CLI} build --build-arg build_type=release \
  -t ${REGISTRY}/compute-pcrs:${TAG} \
  -f Containerfile.compute-pcrs .
${CONTAINER_CLI} push ${REGISTRY}/compute-pcrs:${TAG}

${CONTAINER_CLI} build --build-arg build_type=release \
  -t ${REGISTRY}/registration-server:${TAG} \
  -f Containerfile.registration-server .
${CONTAINER_CLI} push ${REGISTRY}/registration-server:${TAG}

${CONTAINER_CLI} build --build-arg build_type=release \
  -t ${REGISTRY}/attestation-key-register:${TAG} \
  -f Containerfile.attestation-key-register .
${CONTAINER_CLI} push ${REGISTRY}/attestation-key-register:${TAG}
```

Build and push OLM bundle:

**Important:** The `NAMESPACE` build argument must match the deployment namespace in step 3.

```bash
${CONTAINER_CLI} build -f Containerfile.bundle \
  --build-arg OPERATOR_IMAGE=${REGISTRY}/cocl-operator:${TAG} \
  --build-arg COMPUTE_PCRS_IMAGE=${REGISTRY}/compute-pcrs:${TAG} \
  --build-arg REG_SERVER_IMAGE=${REGISTRY}/registration-server:${TAG} \
  --build-arg ATTESTATION_KEY_REGISTER_IMAGE=${REGISTRY}/attestation-key-register:${TAG} \
  --build-arg TRUSTEE_IMAGE=quay.io/trusted-execution-clusters/key-broker-service:20260106 \
  --build-arg TAG=${TAG} \
  --build-arg NAMESPACE=${NAMESPACE} \
  -t ${REGISTRY}/cocl-operator-bundle:${TAG} .
${CONTAINER_CLI} push ${REGISTRY}/cocl-operator-bundle:${TAG}
```

### 3. Deploy Bundle and apply Custom Resources

```bash
kubectl create namespace ${NAMESPACE} || true
operator-sdk run bundle ${REGISTRY}/cocl-operator-bundle:${TAG} --namespace ${NAMESPACE}
```

### 4. Apply Custom Resources

Generate Custom Resources and apply them:

```bash
make -C operator manifests REGISTRY=${REGISTRY} TAG=${TAG} NAMESPACE=${NAMESPACE}

export TRUSTEE_ADDR="kbs-service.${NAMESPACE}.svc.cluster.local"

yq -i '.spec.publicTrusteeAddr = "'$TRUSTEE_ADDR':8080"' \
  operator/config/deploy/trusted_execution_cluster_cr.yaml

kubectl apply -f operator/config/deploy/trusted_execution_cluster_cr.yaml
kubectl apply -f operator/config/deploy/approved_image_cr.yaml
```

Refer to [upstream documentation](https://github.com/trusted-execution-clusters/operator) for VM setup and attestation testing instructions.

## Cleanup

Remove the operator:

```bash
operator-sdk cleanup cocl-operator --namespace ${NAMESPACE}
```

Remove the cluster (development only):

```bash
make -C operator cluster-down
```

## Repository Structure

```
cocl-operator/
├── operator/                            # Git submodule (upstream)
├── Containerfile.operator               # Operator image
├── Containerfile.compute-pcrs           # Compute-pcrs operand
├── Containerfile.registration-server    # Registration-server operand
├── Containerfile.attestation-key-register  # Attestation-key-register operand
├── Containerfile.bundle                 # OLM bundle
├── bundle/
│   └── customize-bundle.sh              # Applies downstream branding to OLM bundle
└── hack/
    └── customize-manifests.sh           # Customizes runtime deployment manifests (non-OLM)
```

## Links

- **Upstream**: https://github.com/trusted-execution-clusters/operator
- **OLM**: https://olm.operatorframework.io/
