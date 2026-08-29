#!/usr/bin/env bash
# Gate oracle wrapper for NAUT-GATE-CHELIS-TEST.
#
# Runs the declared selection (`chelis test tests/ --timeout 600 --jobs auto`)
# and applies the declared normalization: exit status zero is `pass`, any
# other completed exit is `fail`. The semantic verdict travels on the first
# stdout line in the pinned `spec-provenance-result/v1` protocol; the full
# chelis output goes to stderr, which the receipt retains as noncanonical
# raw bytes only.
set -u

"${CHELIS_HOME:-$HOME/.chelis}/bin/chelis" test tests/ --timeout 600 --jobs auto 1>&2
status=$?

if [ "$status" -eq 0 ]; then
  verdict=pass
else
  verdict=fail
fi
printf 'spec-provenance-result/v1\t%s\n' "$verdict"
exit 0
