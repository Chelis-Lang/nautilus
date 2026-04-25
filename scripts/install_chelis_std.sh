#!/usr/bin/env bash
# Install chelis-std v0.1.0 into the local Reef registry from the
# Chelis monorepo's prebuilt artifact.
#
# Why this exists: chelis v0.2.4's `chelis reef publish` requires a
# buildable source tree, and the chelis monorepo's chelis-std source
# does not type-check standalone (`unbound variable:
# test_assert_eq_tensor_int64`). The chelis monorepo nonetheless
# ships a prebuilt `chelis-std-0.1.0.{chb,tar.zst}` under
# `packages/chelis-std/dist/` at every release tag, and chelis v0.2.4
# is happy to consume them if they're placed in
# `~/.chelis/reef/packages/chelis-std/0.1.0/` with a matching
# `~/.chelis/reef/index.json` entry.
#
# Until upstream ships chelis-std as its own release artifact (or
# `chelis reef install <name>=<version>` lands), this script is the
# CI bootstrap path. See docs/UPSTREAM_BUGS.md "v0.2.4 chelis-std
# bootstrap" for the upstream issue.
#
# Usage:
#   GH_TOKEN=...  CHELIS_TAG=v0.2.4  scripts/install_chelis_std.sh
#
# Env:
#   GH_TOKEN      — PAT with `contents: read` on Chelis-Lang/chelis
#   CHELIS_TAG    — tag of the chelis monorepo to fetch chelis-std from
#                   (defaults to v0.2.4)
set -euo pipefail

CHELIS_TAG="${CHELIS_TAG:-v0.2.4}"
WORK_DIR="${WORK_DIR:-/tmp/chelis-monorepo-for-std}"
REEF_HOME="${HOME}/.chelis/reef"

echo "[chelis-std-install] cloning Chelis-Lang/chelis at ${CHELIS_TAG} into ${WORK_DIR}"
rm -rf "${WORK_DIR}"
gh repo clone Chelis-Lang/chelis "${WORK_DIR}" -- --depth 1 --branch "${CHELIS_TAG}" --quiet

DIST="${WORK_DIR}/packages/chelis-std/dist"
TARBALL="${DIST}/chelis-std-0.1.0.tar.zst"
CHB="${DIST}/chelis-std-0.1.0.chb"
test -f "${TARBALL}" || { echo "missing ${TARBALL}" >&2; exit 1; }
test -f "${CHB}"     || { echo "missing ${CHB}"     >&2; exit 1; }

mkdir -p "${REEF_HOME}/packages/chelis-std/0.1.0"
cp "${TARBALL}" "${CHB}" "${REEF_HOME}/packages/chelis-std/0.1.0/"

TSHA=$(sha256sum "${TARBALL}" | awk '{print $1}')
CSHA=$(sha256sum "${CHB}"     | awk '{print $1}')

cat > "${REEF_HOME}/index.json" <<EOF
{
  "packages": {
    "chelis-std": [
      {
        "version": "0.1.0",
        "compiler": "=0.2.4",
        "archive_sha256": "${TSHA}",
        "shell_sha256": "${CSHA}"
      }
    ]
  }
}
EOF

echo "[chelis-std-install] installed chelis-std v0.1.0 (archive sha=${TSHA:0:12}…)"
echo "[chelis-std-install] index at ${REEF_HOME}/index.json"
