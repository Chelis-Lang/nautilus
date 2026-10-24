#!/usr/bin/env python3
"""Fail when a toolchain-installing workflow drifts from reef.toml."""

from __future__ import annotations

import re
import sys
from dataclasses import dataclass
from pathlib import Path

try:
    from . import reef_pin
except ImportError:  # Direct execution: ``python3 scripts/check_workflow_pins.py``.
    import reef_pin


REPO_ROOT = Path(__file__).resolve().parent.parent
CENTRAL_WORKFLOW_PREFIX = "Chelis-Lang/ci/.github/workflows/consumer.yml@"
APPROVED_CENTRAL_WORKFLOW_SHA = "4394706b569bdd7d557f6edc7b9818249decc330"
CENTRAL_INSTALL_PROFILES = frozenset(
    {"nautilus-ci", "nautilus-nightly", "nautilus-release"}
)
CENTRAL_PROFILE_INPUTS = {
    "nautilus-ci": frozenset(
        {
            "profile",
            "chelis-tag",
            "chelis-version",
            "chelis-linux-sha256",
            "chelis-darwin-sha256",
        }
    ),
    "nautilus-nightly": frozenset(
        {"profile", "chelis-tag", "chelis-version", "chelis-linux-sha256"}
    ),
    "nautilus-release": frozenset({"profile", "chelis-linux-sha256"}),
}
CENTRAL_JOB_KEYS = frozenset({"name", "uses", "with", "secrets"})
PIN_RE = re.compile(
    r"^\s*(CHELIS_TAG|CHELIS_VERSION)\s*:\s*(['\"]?)(v?\d+\.\d+\.\d+)\2\s*(?:#.*)?$",
    re.MULTILINE,
)


@dataclass(frozen=True)
class CentralCall:
    profile: str
    chelis_version: str | None
    chelis_tag: str | None


def read_reef_pin(path: Path) -> str:
    """Compatibility wrapper around the shared exact-pin reader."""
    return reef_pin.read_exact_reef_pin(path)


def static_pins(text: str) -> dict[str, set[str]]:
    """Collect literal workflow pin declarations, including duplicates."""
    pins: dict[str, set[str]] = {}
    for key, _quote, value in PIN_RE.findall(text):
        pins.setdefault(key, set()).add(value)
    return pins


def _indent(line: str) -> int | None:
    prefix = line[: len(line) - len(line.lstrip(" \t"))]
    if "\t" in prefix:
        return None
    return len(prefix)


def _scalar(value: str) -> str:
    value = value.strip()
    if " #" in value:
        value = value.split(" #", 1)[0].rstrip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in "'\"":
        value = value[1:-1]
    return value


def _mapping(line: str, indent: int) -> tuple[str, str] | None:
    if _indent(line) != indent:
        return None
    text = line[indent:]
    if not text or text.startswith(("#", "-")) or ":" not in text:
        return None
    key, value = text.split(":", 1)
    key = key.strip()
    if not key:
        return None
    return key, _scalar(value)


def _nested_mapping(
    lines: list[str], start: int, end: int, indent: int
) -> dict[str, str] | None:
    values: dict[str, str] = {}
    for line in lines[start:end]:
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        item = _mapping(line, indent)
        if item is None:
            return None
        key, value = item
        if key in values or not value:
            return None
        values[key] = value
    return values


def _canonical_digest(value: str) -> bool:
    payload = value.removeprefix("sha256:")
    return (
        value.startswith("sha256:")
        and len(payload) == 64
        and all(char in "0123456789abcdef" for char in payload)
    )


