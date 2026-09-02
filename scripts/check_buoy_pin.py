#!/usr/bin/env python3
"""Run the fail-closed check of the Buoy provenance pin.

The pin must record one exact 40-hex revision and the required BLAKE3-256 feature.
The Nix consumer must use the same feature and only the recorded revision.
The repository must not contain a floating reference or vendored Buoy copy.
"""

from __future__ import annotations

import argparse
import pathlib
import re
import sys
import tomllib

REQUIRED_BUOY_FIELDS = (
    "repository",
    "revision",
    "consumer_package",
    "declared_source",
    "reviewed_source_content_hash",
    "digest_feature",
    "provenance_command",
)


def fail(code: str, detail: str) -> None:
    print(f"{code}: {detail}", file=sys.stderr)
    raise SystemExit(1)


def check(repo: pathlib.Path) -> None:
    pin_path = repo / "provenance" / "buoy-pin.toml"
    if not pin_path.is_file():
        fail("NAUT-PIN-MISSING", str(pin_path))
    pin = tomllib.loads(pin_path.read_text())
    buoy = pin.get("buoy", {})
    for field in REQUIRED_BUOY_FIELDS:
        if not buoy.get(field):
            fail("NAUT-PIN-FIELD", f"missing buoy.{field}")
    revision = buoy["revision"]
    if not re.fullmatch(r"[0-9a-f]{40}", revision):
        fail("NAUT-PIN-FLOATING", f"revision must be one full 40-hex commit, got {revision!r}")
    if not buoy["reviewed_source_content_hash"].startswith("sha256-"):
        fail("NAUT-PIN-HASH", "reviewed_source_content_hash must be an SRI sha256 value")
    if buoy["digest_feature"] != "blake3-256":
        fail("NAUT-PIN-DIGEST", "buoy.digest_feature must be blake3-256")

    consumer_text = (repo / "nix" / "buoy-consumer.nix").read_text()
    consumer = "\n".join(
        line
        for line in consumer_text.splitlines()
        if not line.lstrip().startswith("#")
    )
    if "provenance/buoy-pin.toml" not in consumer:
        fail("NAUT-PIN-DRIFT", "nix/buoy-consumer.nix does not read provenance/buoy-pin.toml")
    for marker in ("ref =", 'ref"', "branch"):
        if marker in consumer:
            fail("NAUT-PIN-FLOATING", f"nix/buoy-consumer.nix contains floating marker {marker!r}")
    if re.search(r"\b(rev\s*=\s*\")", consumer):
        fail("NAUT-PIN-DRIFT", "nix/buoy-consumer.nix must take the revision from the pin record")
    digest_default = re.search(r'\bdigestFeature\s*\?\s*"([^"]+)"', consumer)
    if digest_default is None:
        fail("NAUT-PIN-DIGEST-DRIFT", "nix/buoy-consumer.nix must declare its digest default")
    if digest_default.group(1) != buoy["digest_feature"]:
        fail(
            "NAUT-PIN-DIGEST-DRIFT",
            f"pin={buoy['digest_feature']} consumer={digest_default.group(1)}",
        )

    vendored = [
        str(path)
        for path in (repo / "vendor",).__iter__()
        if path.exists()
    ]
    if vendored:
        fail("NAUT-PIN-VENDORED", ";".join(vendored))

    print(f"buoy-pin: ok revision={revision} feature={buoy['digest_feature']}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", default=".", type=pathlib.Path)
    arguments = parser.parse_args()
    check(arguments.repo.resolve())


if __name__ == "__main__":
    main()
