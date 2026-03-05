#!/usr/bin/env bash
# SPDX-FileCopyrightText: Yalan Zhang <yalzhang@redhat.com>
#
# SPDX-License-Identifier: CC0-1.0

set -euo pipefail

# Hardcoded image pullspecs with SHA256 digests - these will be automatically updated by Konflux component nudges
# When component builds complete, Konflux will send PRs to update these digests
# IMPORTANT: Must use @sha256: format, NOT tags - Konflux only updates digest references
export OPERATOR_IMAGE="registry.stage.redhat.io/confidential-clusters-beta/confidential-cluster-rhel9-operator@sha256:345c618885c0635cbf9b39420e3ea92669a9268d4a21c6db4bda54358552bb98"
export COMPUTE_PCRS_IMAGE="registry.stage.redhat.io/confidential-clusters-beta/compute-pcrs-rhel9@sha256:93d4c06518e570428b98ebddd901598598bec01ef7cc42350a1fc8ce73c4c0f6"
export REG_SERVER_IMAGE="registry.stage.redhat.io/confidential-clusters-beta/registration-server-rhel9@sha256:274ecbf33ac0738ee139f9d972971e6b082596f857ebc062fa9d4c64b7f58f77"
export ATTESTATION_KEY_REGISTER_IMAGE="registry.stage.redhat.io/confidential-clusters-beta/attestation-key-register-rhel9@sha256:a26e959b09492e8eaac08f749f35855c57e6b8ce241f80f1eb6ffd5efb5451db"
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
