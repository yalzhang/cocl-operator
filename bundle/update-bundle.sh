#!/usr/bin/env bash
# SPDX-FileCopyrightText: Yalan Zhang <yalzhang@redhat.com>
#
# SPDX-License-Identifier: CC0-1.0

set -euo pipefail

# Hardcoded image pullspecs with SHA256 digests - these will be automatically updated by Konflux component nudges
# When component builds complete, Konflux will send PRs to update these digests
# IMPORTANT: Must use @sha256: format, NOT tags - Konflux only updates digest references
export OPERATOR_IMAGE="registry.redhat.io/confidential-clusters-beta/confidential-cluster-rhel9-operator@sha256:64a53b62a7e52f50ff652152a5dc879e2ba9bbd8809e863024bfcf085821745d"
export COMPUTE_PCRS_IMAGE="registry.redhat.io/confidential-clusters-beta/compute-pcrs-rhel9@sha256:44b99ca527f4f226c4d0f3ea8cfa80a597108d85c9c767dfb4f817cf3a8499fa"
export REG_SERVER_IMAGE="registry.redhat.io/confidential-clusters-beta/registration-server-rhel9@sha256:025f09866674ef67256c5c4a349f1444b0e9d74a289e86a86730d08170386cae"
export ATTESTATION_KEY_REGISTER_IMAGE="registry.redhat.io/confidential-clusters-beta/attestation-key-register-rhel9@sha256:cabd50a2ba5ec3c2556222ca3eaab3c637c193ff002db52790aa68c82c3a690b"
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