def _central_call_from_job(lines: list[str]) -> CentralCall | None:
    keys: dict[str, tuple[str, int]] = {}
    child_ranges: dict[str, tuple[int, int]] = {}
    index = 0
    while index < len(lines):
        line = lines[index]
        if not line.strip() or line.lstrip().startswith("#"):
            index += 1
            continue
        item = _mapping(line, 4)
        if item is None:
            return None
        key, value = item
        if key in keys:
            return None
        keys[key] = (value, index)
        child_end = index + 1
        while child_end < len(lines):
            nested_indent = _indent(lines[child_end])
            if (
                lines[child_end].strip()
                and nested_indent is not None
                and nested_indent <= 4
            ):
                break
            child_end += 1
        child_ranges[key] = (index + 1, child_end)
        index = child_end

    if not {"uses", "with", "secrets"}.issubset(keys) or not set(keys).issubset(
        CENTRAL_JOB_KEYS
    ):
        return None
    if keys["with"][0] or keys["secrets"][0]:
        return None
    for scalar_key in {"name", "uses"}:
        if (
            scalar_key in child_ranges
            and child_ranges[scalar_key][0] != child_ranges[scalar_key][1]
        ):
            return None
    uses = keys["uses"][0]
    if not uses.startswith(CENTRAL_WORKFLOW_PREFIX):
        return None
    sha = uses.removeprefix(CENTRAL_WORKFLOW_PREFIX)
    if (
        len(sha) != 40
        or set(sha) == {"0"}
        or any(char not in "0123456789abcdef" for char in sha)
        or sha != APPROVED_CENTRAL_WORKFLOW_SHA
    ):
        return None

    with_start, with_end = child_ranges["with"]
    inputs = _nested_mapping(lines, with_start, with_end, 6)
    secret_start, secret_end = child_ranges["secrets"]
    secrets = _nested_mapping(lines, secret_start, secret_end, 6)
    if inputs is None or inputs.get("profile") not in CENTRAL_INSTALL_PROFILES:
        return None
    profile = inputs["profile"]
    if set(inputs) != CENTRAL_PROFILE_INPUTS[profile]:
        return None
    if secrets != {"CHELIS_RELEASE_TOKEN": "${{ secrets.CHELIS_RELEASE_TOKEN }}"}:
        return None
    if not _canonical_digest(inputs["chelis-linux-sha256"]):
        return None
    darwin_digest = inputs.get("chelis-darwin-sha256")
    if darwin_digest is not None and not _canonical_digest(darwin_digest):
        return None
    return CentralCall(profile, inputs.get("chelis-version"), inputs.get("chelis-tag"))


def central_calls(text: str) -> list[CentralCall]:
    """Parse executable, non-skippable Nautilus central-workflow call jobs."""
    lines = text.splitlines()
    jobs_index = next(
        (
            index
            for index, line in enumerate(lines)
            if _indent(line) == 0 and line.strip() == "jobs:"
        ),
        None,
    )
    if jobs_index is None:
        return []
    section_end = len(lines)
    for index in range(jobs_index + 1, len(lines)):
        if lines[index].strip() and _indent(lines[index]) == 0:
            section_end = index
            break

    jobs: list[list[str]] = []
    index = jobs_index + 1
    while index < section_end:
        if not lines[index].strip() or lines[index].lstrip().startswith("#"):
            index += 1
            continue
        item = _mapping(lines[index], 2)
        if item is None or item[1]:
            return []
        job_end = index + 1
        while job_end < section_end:
            line_indent = _indent(lines[job_end])
            if lines[job_end].strip() and line_indent is not None and line_indent <= 2:
                break
            job_end += 1
        jobs.append(lines[index + 1 : job_end])
        index = job_end

    # A migrated wrapper has exactly one calling job. This prevents a hidden or
    # conditionally skipped local job from being treated as central authority.
    if len(jobs) != 1:
        return []
    call = _central_call_from_job(jobs[0])
    return [call] if call is not None else []


def _step_field(lines: list[str], index: int, key: str) -> tuple[int, str] | None:
    line = lines[index]
    if not line.strip() or line.lstrip().startswith("#"):
        return None
    indent = _indent(line)
    if indent not in {6, 8}:
        return None

    # Restrict recognition to canonical GitHub jobs -> job -> steps -> step.
    # An inert list under env or another arbitrary YAML field is not a step.
    jobs_line = next(
        (
            candidate
            for candidate in reversed(lines[:index])
            if candidate.strip() and _indent(candidate) == 0
        ),
        None,
    )
    if jobs_line is None or jobs_line.strip() != "jobs:":
        return None
    job_line = next(
        (
            candidate
            for candidate in reversed(lines[:index])
            if candidate.strip() and _indent(candidate) == 2
        ),
        None,
    )
    if job_line is None or _mapping(job_line, 2) is None:
        return None
    section_line = next(
        (
            candidate
            for candidate in reversed(lines[:index])
            if candidate.strip() and _indent(candidate) == 4
        ),
        None,
    )
    if section_line is None or _mapping(section_line, 4) != ("steps", ""):
        return None

    text = line[indent:]
    if indent == 6:
        if not text.startswith("- "):
            return None
        text = text[2:].lstrip()
    else:
        parent = next(
            (
                candidate
                for candidate in reversed(lines[:index])
                if candidate.strip() and _indent(candidate) < 8
            ),
            None,
        )
        if (
            parent is None
            or _indent(parent) != 6
            or not parent.lstrip().startswith("- ")
        ):
            return None
    prefix = f"{key}:"
    if not text.startswith(prefix):
        return None
    return indent, _scalar(text.removeprefix(prefix))


