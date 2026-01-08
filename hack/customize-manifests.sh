#!/bin/bash
set -euo pipefail

# This script applies customizations to the fetched upstream operator source code.
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
PROJECT_ROOT=$(realpath "${SCRIPT_DIR}/..")

OPERATOR_DIR="${PROJECT_ROOT}/operator"
OPERATOR_DEPLOY_FILE="${OPERATOR_DIR}/config/deploy/operator.yaml"
CLUSTER_CR_FILE="${OPERATOR_DIR}/config/deploy/trusted_execution_cluster_cr.yaml"
KIND_FORWARD_REGISTER_FILE="${OPERATOR_DIR}/kind/register-forward.yaml"
KIND_FORWARD_KBS_FILE="${OPERATOR_DIR}/kind/kbs-forward.yaml"

LOCALBIN="${OPERATOR_DIR}/bin"
YQ_VERSION=v4.48.1
YQ="${LOCALBIN}/yq-${YQ_VERSION}"
TRUSTEE_ADDR="${TRUSTEE_ADDR:-}"
# Read environment variables with defaults, consistent with the root Makefile
REGISTRY="${REGISTRY:-quay.io/confidential-clusters}"
TAG="${TAG:-latest}"
NAMESPACE="${NAMESPACE:-confidential-clusters}"

echo "--> Customizing manifests..."
# Check for yq
if [ ! -f "$YQ" ]; then
    echo "!!! yq not found at ${YQ}. Please ensure it has been installed by running 'make -C operator build-tools' from the project root."
    exit 1
fi

# 1. Patch the Namespace name
echo "-->  - Patching Namespace (${OPERATOR_DEPLOY_FILE})..."
"$YQ" eval-all -i "(select(.kind == \"Namespace\") | .metadata.name) = \"${NAMESPACE}\"" "${OPERATOR_DEPLOY_FILE}"

# 2. Patch the Deployment
echo "-->  - Patching Deployment (${OPERATOR_DEPLOY_FILE})..."
"$YQ" eval-all -i '(select(.kind == "Deployment") | .metadata.name) = "cocl-operator"' "${OPERATOR_DEPLOY_FILE}"
"$YQ" eval-all -i '(select(.kind == "Deployment") | .metadata.labels.app) = "cocl-operator"' "${OPERATOR_DEPLOY_FILE}"
"$YQ" eval-all -i '(select(.kind == "Deployment") | .spec.selector.matchLabels.app) = "cocl-operator"' "${OPERATOR_DEPLOY_FILE}"
"$YQ" eval-all -i '(select(.kind == "Deployment") | .spec.template.metadata.labels.app) = "cocl-operator"' "${OPERATOR_DEPLOY_FILE}"
"$YQ" eval-all -i '(select(.kind == "Deployment") | .spec.template.spec.containers[0].name) = "cocl-operator"' "${OPERATOR_DEPLOY_FILE}"

# 3. Patch the TrustedExecutionCluster Custom Resource
echo "-->  - Patching TrustedExecutionCluster CR (${CLUSTER_CR_FILE})..."
"$YQ" -i '.metadata.name = "confidential-cluster"' "${CLUSTER_CR_FILE}"
"$YQ" -i ".spec.pcrsComputeImage = \"${REGISTRY}/compute-pcrs:${TAG}\"" "${CLUSTER_CR_FILE}"
"$YQ" -i ".spec.registerServerImage = \"${REGISTRY}/registration-server:${TAG}\"" "${CLUSTER_CR_FILE}"
"$YQ" -i ".spec.attestationKeyRegisterImage = \"${REGISTRY}/attestation-key-register:${TAG}\"" "${CLUSTER_CR_FILE}"

# 4. Patch config/rbac/kustomization.yaml to set the default namespace and the label
echo "-->  - Setting default namespace in config/rbac/kustomization.yaml..."
"$YQ" -i ".namespace = \"${NAMESPACE}\"" "${OPERATOR_DIR}/config/rbac/kustomization.yaml"
"$YQ" -i '.commonLabels."app.kubernetes.io/name" = "cocl-operator"' "${OPERATOR_DIR}/config/rbac/kustomization.yaml"

echo "--> Customization complete."
