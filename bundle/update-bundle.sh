#!/usr/bin/env bash
# SPDX-FileCopyrightText: Yalan Zhang <yalzhang@redhat.com>
#
# SPDX-License-Identifier: CC0-1.0

set -euo pipefail

# Hardcoded image pullspecs with SHA256 digests - these will be automatically updated by Konflux component nudges
# When component builds complete, Konflux will send PRs to update these digests
# IMPORTANT: Must use @sha256: format, NOT tags - Konflux only updates digest references
export OPERATOR_IMAGE="quay.io/redhat-user-workloads/cocl-operator-tenant/confidential-cluster-operator@sha256:35a44986c1991eb0030de9575c9f4d77276bc71f5408a9af8e4af9af77a155bd"
export COMPUTE_PCRS_IMAGE="quay.io/redhat-user-workloads/cocl-operator-tenant/compute-pcrs@sha256:dac12b9fe8bc92bbc79290cfaf311436e02ba7024692022d921a000ad5586797"
export REG_SERVER_IMAGE="quay.io/redhat-user-workloads/cocl-operator-tenant/registration-server@sha256:3ca734f4dd86fa0d2a1c9da110e545dc7f4b1c0771434a14b2386310b9c257eb"
export ATTESTATION_KEY_REGISTER_IMAGE="quay.io/redhat-user-workloads/cocl-operator-tenant/attestation-key-register@sha256:88678999eb4c49dccda13325f1caed42af9f8c90235392c5547a8b759111443b"
export TRUSTEE_IMAGE="quay.io/trusted-execution-clusters/key-broker-service@sha256:1cf0ba784437f83e7f459e91f17615c9bf5c8068a0212b72fd9fc1babcbf6764"

# These are passed in from the Containerfile build args
: "${TAG:?TAG must be set}"
# NAMESPACE is optional - upstream Makefile has default (trusted-execution-clusters)
# This is only used during manifest generation and is removed from RBAC bindings
# The final bundle is namespace-agnostic and can be installed anywhere
: "${NAMESPACE:=trusted-execution-clusters}"

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
PROJECT_ROOT=$(realpath "${SCRIPT_DIR}/..")

echo "=> Building bundle with the following images:"
echo "   OPERATOR_IMAGE=${OPERATOR_IMAGE}"
echo "   COMPUTE_PCRS_IMAGE=${COMPUTE_PCRS_IMAGE}"
echo "   REG_SERVER_IMAGE=${REG_SERVER_IMAGE}"
echo "   ATTESTATION_KEY_REGISTER_IMAGE=${ATTESTATION_KEY_REGISTER_IMAGE}"
echo "   TRUSTEE_IMAGE=${TRUSTEE_IMAGE}"
echo "   TAG=${TAG}"
echo "   NAMESPACE=${NAMESPACE}"
echo ""

# Extract REGISTRY from OPERATOR_IMAGE (everything before the last /)
export REGISTRY="${OPERATOR_IMAGE%/*}"

# Generate manifests first (creates CRDs and RBAC rules)
echo "=> Generating manifests..."
make -C "${PROJECT_ROOT}/operator" manifests \
    NAMESPACE="${NAMESPACE}" \
    REGISTRY="${REGISTRY}" \
    TAG="${TAG}"

# Generate bundle using the Makefile
# The Makefile will:
# - Copy CRDs from config/crd/
# - Copy RBAC from config/rbac/
# - Inject RBAC rules into CSV
# - Patch image references with the hardcoded images above
# - Validate the bundle with operator-sdk
echo "=> Generating bundle..."
cd "${PROJECT_ROOT}/operator" && \
    make bundle \
    TAG="${TAG}" \
    NAMESPACE="${NAMESPACE}" \
    REGISTRY="${REGISTRY}" \
    OPERATOR_IMAGE="${OPERATOR_IMAGE}" \
    COMPUTE_PCRS_IMAGE="${COMPUTE_PCRS_IMAGE}" \
    REG_SERVER_IMAGE="${REG_SERVER_IMAGE}" \
    ATTESTATION_KEY_REGISTER_IMAGE="${ATTESTATION_KEY_REGISTER_IMAGE}" \
    TRUSTEE_IMAGE="${TRUSTEE_IMAGE}"

# Apply downstream-specific customizations to the generated bundle
echo "=> Applying downstream customizations..."
bash "${PROJECT_ROOT}/bundle/customize-bundle.sh"

echo "=> Bundle generation complete!"