def _run_blocks(text: str) -> list[str]:
    """Return actual YAML step run scalars, skipping nested lookalikes."""
    lines = text.splitlines()
    blocks: list[str] = []
    index = 0
    while index < len(lines):
        field = _step_field(lines, index, "run")
        if field is None:
            index += 1
            continue
        indent, value = field
        if value not in {"|", ">", "|-", ">-", "|+", ">+"}:
            blocks.append(value)
            index += 1
            continue
        body: list[str] = []
        index += 1
        while index < len(lines):
            child_indent = _indent(lines[index])
            if lines[index].strip() and (
                child_indent is None or child_indent <= indent
            ):
                break
            if lines[index].strip() and not lines[index].lstrip().startswith("#"):
                body.append(lines[index].strip())
            index += 1
        blocks.append("\n".join(body))
    return blocks


def _step_uses(text: str) -> list[str]:
    uses: list[str] = []
    lines = text.splitlines()
    index = 0
    while index < len(lines):
        run_field = _step_field(lines, index, "run")
        if run_field is not None and run_field[1] in {
            "|",
            ">",
            "|-",
            ">-",
            "|+",
            ">+",
        }:
            indent = run_field[0]
            index += 1
            while index < len(lines):
                child_indent = _indent(lines[index])
                if lines[index].strip() and (
                    child_indent is None or child_indent <= indent
                ):
                    break
                index += 1
            continue
        uses_field = _step_field(lines, index, "uses")
        if uses_field is not None:
            uses.append(uses_field[1])
        index += 1
    return uses


def legacy_installs_toolchain(text: str) -> bool:
    if "./.github/actions/install-chelis" in _step_uses(text):
        return True
    for block in _run_blocks(text):
        commands = [line.strip() for line in block.splitlines() if line.strip()]
        if any(command.startswith("chelisup install ") for command in commands):
            return True
        if (
            commands
            and commands[0].startswith("gh release download")
            and any("--repo Chelis-Lang/chelis" in command for command in commands)
        ):
            return True
    return False


def check_workflow_pins(version: str, workflow_dir: Path) -> list[str]:
    """Return errors for installing workflows without one manifest-matching pin."""
    expected = {"CHELIS_TAG": f"v{version}", "CHELIS_VERSION": version}
    paths = sorted([*workflow_dir.glob("*.yml"), *workflow_dir.glob("*.yaml")])
    errors: list[str] = []
    checked = 0

    for path in paths:
        try:
            text = path.read_text(encoding="utf-8")
        except OSError as exc:
            errors.append(f"cannot read {path}: {exc}")
            continue

        calls = central_calls(text)
        if calls:
            checked += len(calls)
            for call in calls:
                if call.chelis_version is not None and call.chelis_version != version:
                    errors.append(
                        f"{path}: chelis-version={call.chelis_version}; expected {version}"
                    )
                if call.chelis_tag is not None and call.chelis_tag != f"v{version}":
                    errors.append(
                        f"{path}: chelis-tag={call.chelis_tag}; expected v{version}"
                    )
            continue
        if CENTRAL_WORKFLOW_PREFIX in text:
            errors.append(f"{path}: malformed or unapproved central workflow call")
            continue
        if not legacy_installs_toolchain(text):
            continue

        checked += 1
        pins = static_pins(text)
        for key, wanted in expected.items():
            found = pins.get(key, set())
            if found != {wanted}:
                actual = ", ".join(sorted(found)) or "missing"
                errors.append(f"{path}: {key}={actual}; expected {wanted}")

    if checked == 0:
        errors.append(f"{workflow_dir}: no toolchain-installing workflow found")
    return errors


def main() -> int:
    try:
        version = read_reef_pin(REPO_ROOT / "reef.toml")
    except ValueError as exc:
        print(f"workflow pin error: {exc}", file=sys.stderr)
        return 1

    errors = check_workflow_pins(version, REPO_ROOT / ".github" / "workflows")
    for error in errors:
        print(f"workflow pin error: {error}", file=sys.stderr)
    if errors:
        return 1

    print("workflow pins match the exact compiler pin in reef.toml")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
