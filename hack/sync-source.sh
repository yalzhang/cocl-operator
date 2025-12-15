#!/usr/bin/env bash

set -euo pipefail

UPSTREAM_REPO="https://github.com/trusted-execution-clusters/operator.git"
DEST_DIR="operator"

UPSTREAM_REF="$1"        # branch / tag / commit

if [[ -z "${UPSTREAM_REF}" ]]; then
  echo "Usage: sync-source.sh <upstream-ref>"
  exit 1
fi

TMP_DIR="$(mktemp -d)"

echo "==> Fetching upstream repo"
echo "    Repo: ${UPSTREAM_REPO}"
echo "    Ref : ${UPSTREAM_REF}"

git clone --no-checkout "${UPSTREAM_REPO}" "${TMP_DIR}"
git -C "${TMP_DIR}" checkout "${UPSTREAM_REF}"

echo "==> Syncing upstream content into ${DEST_DIR}"

rm -rf "${DEST_DIR}"
mkdir -p "${DEST_DIR}"

(
  cd "${TMP_DIR}" || exit 1
  tar cf - --exclude='.git' --exclude='.github' .
) | (
  cd "${DEST_DIR}" || exit 1
  tar xf -
)

rm -rf "${TMP_DIR}"

echo "==> Upstream fetch completed"
