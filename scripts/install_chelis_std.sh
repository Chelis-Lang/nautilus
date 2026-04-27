#!/usr/bin/env bash
# Install chelis-std v0.1.0 into the local Reef registry from the
# Chelis monorepo's prebuilt artifact.
#
# Why this exists: chelis-std is not shipped as a release artifact of
# Chelis-Lang/chelis (only the toolchain tarball is). The prebuilt
# `chelis-std-0.1.0.{chb,tar.zst}` ships inside the chelis monorepo at
# every release tag under `packages/chelis-std/dist/`. This script
# clones that tag and hands it to `chelis reef install --from-monorepo`,
# which (as of chelis v0.3.0) is the sanctioned way to populate the
# local registry without source-rebuilding chelis-std.
#
# Pre-v0.3.0 history: this script used to hand-roll the install by
# copying files into ~/.chelis/reef/packages/<name>/<version>/ and
# writing the index.json by hand, because chelis v0.2.x had no
# `reef install` subcommand. v0.3.0 shipped the proper command — see
# `chelis reef install --help` and docs/UPSTREAM_BUGS.md
# ("v0.2.4 chelis-std bootstrap" — now resolved).
#
# Usage:
#   GH_TOKEN=...  CHELIS_TAG=v0.3.0  scripts/install_chelis_std.sh
#
# Env:
#   GH_TOKEN      — PAT with `contents: read` on Chelis-Lang/chelis
#   CHELIS_TAG    — tag of the chelis monorepo to fetch chelis-std from
#                   (defaults to v0.3.0)
#   CHELIS_BIN    — chelis binary to use for `reef install`. Defaults
#                   to whichever `chelis` is on PATH; CI sets this to
#                   the v0.3.0 toolchain it just downloaded.
set -euo pipefail

CHELIS_TAG="${CHELIS_TAG:-v0.3.0}"
CHELIS_BIN="${CHELIS_BIN:-chelis}"
WORK_DIR="${WORK_DIR:-/tmp/chelis-monorepo-for-std}"

echo "[chelis-std-install] cloning Chelis-Lang/chelis at ${CHELIS_TAG} into ${WORK_DIR}"
rm -rf "${WORK_DIR}"
gh repo clone Chelis-Lang/chelis "${WORK_DIR}" -- --depth 1 --branch "${CHELIS_TAG}" --quiet

echo "[chelis-std-install] running chelis reef install --from-monorepo"
"${CHELIS_BIN}" reef install --from-monorepo "${WORK_DIR}" chelis-std

echo "[chelis-std-install] done"
