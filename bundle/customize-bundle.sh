#!/bin/bash
# SPDX-FileCopyrightText: Yalan Zhang <yalzhang@redhat.com>
#
# SPDX-License-Identifier: CC0-1.0

set -euo pipefail

# This script applies downstream customizations to the generated OLM bundle manifests.
# It transforms the upstream "trusted-cluster-operator" to downstream "confidential-cluster-operator".

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
PROJECT_ROOT=$(realpath "${SCRIPT_DIR}/..")

OPERATOR_DIR="${PROJECT_ROOT}/operator"
BUNDLE_DIR="${OPERATOR_DIR}/bundle"
BUNDLE_MANIFESTS="${BUNDLE_DIR}/manifests"
BUNDLE_METADATA="${BUNDLE_DIR}/metadata"

echo "--> Customizing bundle manifests for confidential-cluster-operator..."

CSV_FILE="${BUNDLE_MANIFESTS}/trusted-cluster-operator.clusterserviceversion.yaml"

echo "-->  - Renaming CSV file..."
mv "${CSV_FILE}" "${BUNDLE_MANIFESTS}/confidential-cluster-operator.clusterserviceversion.yaml"
CSV_FILE="${BUNDLE_MANIFESTS}/confidential-cluster-operator.clusterserviceversion.yaml"

echo "-->  - Updating CSV metadata.name..."
VERSION=$(yq '.spec.version' "${CSV_FILE}")
yq -i ".metadata.name = \"confidential-cluster-operator.v${VERSION}\"" "${CSV_FILE}"

echo "-->  - Updating display name..."
yq -i '.spec.displayName = "confidential cluster operator"' "${CSV_FILE}"

echo "-->  - Updating description..."
yq -i '.spec.description = "An operator to manage confidential cluster for Red Hat OpenShift with remote attestation capabilities."' "${CSV_FILE}"

echo "-->  - Updating deployment name and labels..."
yq -i '.spec.install.spec.deployments[0].name = "confidential-cluster-operator"' "${CSV_FILE}"
yq -i '.spec.install.spec.deployments[0].spec.selector.matchLabels.app = "confidential-cluster-operator"' "${CSV_FILE}"
yq -i '.spec.install.spec.deployments[0].spec.template.metadata.labels.app = "confidential-cluster-operator"' "${CSV_FILE}"

echo "-->  - Updating container name..."
yq -i '.spec.install.spec.deployments[0].spec.template.spec.containers[0].name = "confidential-cluster-operator"' "${CSV_FILE}"

echo "-->  - Updating OPERATOR_NAME environment variable..."
yq -i '(.spec.install.spec.deployments[0].spec.template.spec.containers[0].env[] | select(.name == "OPERATOR_NAME")).value = "confidential-cluster-operator"' "${CSV_FILE}"

yq -i '(.spec.customresourcedefinitions.owned[] | select(.kind == "TrustedExecutionCluster")).description = "Represents a confidential cluster."' "${CSV_FILE}"
yq -i '(.spec.customresourcedefinitions.owned[] | select(.kind == "Machine")).description = "Represents a machine in a confidential cluster."' "${CSV_FILE}"

echo "-->  - Updating bundle metadata package name..."
yq -i '.annotations."operators.operatorframework.io.bundle.package.v1" = "confidential-cluster-operator"' "${BUNDLE_METADATA}/annotations.yaml"

echo "--> Bundle customization complete."
