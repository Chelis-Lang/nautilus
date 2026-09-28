#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import tomllib
from datetime import date
from pathlib import Path
from typing import Callable

ROOT = Path(__file__).resolve().parents[1]
OPENSPEC_VERSION = "1.6.0"
OPENSPEC_GATE_COMMAND = "nix run ./ci#openspec-gate"
ARCHIVE_NAME = "archive"
CHANGE_NAME = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
ARCHIVED_CHANGE = re.compile(
    r"^(?P<date>\d{4}-\d{2}-\d{2})-(?P<name>[a-z0-9]+(?:-[a-z0-9]+)*)$"
)
EXEMPTION_NAME = re.compile(
    r"^(?P<date>\d{4}-\d{2}-\d{2})-[a-z0-9]+(?:-[a-z0-9]+)*\.toml$"
)
# OpenSpec 1.6 splits task artifacts on LF, then applies a prefix regex whose
# JavaScript `\s` class differs from Python's: Python omits U+FEFF and includes
# characters JavaScript does not. Keep the remaining ECMAScript set explicit.
TASK_WHITESPACE = (
    "\t\v\f\r \u00a0\u1680\u2000\u2001\u2002\u2003\u2004\u2005\u2006"
    "\u2007\u2008\u2009\u200a\u2028\u2029\u202f\u205f\u3000\ufeff"
)
TASK_WHITESPACE_CLASS = re.escape(TASK_WHITESPACE)
CHECKBOX = re.compile(
    rf"^[{TASK_WHITESPACE_CLASS}]*[-*][{TASK_WHITESPACE_CLASS}]+"
    rf"\[(?P<mark>x|[{TASK_WHITESPACE_CLASS}])\]",
    re.IGNORECASE | re.MULTILINE,
)
SCHEMA_DECLARATION = re.compile(
    r"^[ \t]*schema[ \t]*:[ \t]*(?P<value>[^#\r\n]*?)[ \t]*(?:#.*)?$",
    re.MULTILINE,
)


def dated_name_match(pattern: re.Pattern[str], name: str) -> re.Match[str] | None:
    match = pattern.fullmatch(name)
    if match is None:
        return None
    try:
        date.fromisoformat(match.group("date"))
    except ValueError:
        return None
    return match


def archived_change_match(name: str) -> re.Match[str] | None:
    return dated_name_match(ARCHIVED_CHANGE, name)


def exemption_name_is_valid(name: str) -> bool:
    return dated_name_match(EXEMPTION_NAME, name) is not None


def changes_root(root: Path) -> Path:
    return root / "openspec" / "changes"


def exemptions_root(root: Path) -> Path:
    return root / "openspec" / "exemptions"


def repository_symlink_errors(root: Path) -> list[str]:
    openspec = root / "openspec"
    if openspec.is_symlink():
        return ["OpenSpec root must be a regular non-symlink directory: openspec"]
    if not openspec.exists():
        return []
    if not openspec.is_dir():
        return ["OpenSpec root is not a directory: openspec"]

    errors: list[str] = []
    for raw_directory, directory_names, file_names in os.walk(
        openspec, topdown=True, followlinks=False
    ):
        directory = Path(raw_directory)
        for name in [*directory_names, *file_names]:
            candidate = directory / name
            if candidate.is_symlink():
                display = candidate.relative_to(root).as_posix()
                errors.append(
                    "OpenSpec content must be regular non-symlink repository "
                    f"artifacts: {display}"
                )
        directory_names[:] = [
            name for name in directory_names if not (directory / name).is_symlink()
        ]
    return errors


def lifecycle_schema_errors(root: Path, change: Path) -> list[str]:
    marker = change / ".openspec.yaml"
    display = marker.relative_to(root).as_posix()
    if marker.is_symlink() or not marker.is_file():
        return [
            f"lifecycle metadata must be a regular non-symlink file: {display}"
        ]
    try:
        text = marker.read_text(encoding="utf-8")
    except (OSError, UnicodeError) as error:
        return [f"cannot read lifecycle metadata {display}: {error}"]
    declarations = list(SCHEMA_DECLARATION.finditer(text))
    if (
        len(declarations) != 1
        or declarations[0].group("value") != "spec-driven"
    ):
        return [
            f"lifecycle metadata {display} must select exactly the built-in "
            "schema: spec-driven"
        ]
    return []


def repository_schema_errors(root: Path) -> list[str]:
    schemas = root / "openspec" / "schemas"
    if schemas.exists() or schemas.is_symlink():
        return [
            "project-local OpenSpec schemas are forbidden because they can "
            "override the required built-in spec-driven artifact graph: "
            f"{schemas}"
        ]
    return []


def active_change_dirs(root: Path) -> list[Path]:
    parent = changes_root(root)
    if not parent.is_dir():
        return []
    result: list[Path] = []
    for path in parent.iterdir():
        if not path.is_dir():
            continue
        if path.name == ARCHIVE_NAME and not (path / ".openspec.yaml").is_file():
            continue
        result.append(path)
    return sorted(result, key=lambda path: path.name)


def archived_change_dirs(root: Path) -> list[Path]:
    parent = changes_root(root) / ARCHIVE_NAME
    if not parent.is_dir():
        return []
    return sorted(
        (path for path in parent.iterdir() if path.is_dir()),
        key=lambda path: path.name,
    )


def archived_change_ids(root: Path) -> dict[str, list[Path]]:
    result: dict[str, list[Path]] = {}
    for path in archived_change_dirs(root):
        match = archived_change_match(path.name)
        if match:
            result.setdefault(match.group("name"), []).append(path)
    return result


def change_ids_from_paths(paths: list[str]) -> set[str]:
    result: set[str] = set()
    for raw_path in paths:
        parts = Path(raw_path).parts
        if len(parts) < 3 or parts[:2] != ("openspec", "changes"):
            continue
        if parts[2] == ARCHIVE_NAME:
            if len(parts) < 4:
                continue
            match = archived_change_match(parts[3])
            if match:
                result.add(match.group("name"))
            else:
                result.add(f"{ARCHIVE_NAME}/{parts[3]}")
        else:
            result.add(parts[2])
    return result


def changed_entries(root: Path, base: str) -> list[tuple[str, str]]:
    git = os.environ.get("GIT_BIN", "git")
    merge_base = subprocess.run(
        [git, "merge-base", base, "HEAD"],
        cwd=root,
        check=False,
        capture_output=True,
        text=True,
    )
    comparison = merge_base.stdout.strip()
    if merge_base.returncode != 0 or not comparison:
        diagnostic = merge_base.stderr.strip() or "no merge base found"
        raise RuntimeError(f"cannot resolve comparison base {base!r}: {diagnostic}")

    completed = subprocess.run(
        [git, "diff", "--name-status", "--no-renames", comparison, "--"],
        cwd=root,
        check=False,
        capture_output=True,
        text=True,
    )
    if completed.returncode != 0:
        diagnostic = completed.stderr.strip() or "unknown git diff failure"
        raise RuntimeError(f"cannot compare OpenSpec scope with {base!r}: {diagnostic}")

    result: list[tuple[str, str]] = []
    for line in completed.stdout.splitlines():
        status, separator, path = line.partition("\t")
        if not separator or len(status) != 1 or not path:
            raise RuntimeError(f"cannot parse git diff entry relative to {base!r}: {line!r}")
        result.append((status, path))

    untracked = subprocess.run(
        [git, "ls-files", "--others", "--exclude-standard", "-z"],
        cwd=root,
        check=False,
        capture_output=True,
    )
    if untracked.returncode != 0:
        diagnostic = untracked.stderr.decode("utf-8", errors="replace").strip()
        raise RuntimeError(
            f"cannot inspect untracked scope relative to {base!r}: "
            f"{diagnostic or 'unknown git ls-files failure'}"
        )
    tracked_paths = {path for _, path in result}
    try:
        untracked_paths = [
            raw.decode("utf-8") for raw in untracked.stdout.split(b"\0") if raw
        ]
    except UnicodeDecodeError as error:
        raise RuntimeError(
            f"cannot decode untracked repository path as UTF-8: {error}"
        ) from error
    result.extend(
        ("A", path) for path in untracked_paths if path not in tracked_paths
    )
    return sorted(result, key=lambda entry: entry[1])


def added_lifecycle_ids(entries: list[tuple[str, str]]) -> set[str]:
    markers: list[str] = []
    for status, raw_path in entries:
        if status != "A":
            continue
        parts = Path(raw_path).parts
        active_marker = (
            len(parts) == 4
            and parts[:2] == ("openspec", "changes")
            and parts[2] != ARCHIVE_NAME
            and parts[3] == ".openspec.yaml"
        )
        archived_marker = (
            len(parts) == 5
            and parts[:3] == ("openspec", "changes", ARCHIVE_NAME)
            and parts[4] == ".openspec.yaml"
        )
        if active_marker or archived_marker:
            markers.append(raw_path)
    return change_ids_from_paths(markers)


def added_archived_change_dirs(
    root: Path, entries: list[tuple[str, str]]
) -> list[Path]:
    result: set[Path] = set()
    for status, raw_path in entries:
        parts = Path(raw_path).parts
        if (
            status == "A"
            and len(parts) == 5
            and parts[:3] == ("openspec", "changes", ARCHIVE_NAME)
            and parts[4] == ".openspec.yaml"
        ):
            result.add(root / Path(*parts[:-1]))
    return sorted(result, key=lambda path: path.as_posix())


def exemption_changes(entries: list[tuple[str, str]]) -> list[tuple[str, str]]:
    return [
        (status, path)
        for status, path in entries
        if Path(path).parts[:2] == ("openspec", "exemptions")
    ]


def exemption_manifest_errors(
    root: Path,
    path: Path,
    *,
    expected_paths: set[str] | None = None,
) -> list[str]:
    errors: list[str] = []
    try:
        display = path.relative_to(root).as_posix()
    except ValueError:
        display = str(path)

    if path.parent != exemptions_root(root) or not exemption_name_is_valid(path.name):
        return [
            f"invalid maintenance exemption path {display!r}: expected a valid "
            "calendar date in openspec/exemptions/"
            "YYYY-MM-DD-<kebab-case-id>.toml"
        ]
    if path.is_symlink():
        return [
            f"maintenance exemption manifest must be a regular non-symlink file: "
            f"{display}"
        ]
    if not path.is_file():
        return [f"missing maintenance exemption manifest: {display}"]

    try:
        data = tomllib.loads(path.read_text(encoding="utf-8"))
    except (OSError, tomllib.TOMLDecodeError) as error:
        return [f"invalid maintenance exemption manifest {display}: {error}"]

    expected_keys = {"kind", "reason", "paths"}
    if set(data) != expected_keys:
        errors.append(
            f"maintenance exemption {display} must contain exactly kind, reason, "
            "and paths"
        )
    if data.get("kind") != "maintenance":
        errors.append(f"maintenance exemption {display} must set kind = \"maintenance\"")
    reason = data.get("reason")
    if not isinstance(reason, str) or not reason.strip():
        errors.append(f"maintenance exemption {display} must provide a non-empty reason")

    declared = data.get("paths")
    normalized: list[str] = []
    if not isinstance(declared, list) or not declared:
        errors.append(f"maintenance exemption {display} must declare at least one path")
    else:
        for value in declared:
            if not isinstance(value, str) or not value:
                errors.append(
                    f"maintenance exemption {display} contains a non-string or empty path"
                )
                continue
            candidate = Path(value)
            if (
                candidate.is_absolute()
                or value in {".", ".."}
                or "\\" in value
                or candidate.as_posix() != value
                or any(part in {".", ".."} for part in candidate.parts)
            ):
                errors.append(
                    f"maintenance exemption {display} contains invalid repository path "
                    f"{value!r}"
                )
                continue
            if candidate.parts[:2] in {
                ("openspec", "changes"),
                ("openspec", "exemptions"),
            }:
                errors.append(
                    f"maintenance exemption {display} cannot cover governance path "
                    f"{value!r}"
                )
                continue
            normalized.append(value)
        if len(set(normalized)) != len(normalized):
            errors.append(f"maintenance exemption {display} contains duplicate paths")

    if expected_paths is not None and set(normalized) != expected_paths:
        missing = sorted(expected_paths - set(normalized))
        extra = sorted(set(normalized) - expected_paths)
        details: list[str] = []
        if missing:
            details.append("missing " + ", ".join(missing))
        if extra:
            details.append("extra " + ", ".join(extra))
        errors.append(
            f"maintenance exemption {display} paths do not match the branch diff: "
            + "; ".join(details)
        )
    return errors


def repository_exemption_errors(root: Path) -> list[str]:
    parent = exemptions_root(root)
    if not parent.exists():
        return []
    if not parent.is_dir():
        return [f"maintenance exemption root is not a directory: {parent}"]
    errors: list[str] = []
    for path in sorted(parent.iterdir(), key=lambda candidate: candidate.name):
        errors.extend(exemption_manifest_errors(root, path))
    return errors


def branch_scope_errors(
    root: Path,
    base: str,
    entries: list[tuple[str, str]],
    *,
    require_archived: bool = False,
) -> list[str]:
    if not entries:
        return []
    errors: list[str] = []
    paths = [path for _, path in entries]
    lifecycles = change_ids_from_paths(paths)
    lifecycle_entries = [
        (status, path)
        for status, path in entries
        if change_ids_from_paths([path])
    ]
    added_lifecycles = added_lifecycle_ids(entries)
    exemptions = exemption_changes(entries)

    if len(lifecycles) > 1:
        errors.append(
            f"branch changes {len(lifecycles)} change lifecycles relative to "
            f"{base!r}: " + ", ".join(sorted(lifecycles))
        )
    if lifecycles:
        if exemptions:
            errors.append(
                "branch cannot combine a governed lifecycle with maintenance "
                "exemption changes"
            )
        if len(lifecycles) == 1 and added_lifecycles != lifecycles:
            errors.append(
                "branch lifecycle evidence must add exactly one lifecycle "
                ".openspec.yaml marker"
            )
        if any(status != "A" for status, _ in lifecycle_entries):
            errors.append(
                "new lifecycle evidence cannot modify, delete, or type-change "
                "existing lifecycle paths"
            )
        active_evidence = any(
            Path(path).parts[2] != ARCHIVE_NAME for _, path in lifecycle_entries
        )
        baseline_spec_entries = [
            path
            for _, path in entries
            if Path(path).parts[:2] == ("openspec", "specs")
        ]
        if active_evidence and baseline_spec_entries:
            errors.append(
                "active lifecycle evidence cannot pre-synchronize baseline "
                "specifications before archive: "
                + ", ".join(sorted(baseline_spec_entries))
            )
        if require_archived and active_evidence:
            errors.append(
                "merge-bound lifecycle evidence must be archived; run the "
                "pre-archive gate before moving and synchronizing the change"
            )
        return errors

    if len(exemptions) != 1:
        errors.append(
            "branch must add exactly one governed change lifecycle or one "
            "maintenance exemption manifest"
        )
        return errors

    status, raw_manifest = exemptions[0]
    if status != "A":
        errors.append("branch maintenance exemption manifest must be newly added")
        return errors
    manifest = root / raw_manifest
    changed_paths = set(paths) - {raw_manifest}
    errors.extend(
        exemption_manifest_errors(root, manifest, expected_paths=changed_paths)
    )
    return errors


def task_counts(change: Path) -> tuple[int, int]:
    tasks = change / "tasks.md"
    if not tasks.is_file():
        raise RuntimeError(f"missing task artifact: {tasks}")
    content = tasks.read_bytes().decode("utf-8")
    matches = list(CHECKBOX.finditer(content))
    if not matches:
        raise RuntimeError(f"task artifact contains no checkboxes: {tasks}")
    undescribed: list[re.Match[str]] = []
    for match in matches:
        line_end = content.find("\n", match.end())
        if line_end == -1:
            line_end = len(content)
        description = content[match.end() : line_end]
        if description.endswith("\r"):
            description = description[:-1]
        if not any(
            not character.isspace() and character not in TASK_WHITESPACE
            for character in description
        ):
            undescribed.append(match)
    if undescribed:
        raise RuntimeError(
            f"task artifact contains {len(undescribed)} checkbox(es) without "
            f"non-whitespace descriptions: {tasks}"
        )
    marks = [match.group("mark").lower() for match in matches]
    return len(marks), sum(mark != "x" for mark in marks)


def openspec_bin() -> str:
    command = os.environ.get("OPENSPEC_BIN", "openspec")
    if shutil.which(command) is None:
        raise RuntimeError(
            f"OpenSpec executable not found: {command!r}; run "
            f"{OPENSPEC_GATE_COMMAND} or set OPENSPEC_BIN explicitly"
        )
    version = subprocess.run(
        [command, "--version"],
        check=False,
        capture_output=True,
        text=True,
    )
    actual = version.stdout.strip()
    if version.returncode != 0 or actual != OPENSPEC_VERSION:
        raise RuntimeError(
            f"OpenSpec version mismatch: expected {OPENSPEC_VERSION}, "
            f"got {actual or 'unknown'}"
        )
    return command


def run_validation_command(
    command: list[str], *, cwd: Path, show_output: bool
) -> int:
    print("+", " ".join(command), flush=True)
    completed = subprocess.run(
        command,
        cwd=cwd,
        check=False,
        capture_output=True,
        text=True,
    )
    if show_output:
        if completed.stdout:
            print(completed.stdout, end="")
        if completed.stderr:
            print(completed.stderr, end="", file=sys.stderr)
    return completed.returncode


def git_base_spec_files(root: Path, base: str) -> dict[str, bytes]:
    git = os.environ.get("GIT_BIN", "git")
    listed = subprocess.run(
        [
            git,
            "ls-tree",
            "-r",
            "-z",
            "--name-only",
            base,
            "--",
            "openspec/specs",
        ],
        cwd=root,
        check=False,
        capture_output=True,
    )
    if listed.returncode != 0:
        diagnostic = listed.stderr.decode("utf-8", errors="replace").strip()
        raise RuntimeError(
            f"cannot read branch-base OpenSpec specs from {base!r}: "
            f"{diagnostic or 'unknown git ls-tree failure'}"
        )

    result: dict[str, bytes] = {}
    for raw_path in listed.stdout.split(b"\0"):
        if not raw_path:
            continue
        try:
            path = raw_path.decode("utf-8")
        except UnicodeDecodeError as error:
            raise RuntimeError(
                f"branch-base OpenSpec spec path is not UTF-8: {error}"
            ) from error
        if Path(path).parts[:2] != ("openspec", "specs"):
            raise RuntimeError(f"unexpected branch-base OpenSpec spec path: {path!r}")
        shown = subprocess.run(
            [git, "show", f"{base}:{path}"],
            cwd=root,
            check=False,
            capture_output=True,
        )
        if shown.returncode != 0:
            diagnostic = shown.stderr.decode("utf-8", errors="replace").strip()
            raise RuntimeError(
                f"cannot read branch-base OpenSpec spec {path!r}: "
                f"{diagnostic or 'unknown git show failure'}"
            )
        result[path] = shown.stdout
    return result


def requirement_structure(spec: Path) -> list[tuple[str, tuple[str, ...]]]:
    if not spec.is_file():
        raise RuntimeError(f"missing baseline specification: {spec}")
    result: list[tuple[str, tuple[str, ...]]] = []
    current_requirement: str | None = None
    current_scenarios: list[str] = []
    in_requirements = False
    fence_character: str | None = None
    fence_length = 0
    for line in spec.read_text(encoding="utf-8").replace("\r\n", "\n").split("\n"):
        fence = re.match(r"^[ \t]*(?P<marker>`{3,}|~{3,})", line)
        if fence is not None:
            marker = fence.group("marker")
            if fence_character is None:
                fence_character = marker[0]
                fence_length = len(marker)
            elif marker[0] == fence_character and len(marker) >= fence_length:
                fence_character = None
                fence_length = 0
            continue
        if fence_character is not None:
            continue
        if not in_requirements:
            if re.fullmatch(r"##\s+Requirements\s*", line, re.IGNORECASE):
                in_requirements = True
            continue
        if re.match(r"^##\s+", line):
            break
        requirement = re.fullmatch(
            r"###\s*Requirement:\s*(?P<name>.+?)\s*", line, re.IGNORECASE
        )
        if requirement is not None:
            if current_requirement is not None:
                result.append((current_requirement, tuple(current_scenarios)))
            current_requirement = requirement.group("name").strip()
            current_scenarios = []
            continue
        scenario = re.fullmatch(
            r"####\s*Scenario:\s*(?P<name>.+?)\s*", line, re.IGNORECASE
        )
        if scenario is not None and current_requirement is not None:
            current_scenarios.append(scenario.group("name").strip())
    if current_requirement is not None:
        result.append((current_requirement, tuple(current_scenarios)))
    return result


def spec_requirement_snapshot(
    root: Path, capability: str, executable: str
) -> dict[str, tuple[str, tuple[tuple[str, str], ...]]]:
    spec = root / "openspec" / "specs" / capability / "spec.md"
    structure = requirement_structure(spec)
    completed = subprocess.run(
        [
            executable,
            "show",
            capability,
            "--type",
            "spec",
            "--json",
            "--no-interactive",
        ],
        cwd=root,
        check=False,
        capture_output=True,
        text=True,
    )
    if completed.returncode != 0:
        diagnostic = completed.stderr.strip() or completed.stdout.strip()
        raise RuntimeError(
            f"cannot inspect baseline specification {capability!r}: "
            f"{diagnostic or 'unknown OpenSpec show failure'}"
        )
    try:
        data = json.loads(completed.stdout)
    except json.JSONDecodeError as error:
        raise RuntimeError(
            f"cannot parse baseline specification {capability!r}: {error}"
        ) from error
    requirements = data.get("requirements") if isinstance(data, dict) else None
    if not isinstance(requirements, list) or len(structure) != len(requirements):
        raise RuntimeError(
            f"baseline specification {capability!r} requirement headers do not "
            "match OpenSpec's parsed requirements"
        )

    result: dict[str, tuple[str, tuple[tuple[str, str], ...]]] = {}
    for (name, scenario_names), requirement in zip(structure, requirements):
        if not isinstance(requirement, dict) or not isinstance(
            requirement.get("text"), str
        ):
            raise RuntimeError(
                f"baseline specification {capability!r} has an invalid parsed "
                f"requirement {name!r}"
            )
        scenarios = requirement.get("scenarios")
        if (
            not isinstance(scenarios, list)
            or len(scenario_names) != len(scenarios)
            or any(
                not isinstance(scenario, dict)
                or not isinstance(scenario.get("rawText"), str)
                for scenario in scenarios
            )
        ):
            raise RuntimeError(
                f"baseline specification {capability!r} has invalid parsed "
                f"scenarios for requirement {name!r}"
            )
        if name in result:
            raise RuntimeError(
                f"baseline specification {capability!r} repeats requirement "
                f"header {name!r}"
            )
        result[name] = (
            requirement["text"],
            tuple(
                sorted(
                    (scenario_name, scenario["rawText"])
                    for scenario_name, scenario in zip(scenario_names, scenarios)
                )
            ),
        )
    return result


def archived_spec_sync_errors(
    root: Path,
    change: Path,
    executable: str,
    base_spec_files: dict[str, bytes],
) -> list[str]:
    match = archived_change_match(change.name)
    if match is None or not change.is_dir():
        return []
    identifier = match.group("name")
    capabilities = sorted(
        path.parent.name
        for path in (change / "specs").glob("*/spec.md")
        if path.is_file()
    )
    if not capabilities:
        return [f"archived change {change.name!r} contains no delta specifications"]

    with tempfile.TemporaryDirectory(
        prefix="nautilus-openspec-archive-sync-"
    ) as directory:
        fixture_root = Path(directory)
        fixture_openspec = fixture_root / "openspec"
        fixture_openspec.mkdir(parents=True)
        shutil.copy2(
            root / "openspec" / "config.yaml",
            fixture_openspec / "config.yaml",
        )
        for raw_path, content in base_spec_files.items():
            relative = Path(raw_path)
            if relative.parts[:2] != ("openspec", "specs"):
                raise RuntimeError(
                    f"unexpected branch-base OpenSpec spec path: {raw_path!r}"
                )
            target = fixture_root / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(content)
        fixture_changes = fixture_openspec / "changes"
        fixture_changes.mkdir()
        shutil.copytree(change, fixture_changes / identifier)

        archived = subprocess.run(
            [executable, "archive", identifier, "--json", "--yes"],
            cwd=fixture_root,
            check=False,
            capture_output=True,
            text=True,
        )
        if archived.returncode != 0:
            diagnostic = archived.stderr.strip() or archived.stdout.strip()
            return [
                f"cannot reconstruct synchronized specs for archived change "
                f"{change.name!r}: {diagnostic or 'unknown OpenSpec archive failure'}"
            ]

        errors: list[str] = []
        expected_capabilities = {
            path.parent.name
            for path in (fixture_openspec / "specs").glob("*/spec.md")
            if path.is_file()
        }
        actual_capabilities = {
            path.parent.name
            for path in (root / "openspec" / "specs").glob("*/spec.md")
            if path.is_file()
        }
        if actual_capabilities != expected_capabilities:
            missing = sorted(expected_capabilities - actual_capabilities)
            unexpected = sorted(actual_capabilities - expected_capabilities)
            details: list[str] = []
            if missing:
                details.append("missing " + ", ".join(missing))
            if unexpected:
                details.append("unexpected " + ", ".join(unexpected))
            errors.append(
                f"archived change {change.name!r} is not synchronized: baseline "
                f"capability set differs from the branch-base specs with this "
                f"delta applied ({'; '.join(details)})"
            )

        for capability in sorted(expected_capabilities & actual_capabilities):
            try:
                expected = spec_requirement_snapshot(
                    fixture_root, capability, executable
                )
                actual = spec_requirement_snapshot(root, capability, executable)
            except RuntimeError as error:
                errors.append(
                    f"archived change {change.name!r} is not synchronized for "
                    f"capability {capability!r}: {error}"
                )
                continue
            if actual != expected:
                errors.append(
                    f"archived change {change.name!r} is not synchronized for "
                    f"capability {capability!r}: baseline requirements differ "
                    "from the branch-base specs with this delta applied"
                )
        return errors


def lifecycle_completion_check(
    root: Path,
    identifier: str,
    executable: str,
    *,
    display: str,
    show_output: bool,
) -> int:
    command = [executable, "status", "--change", identifier, "--json"]
    print("+", " ".join(command), flush=True)
    completed = subprocess.run(
        command,
        cwd=root,
        check=False,
        capture_output=True,
        text=True,
    )
    if show_output and completed.stderr:
        print(completed.stderr, end="", file=sys.stderr)
    if completed.returncode != 0:
        diagnostic = completed.stderr.strip() or completed.stdout.strip()
        print(
            f"openspec-gate: cannot inspect {display} lifecycle status: "
            f"{diagnostic or 'unknown OpenSpec status failure'}",
            file=sys.stderr,
        )
        return 1

    try:
        status = json.loads(completed.stdout)
    except json.JSONDecodeError as error:
        print(
            f"openspec-gate: cannot parse {display} lifecycle status: {error}",
            file=sys.stderr,
        )
        return 1
    if not isinstance(status, dict) or status.get("isComplete") is not True:
        incomplete: list[str] = []
        artifacts = status.get("artifacts") if isinstance(status, dict) else None
        if isinstance(artifacts, list):
            for artifact in artifacts:
                if not isinstance(artifact, dict) or artifact.get("status") == "done":
                    continue
                incomplete.append(
                    f"{artifact.get('id', 'unknown')}={artifact.get('status', 'unknown')}"
                )
        detail = ": " + ", ".join(incomplete) if incomplete else ""
        print(
            f"openspec-gate: {display} lifecycle artifacts are incomplete{detail}",
            file=sys.stderr,
        )
        return 1
    return 0


def validate_archived_change(
    root: Path,
    change: Path,
    executable: str,
    *,
    show_output: bool,
) -> int:
    match = archived_change_match(change.name)
    if match is None:
        raise RuntimeError(f"invalid archived change directory: {change}")
    identifier = match.group("name")
    with tempfile.TemporaryDirectory(prefix="nautilus-openspec-archive-") as directory:
        fixture_root = Path(directory)
        fixture_openspec = fixture_root / "openspec"
        fixture_openspec.mkdir(parents=True)
        shutil.copy2(
            root / "openspec" / "config.yaml",
            fixture_openspec / "config.yaml",
        )
        baseline = root / "openspec" / "specs"
        if baseline.is_dir():
            shutil.copytree(baseline, fixture_openspec / "specs")
        fixture_changes = fixture_openspec / "changes"
        fixture_changes.mkdir()
        shutil.copytree(change, fixture_changes / identifier)
        print(f"openspec-gate: validating archived change {change.name}")
        completion = lifecycle_completion_check(
            fixture_root,
            identifier,
            executable,
            display=f"archived change {change.name!r}",
            show_output=show_output,
        )
        validation = run_validation_command(
            [
                executable,
                "validate",
                identifier,
                "--strict",
                "--no-interactive",
            ],
            cwd=fixture_root,
            show_output=show_output,
        )
        return 1 if completion != 0 or validation != 0 else 0


def governance_errors(
    root: Path,
    active: list[Path],
    *,
    require_complete: bool,
    require_archived: bool = False,
    base: str | None = None,
    entries: list[tuple[str, str]] | None = None,
) -> list[str]:
    errors = repository_symlink_errors(root)
    if errors:
        return errors
    errors.extend(repository_exemption_errors(root))
    errors.extend(repository_schema_errors(root))
    archive_dirs = archived_change_dirs(root)
    for change in archive_dirs:
        if archived_change_match(change.name) is None:
            errors.append(
                f"invalid archived change directory {change.name!r}: expected a valid "
                "calendar date in YYYY-MM-DD-<kebab-case-change-id>"
            )
    for change in [*active, *archive_dirs]:
        errors.extend(lifecycle_schema_errors(root, change))
    archived = archived_change_ids(root)
    for identifier, locations in sorted(archived.items()):
        if len(locations) > 1:
            errors.append(
                f"multiple archived lifecycles reuse change identifier {identifier!r}: "
                + ", ".join(path.name for path in locations)
            )
    if len(active) > 1:
        errors.append(
            "multiple active changes violate one-change branch isolation: "
            + ", ".join(change.name for change in active)
        )
    if require_archived and active:
        errors.append(
            "merge-bound validation requires zero active changes; archive the "
            "branch lifecycle after the pre-archive gate: "
            + ", ".join(change.name for change in active)
        )
    if base is not None:
        errors.extend(
            branch_scope_errors(
                root,
                base,
                entries if entries is not None else changed_entries(root, base),
                require_archived=require_archived,
            )
        )
    for change in active:
        if change.name in archived:
            errors.append(
                f"active change {change.name!r} reuses archived change identifier: "
                + ", ".join(path.name for path in archived[change.name])
            )
        if not CHANGE_NAME.fullmatch(change.name):
            errors.append(
                f"invalid change identifier {change.name!r}: use lowercase kebab-case"
            )
        if change.name == ARCHIVE_NAME:
            errors.append(
                f"reserved change name {ARCHIVE_NAME!r}: remove the active change "
                "metadata from the archive container and choose another name"
            )
        if require_complete:
            try:
                total, unchecked = task_counts(change)
            except RuntimeError as error:
                errors.append(str(error))
                continue
            if unchecked:
                errors.append(
                    f"active change {change.name!r} has {unchecked}/{total} unchecked tasks"
                )

    for change in archive_dirs:
        try:
            total, unchecked = task_counts(change)
        except RuntimeError as error:
            errors.append(str(error))
            continue
        if unchecked:
            errors.append(
                f"archived change {change.name!r} has {unchecked}/{total} unchecked tasks"
            )
    return errors


def validate(
    root: Path,
    *,
    require_complete: bool = False,
    require_archived: bool = False,
    show_output: bool = True,
    base: str | None = None,
    validate_archives: bool = True,
) -> int:
    symlink_errors = repository_symlink_errors(root)
    if symlink_errors:
        for error in symlink_errors:
            print(f"openspec-gate: {error}", file=sys.stderr)
        return 1

    config = root / "openspec" / "config.yaml"
    if not config.is_file():
        print(f"openspec-gate: missing {config}", file=sys.stderr)
        return 2

    executable = openspec_bin()
    require_complete = require_complete or require_archived
    active = active_change_dirs(root)
    entries = changed_entries(root, base) if base is not None else None
    if active:
        print("openspec-gate: active changes: " + ", ".join(p.name for p in active))
    else:
        print("openspec-gate: no active changes; validating baseline specs")

    returncode = 0
    for error in governance_errors(
        root,
        active,
        require_complete=require_complete,
        require_archived=require_archived,
        base=base,
        entries=entries,
    ):
        print(f"openspec-gate: {error}", file=sys.stderr)
        returncode = 1

    if base is not None and entries is not None:
        base_specs = git_base_spec_files(root, base)
        for change in added_archived_change_dirs(root, entries):
            for error in archived_spec_sync_errors(
                root, change, executable, base_specs
            ):
                print(f"openspec-gate: {error}", file=sys.stderr)
                returncode = 1

    if require_complete:
        for change in active:
            if CHANGE_NAME.fullmatch(change.name) and lifecycle_completion_check(
                root,
                change.name,
                executable,
                display=f"active change {change.name!r}",
                show_output=show_output,
            ) != 0:
                returncode = 1

    commands = [
        [
            executable,
            "validate",
            change.name,
            "--strict",
            "--no-interactive",
        ]
        for change in active
        if CHANGE_NAME.fullmatch(change.name)
    ]
    commands.append(
        [
            executable,
            "validate",
            "--all",
            "--strict",
            "--no-interactive",
        ]
    )

    for command in commands:
        if run_validation_command(command, cwd=root, show_output=show_output) != 0:
            returncode = 1

    if validate_archives:
        for change in archived_change_dirs(root):
            if archived_change_match(change.name) is None:
                continue
            if (
                validate_archived_change(
                    root,
                    change,
                    executable,
                    show_output=show_output,
                )
                != 0
            ):
                returncode = 1
    return returncode


def ensure_archived_change_for_self_test(root: Path) -> Path:
    archived = archived_change_dirs(root)
    if archived:
        return archived[0]

    active = [
        change
        for change in active_change_dirs(root)
        if CHANGE_NAME.fullmatch(change.name) and change.name != ARCHIVE_NAME
    ]
    if not active:
        raise RuntimeError("self-test requires an active or archived change")
    source = active[0]
    destination = changes_root(root) / ARCHIVE_NAME / f"2000-01-01-{source.name}"
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copytree(source, destination)
    for change in active_change_dirs(root):
        shutil.rmtree(change)
    return destination


def malformed_spec(root: Path) -> Path:
    parent = changes_root(root)
    candidates = sorted(parent.glob("*/specs/*/spec.md"))
    if not candidates:
        candidates = sorted((root / "openspec" / "specs").glob("*/spec.md"))
    if not candidates:
        candidates = sorted(
            (changes_root(root) / ARCHIVE_NAME).glob("*/specs/*/spec.md")
        )
    if not candidates:
        raise RuntimeError("self-test requires at least one change or baseline spec")
    candidate = candidates[0]
    candidate.write_text(
        "## ADDED Requirements\n\n"
        "### Requirement: Deliberately malformed self-test fixture\n"
        "This fixture intentionally omits normative language and scenarios.\n",
        encoding="utf-8",
    )
    return candidate


def malformed_archived_spec(root: Path) -> Path:
    change = ensure_archived_change_for_self_test(root)
    candidates = sorted((change / "specs").glob("*/spec.md"))
    if not candidates:
        raise RuntimeError("self-test requires at least one archived spec")
    candidate = candidates[0]
    candidate.write_text(
        "## ADDED Requirements\n\n"
        "### Requirement: Deliberately malformed archived fixture\n"
        "This fixture intentionally omits normative language and scenarios.\n",
        encoding="utf-8",
    )
    return candidate


def invalid_archived_directory(root: Path) -> Path:
    archived = ensure_archived_change_for_self_test(root)
    destination = changes_root(root) / ARCHIVE_NAME / "not-a-dated-lifecycle"
    shutil.copytree(archived, destination)
    return destination


def invalid_calendar_archived_directory(root: Path) -> Path:
    archived = ensure_archived_change_for_self_test(root)
    destination = (
        changes_root(root) / ARCHIVE_NAME / "2000-99-99-calendar-self-test"
    )
    shutil.copytree(archived, destination)
    return destination


def missing_archived_artifacts(root: Path) -> Path:
    change = ensure_archived_change_for_self_test(root)
    for name in ("proposal.md", "design.md"):
        artifact = change / name
        if not artifact.is_file():
            raise RuntimeError(f"self-test requires archived artifact: {artifact}")
        artifact.unlink()
    return change


def reserved_archive_change(root: Path) -> Path:
    container = changes_root(root) / ARCHIVE_NAME
    container.mkdir(parents=True, exist_ok=True)
    marker = container / ".openspec.yaml"
    marker.write_text("schema: spec-driven\ncreated: 2000-01-01\n", encoding="utf-8")
    (container / "tasks.md").write_text(
        "## 1. Invalid reserved change\n\n- [x] 1.1 Deliberate fixture\n",
        encoding="utf-8",
    )
    return marker


def incomplete_archive(root: Path) -> Path:
    change = changes_root(root) / ARCHIVE_NAME / "2000-01-01-incomplete-self-test"
    change.mkdir(parents=True, exist_ok=True)
    (change / ".openspec.yaml").write_text(
        "schema: spec-driven\ncreated: 2000-01-01\n", encoding="utf-8"
    )
    tasks = change / "tasks.md"
    tasks.write_text(
        "## 1. Incomplete archive\n\n    - [ ] 1.1 Deliberate fixture\n",
        encoding="utf-8",
    )
    return tasks


def mark_active_tasks_complete(root: Path) -> None:
    for change in active_change_dirs(root):
        tasks = change / "tasks.md"
        if not tasks.is_file():
            continue
        text = tasks.read_text(encoding="utf-8")
        tasks.write_text(
            CHECKBOX.sub(lambda match: match.group(0).replace("[ ]", "[x]", 1), text),
            encoding="utf-8",
        )


def incomplete_active_change(root: Path) -> Path:
    active = active_change_dirs(root)
    if active:
        tasks = active[0] / "tasks.md"
        if not tasks.is_file():
            raise RuntimeError(f"missing task artifact: {tasks}")
        text = tasks.read_text(encoding="utf-8")
        checkbox = CHECKBOX.search(text)
        if checkbox is None:
            raise RuntimeError(f"task artifact contains no checkboxes: {tasks}")
        start, end = checkbox.span("mark")
        tasks.write_text(text[:start] + " " + text[end:], encoding="utf-8")
        return tasks

    change = changes_root(root) / "incomplete-self-test"
    change.mkdir(parents=True, exist_ok=True)
    (change / ".openspec.yaml").write_text(
        "schema: spec-driven\ncreated: 2000-01-01\n", encoding="utf-8"
    )
    tasks = change / "tasks.md"
    tasks.write_text(
        "## 1. Incomplete active change\n\n  - [ ] 1.1 Deliberate fixture\n",
        encoding="utf-8",
    )
    return tasks


def reused_archived_identifier(root: Path) -> Path:
    source = ensure_archived_change_for_self_test(root)
    match = archived_change_match(source.name)
    if match is None:
        raise RuntimeError(f"self-test found invalid archived change: {source}")
    identifier = match.group("name")
    for change in active_change_dirs(root):
        shutil.rmtree(change)
    destination = changes_root(root) / identifier
    shutil.copytree(source, destination)
    return destination


def duplicate_archived_identifier(root: Path) -> Path:
    source = ensure_archived_change_for_self_test(root)
    match = archived_change_match(source.name)
    if match is None:
        raise RuntimeError(f"self-test found invalid archived change: {source}")
    identifier = match.group("name")
    year = 1900
    destination = changes_root(root) / ARCHIVE_NAME / f"{year}-01-01-{identifier}"
    while destination.exists():
        year += 1
        destination = changes_root(root) / ARCHIVE_NAME / f"{year}-01-01-{identifier}"
    shutil.copytree(source, destination)
    return destination


def invalid_identifier(root: Path, name: str) -> Path:
    active = active_change_dirs(root)
    archived = archived_change_dirs(root)
    sources = active or archived
    if not sources:
        raise RuntimeError("self-test requires a change to copy")
    source = sources[0]
    destination = changes_root(root) / name
    shutil.copytree(source, destination)
    for change in active:
        if change != destination:
            shutil.rmtree(change)
    baseline = root / "openspec" / "specs"
    if baseline.exists():
        shutil.rmtree(baseline)
    baseline.mkdir(parents=True)
    mark_active_tasks_complete(root)
    return destination


def expect_invalid(
    root: Path,
    label: str,
    mutate: Callable[[Path], Path],
    *,
    require_complete: bool = False,
) -> bool:
    with tempfile.TemporaryDirectory(prefix="nautilus-openspec-") as directory:
        fixture_root = Path(directory)
        shutil.copytree(root / "openspec", fixture_root / "openspec")
        broken = mutate(fixture_root)
        print(f"openspec-gate self-test: {label}: {broken.relative_to(fixture_root)}")
        return (
            validate(
                fixture_root,
                require_complete=require_complete,
                show_output=False,
                validate_archives=False,
            )
            != 0
        )


def incomplete_active_tasks_are_rejected(root: Path) -> bool:
    with tempfile.TemporaryDirectory(prefix="nautilus-openspec-") as directory:
        fixture_root = Path(directory)
        shutil.copytree(root / "openspec", fixture_root / "openspec")
        if not active_change_dirs(fixture_root):
            change = changes_root(fixture_root) / "active-completion-self-test"
            change.mkdir(parents=True)
            (change / ".openspec.yaml").write_text(
                "schema: spec-driven\ncreated: 2000-01-01\n", encoding="utf-8"
            )
            (change / "tasks.md").write_text(
                "## 1. Active change\n\n  - [x] 1.1 Deliberate fixture\n",
                encoding="utf-8",
            )
        broken = incomplete_active_change(fixture_root)
        active = active_change_dirs(fixture_root)
        errors = governance_errors(
            fixture_root,
            active,
            require_complete=True,
        )
        print(
            "openspec-gate self-test: completion mode must reject indented "
            f"unchecked active tasks: {broken.relative_to(fixture_root)}"
        )
        return len(active) == 1 and any(
            "unchecked tasks" in error for error in errors
        )


def malformed_archived_specs_are_rejected(root: Path) -> bool:
    with tempfile.TemporaryDirectory(prefix="nautilus-openspec-") as directory:
        fixture_root = Path(directory)
        shutil.copytree(root / "openspec", fixture_root / "openspec")
        broken = malformed_archived_spec(fixture_root)
        change = broken.parents[2]
        print(
            "openspec-gate self-test: malformed archived specs must fail: "
            f"{broken.relative_to(fixture_root)}"
        )
        return (
            validate_archived_change(
                fixture_root,
                change,
                openspec_bin(),
                show_output=False,
            )
            != 0
        )


def malformed_archive_names_are_rejected(root: Path) -> bool:
    with tempfile.TemporaryDirectory(prefix="nautilus-openspec-") as directory:
        fixture_root = Path(directory)
        shutil.copytree(root / "openspec", fixture_root / "openspec")
        broken = invalid_archived_directory(fixture_root)
        errors = governance_errors(
            fixture_root,
            active_change_dirs(fixture_root),
            require_complete=False,
        )
        print(
            "openspec-gate self-test: malformed archive names must fail: "
            f"{broken.relative_to(fixture_root)}"
        )
        return any(
            "invalid archived change directory" in error for error in errors
        )


def invalid_archive_calendar_dates_are_rejected(root: Path) -> bool:
    with tempfile.TemporaryDirectory(prefix="nautilus-openspec-") as directory:
        fixture_root = Path(directory)
        shutil.copytree(root / "openspec", fixture_root / "openspec")
        broken = invalid_calendar_archived_directory(fixture_root)
        errors = governance_errors(
            fixture_root,
            active_change_dirs(fixture_root),
            require_complete=False,
        )
        print(
            "openspec-gate self-test: impossible archive calendar dates must fail: "
            f"{broken.relative_to(fixture_root)}"
        )
        return any(
            "invalid archived change directory" in error for error in errors
        )


def missing_archived_artifacts_are_rejected(root: Path) -> bool:
    with tempfile.TemporaryDirectory(prefix="nautilus-openspec-") as directory:
        fixture_root = Path(directory)
        shutil.copytree(root / "openspec", fixture_root / "openspec")
        broken = missing_archived_artifacts(fixture_root)
        print(
            "openspec-gate self-test: missing archived planning artifacts must fail: "
            f"{broken.relative_to(fixture_root)}"
        )
        return (
            validate_archived_change(
                fixture_root,
                broken,
                openspec_bin(),
                show_output=False,
            )
            != 0
        )


def archived_identifier_reuse_is_rejected(root: Path) -> bool:
    with tempfile.TemporaryDirectory(prefix="nautilus-openspec-") as directory:
        fixture_root = Path(directory)
        shutil.copytree(root / "openspec", fixture_root / "openspec")
        broken = reused_archived_identifier(fixture_root)
        errors = governance_errors(
            fixture_root,
            active_change_dirs(fixture_root),
            require_complete=False,
        )
        print(
            "openspec-gate self-test: archived identifier reuse must fail: "
            f"{broken.relative_to(fixture_root)}"
        )
        return any("reuses archived change identifier" in error for error in errors)


def duplicate_archived_identifiers_are_rejected(root: Path) -> bool:
    with tempfile.TemporaryDirectory(prefix="nautilus-openspec-") as directory:
        fixture_root = Path(directory)
        shutil.copytree(root / "openspec", fixture_root / "openspec")
        broken = duplicate_archived_identifier(fixture_root)
        errors = governance_errors(
            fixture_root,
            active_change_dirs(fixture_root),
            require_complete=False,
        )
        print(
            "openspec-gate self-test: duplicate archived identifiers must fail: "
            f"{broken.relative_to(fixture_root)}"
        )
        return any("multiple archived lifecycles" in error for error in errors)


def multiple_active_changes_are_rejected(root: Path) -> bool:
    with tempfile.TemporaryDirectory(prefix="nautilus-openspec-") as directory:
        fixture_root = Path(directory)
        shutil.copytree(root / "openspec", fixture_root / "openspec")
        active = active_change_dirs(fixture_root)
        next_index = 1
        while len(active) < 2:
            change = changes_root(fixture_root) / f"scope-self-test-{next_index}"
            next_index += 1
            if change.exists():
                continue
            change.mkdir(parents=True)
            (change / ".openspec.yaml").write_text(
                "schema: spec-driven\ncreated: 2000-01-01\n", encoding="utf-8"
            )
            active = active_change_dirs(fixture_root)
        errors = governance_errors(
            fixture_root, active, require_complete=False
        )
        print("openspec-gate self-test: multiple active changes must fail")
        return any("multiple active changes" in error for error in errors)


def multiple_lifecycle_paths_are_distinct() -> bool:
    paths = [
        "openspec/changes/archive/2000-01-01-first-change/tasks.md",
        "openspec/changes/archive/not-a-dated-lifecycle/tasks.md",
        "openspec/changes/second-change/proposal.md",
    ]
    print("openspec-gate self-test: multiple branch lifecycles must be detected")
    return change_ids_from_paths(paths) == {
        "first-change",
        "archive/not-a-dated-lifecycle",
        "second-change",
    }


def openspec_symlinks_are_rejected(root: Path) -> bool:
    with tempfile.TemporaryDirectory(
        prefix="nautilus-openspec-symlink-"
    ) as directory:
        fixture_root = Path(directory)
        shutil.copytree(root / "openspec", fixture_root / "openspec")
        lifecycles = active_change_dirs(fixture_root) or archived_change_dirs(fixture_root)
        if not lifecycles:
            raise RuntimeError("self-test requires an active or archived change")

        proposal = lifecycles[0] / "proposal.md"
        outside_proposal = fixture_root / "mutable-proposal.md"
        shutil.copy2(proposal, outside_proposal)
        proposal.unlink()
        proposal.symlink_to(outside_proposal)

        outside_specs = fixture_root / "mutable-specs"
        outside_specs.mkdir()
        specs_link = fixture_root / "openspec" / "specs" / "linked-capability"
        specs_link.parent.mkdir(parents=True, exist_ok=True)
        specs_link.symlink_to(outside_specs, target_is_directory=True)

        errors = governance_errors(
            fixture_root,
            active_change_dirs(fixture_root),
            require_complete=False,
        )
        print(
            "openspec-gate self-test: file and directory symlinks anywhere "
            "under openspec/ must be rejected"
        )
        return any("proposal.md" in error for error in errors) and any(
            "linked-capability" in error for error in errors
        )


def hidden_lifecycle_directories_are_rejected(root: Path) -> bool:
    with tempfile.TemporaryDirectory(
        prefix="nautilus-openspec-hidden-lifecycle-"
    ) as directory:
        fixture_root = Path(directory)
        shutil.copytree(root / "openspec", fixture_root / "openspec")
        archived = ensure_archived_change_for_self_test(fixture_root)
        hidden_active = changes_root(fixture_root) / ".hidden-active"
        hidden_active.mkdir()
        (hidden_active / ".openspec.yaml").write_text(
            "schema: spec-driven\ncreated: 2000-01-01\n", encoding="utf-8"
        )
        hidden_archive = changes_root(fixture_root) / ARCHIVE_NAME / ".hidden-archive"
        shutil.copytree(archived, hidden_archive)
        errors = governance_errors(
            fixture_root,
            active_change_dirs(fixture_root),
            require_complete=False,
        )
        branch_errors = branch_scope_errors(
            fixture_root,
            "base-self-test",
            [
                ("A", "openspec/changes/real-change/.openspec.yaml"),
                ("A", "openspec/changes/.hidden-active/.openspec.yaml"),
                ("A", "src/implementation.py"),
            ],
        )
        print(
            "openspec-gate self-test: dot-prefixed active and archived "
            "lifecycles must be rejected and counted in branch scope"
        )
        return (
            any(
                "invalid change identifier '.hidden-active'" in error
                for error in errors
            )
            and any(
                "invalid archived change directory '.hidden-archive'" in error
                for error in errors
            )
            and any("changes 2 change lifecycles" in error for error in branch_errors)
        )


def branch_scope_evidence_is_required() -> bool:
    root = Path("/branch-scope-self-test")
    base = "base-self-test"
    empty = branch_scope_errors(root, base, [])
    missing = branch_scope_errors(root, base, [("M", "README.md")])
    deletion = branch_scope_errors(
        root,
        base,
        [
            (
                "A",
                "openspec/changes/archive/2000-01-01-first-change/"
                ".openspec.yaml",
            ),
            (
                "D",
                "openspec/changes/archive/1999-01-01-second-change/tasks.md",
            ),
        ],
    )
    marker_missing = branch_scope_errors(
        root,
        base,
        [("M", "openspec/changes/archive/2000-01-01-first-change/tasks.md")],
    )
    replaced = branch_scope_errors(
        root,
        base,
        [
            (
                "D",
                "openspec/changes/archive/1999-01-01-first-change/tasks.md",
            ),
            (
                "A",
                "openspec/changes/archive/2000-01-01-first-change/"
                ".openspec.yaml",
            ),
        ],
    )
    print(
        "openspec-gate self-test: non-empty branch scope requires one new "
        "lifecycle or maintenance exemption and counts deletions"
    )
    return (
        not empty
        and any("must add exactly one governed change lifecycle" in error for error in missing)
        and any("changes 2 change lifecycles" in error for error in deletion)
        and any("must add exactly one lifecycle" in error for error in marker_missing)
        and any("cannot modify, delete" in error for error in replaced)
    )


def active_baseline_presynchronization_is_rejected() -> bool:
    root = Path("/active-presynchronization-self-test")
    active_entries = [
        ("A", "openspec/changes/example-change/.openspec.yaml"),
        ("A", "openspec/changes/example-change/specs/example/spec.md"),
        ("A", "openspec/specs/example/spec.md"),
        ("A", "src/implementation.py"),
    ]
    archived_entries = [
        (
            "A",
            "openspec/changes/archive/2000-01-01-example-change/.openspec.yaml",
        ),
        (
            "A",
            "openspec/changes/archive/2000-01-01-example-change/specs/"
            "example/spec.md",
        ),
        ("A", "openspec/specs/example/spec.md"),
        ("A", "src/implementation.py"),
    ]
    active_errors = branch_scope_errors(
        root, "base-self-test", active_entries, require_archived=False
    )
    archived_errors = branch_scope_errors(
        root, "base-self-test", archived_entries, require_archived=True
    )
    print(
        "openspec-gate self-test: active lifecycles cannot pre-synchronize "
        "baseline specs, while archived lifecycles may synchronize them"
    )
    return any("cannot pre-synchronize baseline" in error for error in active_errors) and not (
        archived_errors
    )


def maintenance_exemption_controls_are_enforced() -> bool:
    with tempfile.TemporaryDirectory(prefix="nautilus-openspec-exemption-") as directory:
        root = Path(directory)
        parent = exemptions_root(root)
        parent.mkdir(parents=True)
        relative = "openspec/exemptions/2000-01-01-doc-typo.toml"
        manifest = root / relative
        manifest.write_text(
            'kind = "maintenance"\n'
            'reason = "Correct a documentation typo without changing behavior."\n'
            'paths = ["README.md"]\n',
            encoding="utf-8",
        )
        valid = branch_scope_errors(
            root,
            "base-self-test",
            [("M", "README.md"), ("A", relative)],
            require_archived=True,
        )
        uncovered = branch_scope_errors(
            root,
            "base-self-test",
            [
                ("M", "README.md"),
                ("M", "docs/architecture.md"),
                ("A", relative),
            ],
        )
        modified = branch_scope_errors(
            root,
            "base-self-test",
            [("M", "README.md"), ("M", relative)],
        )
        mixed = branch_scope_errors(
            root,
            "base-self-test",
            [
                (
                    "A",
                    "openspec/changes/archive/2000-01-01-real-change/"
                    ".openspec.yaml",
                ),
                ("A", relative),
            ],
        )
        invalid_date = parent / "2000-99-99-impossible.toml"
        invalid_date.write_text(manifest.read_text(encoding="utf-8"), encoding="utf-8")
        invalid_date_errors = exemption_manifest_errors(root, invalid_date)
        target = root / "mutable-exemption-target.toml"
        target.write_text(manifest.read_text(encoding="utf-8"), encoding="utf-8")
        symlink = parent / "2000-01-02-symlink.toml"
        symlink.symlink_to(target)
        symlink_errors = exemption_manifest_errors(root, symlink)
        print(
            "openspec-gate self-test: maintenance exemptions must be new, "
            "exclusive, exact-path, valid-date regular files"
        )
        return (
            not valid
            and any("paths do not match" in error for error in uncovered)
            and any("must be newly added" in error for error in modified)
            and any("cannot combine" in error for error in mixed)
            and any("valid calendar date" in error for error in invalid_date_errors)
            and any("non-symlink" in error for error in symlink_errors)
        )


def undescribed_tasks_are_rejected(root: Path) -> bool:
    with tempfile.TemporaryDirectory(
        prefix="nautilus-openspec-task-description-"
    ) as directory:
        fixture_root = Path(directory)
        shutil.copytree(root / "openspec", fixture_root / "openspec")
        archived = ensure_archived_change_for_self_test(fixture_root)
        tasks = archived / "tasks.md"
        tasks.write_text("- [x]\n", encoding="utf-8")
        errors = governance_errors(
            fixture_root,
            active_change_dirs(fixture_root),
            require_complete=True,
        )
        print(
            "openspec-gate self-test: task checkboxes without descriptions "
            "must fail completion mode"
        )
        return any(
            "without non-whitespace descriptions" in error for error in errors
        )


def archived_spec_sync_is_enforced(root: Path) -> bool:
    with tempfile.TemporaryDirectory(
        prefix="nautilus-openspec-archive-sync-control-"
    ) as directory:
        fixture_root = Path(directory)
        fixture_openspec = fixture_root / "openspec"
        fixture_openspec.mkdir(parents=True)
        shutil.copy2(
            root / "openspec" / "config.yaml",
            fixture_openspec / "config.yaml",
        )
        change = (
            fixture_openspec
            / "changes"
            / ARCHIVE_NAME
            / "2000-01-01-archive-sync-self-test"
        )
        delta = change / "specs" / "archive-sync-self-test" / "spec.md"
        delta.parent.mkdir(parents=True)
        (change / ".openspec.yaml").write_text(
            "schema: spec-driven\ncreated: 2000-01-01\n", encoding="utf-8"
        )
        (change / "proposal.md").write_text(
            "## Why\n\nExercise archive synchronization.\n\n"
            "## What Changes\n\n- Add one fixture requirement.\n",
            encoding="utf-8",
        )
        (change / "design.md").write_text(
            "## Context\n\nSelf-test fixture.\n", encoding="utf-8"
        )
        (change / "tasks.md").write_text(
            "- [x] 1.1 Exercise archive synchronization.\n", encoding="utf-8"
        )
        requirement = (
            "### Requirement: Archive synchronization is enforced\n"
            "The governance gate SHALL reject an archive whose delta is absent "
            "from the baseline specification.\n\n"
            "#### Scenario: Baseline requirement is missing\n"
            "- **WHEN** an archived delta is not present in the baseline\n"
            "- **THEN** the governance gate SHALL fail\n"
        )
        delta.write_text(
            "## ADDED Requirements\n\n" + requirement,
            encoding="utf-8",
        )
        baseline = (
            fixture_openspec
            / "specs"
            / "archive-sync-self-test"
            / "spec.md"
        )
        baseline.parent.mkdir(parents=True)
        baseline_content = (
            "# Archive Sync Self-Test Specification\n\n"
            "## Purpose\n\nExercise the synchronization control.\n\n"
            "## Requirements\n\n"
            + requirement
        )
        baseline.write_text(baseline_content, encoding="utf-8")
        valid = archived_spec_sync_errors(
            fixture_root, change, openspec_bin(), {}
        )
        baseline.unlink()
        missing = archived_spec_sync_errors(
            fixture_root, change, openspec_bin(), {}
        )
        baseline.write_text(
            baseline_content.replace(
                "Scenario: Baseline requirement is missing",
                "Scenario: Baseline requirement drifted",
            ),
            encoding="utf-8",
        )
        divergent = archived_spec_sync_errors(
            fixture_root, change, openspec_bin(), {}
        )
        print(
            "openspec-gate self-test: archived deltas must be synchronized "
            "into baseline requirements"
        )
        return (
            not valid
            and any("is not synchronized" in error for error in missing)
            and any("is not synchronized" in error for error in divergent)
        )


def asterisk_unchecked_tasks_are_rejected(root: Path) -> bool:
    with tempfile.TemporaryDirectory(prefix="nautilus-openspec-task-marker-") as directory:
        fixture_root = Path(directory)
        shutil.copytree(root / "openspec", fixture_root / "openspec")
        archived = ensure_archived_change_for_self_test(fixture_root)
        tasks = archived / "tasks.md"
        text = tasks.read_text(encoding="utf-8")
        completed = CHECKBOX.sub(
            lambda match: match.group(0).replace("[ ]", "[x]", 1), text
        )
        tasks.write_text(
            completed + "\n* [ ] Deliberately incomplete asterisk task\n",
            encoding="utf-8",
        )
        errors = governance_errors(
            fixture_root,
            active_change_dirs(fixture_root),
            require_complete=True,
        )
        print(
            "openspec-gate self-test: asterisk unchecked tasks must fail "
            "completion mode"
        )
        return any(
            "archived change" in error and "1/" in error and "unchecked tasks" in error
            for error in errors
        )


def tab_unchecked_tasks_are_rejected(root: Path) -> bool:
    with tempfile.TemporaryDirectory(prefix="nautilus-openspec-tab-task-") as directory:
        fixture_root = Path(directory)
        shutil.copytree(root / "openspec", fixture_root / "openspec")
        archived = ensure_archived_change_for_self_test(fixture_root)
        tasks = archived / "tasks.md"
        text = tasks.read_text(encoding="utf-8")
        completed = CHECKBOX.sub(
            lambda match: match.group(0)[: match.start("mark") - match.start()]
            + "x"
            + match.group(0)[match.end("mark") - match.start() :],
            text,
        )
        tasks.write_text(
            completed + "\n- [\t] Deliberately incomplete tab-marked task\n",
            encoding="utf-8",
        )
        errors = governance_errors(
            fixture_root,
            active_change_dirs(fixture_root),
            require_complete=True,
        )
        print(
            "openspec-gate self-test: tab-marked unchecked tasks must fail "
            "completion mode"
        )
        return any(
            "archived change" in error and "1/" in error and "unchecked tasks" in error
            for error in errors
        )


def unicode_separator_unchecked_tasks_are_rejected(root: Path) -> bool:
    with tempfile.TemporaryDirectory(
        prefix="nautilus-openspec-unicode-task-separator-"
    ) as directory:
        fixture_root = Path(directory)
        shutil.copytree(root / "openspec", fixture_root / "openspec")
        archived = ensure_archived_change_for_self_test(fixture_root)
        tasks = archived / "tasks.md"
        text = tasks.read_text(encoding="utf-8")
        completed = CHECKBOX.sub(
            lambda match: match.group(0)[: match.start("mark") - match.start()]
            + "x"
            + match.group(0)[match.end("mark") - match.start() :],
            text,
        )
        tasks.write_text(
            completed + "\n-\N{NO-BREAK SPACE}[ ] Deliberately incomplete task\n",
            encoding="utf-8",
        )
        errors = governance_errors(
            fixture_root,
            active_change_dirs(fixture_root),
            require_complete=True,
        )
        print(
            "openspec-gate self-test: Unicode-separated unchecked tasks must "
            "fail completion mode"
        )
        return any(
            "archived change" in error and "1/" in error and "unchecked tasks" in error
            for error in errors
        )


def all_openspec_task_whitespace_is_counted() -> bool:
    with tempfile.TemporaryDirectory(
        prefix="nautilus-openspec-task-whitespace-set-"
    ) as directory:
        change = Path(directory)
        tasks = change / "tasks.md"
        lines = [
            *(f"-{separator}[ ] Incomplete separator task" for separator in TASK_WHITESPACE),
            *(f"- [{mark}] Incomplete mark task" for mark in TASK_WHITESPACE),
            "- [X] Complete uppercase task",
        ]
        tasks.write_bytes(("\n".join(lines) + "\n").encode("utf-8"))
        total, unchecked = task_counts(change)
        print(
            "openspec-gate self-test: every non-LF ECMAScript whitespace "
            "character and uppercase completion mark recognized by OpenSpec "
            "must be counted"
        )
        return total == len(lines) and unchecked == len(lines) - 1


def uppercase_undescribed_tasks_are_rejected(root: Path) -> bool:
    with tempfile.TemporaryDirectory(
        prefix="nautilus-openspec-uppercase-task-marker-"
    ) as directory:
        fixture_root = Path(directory)
        shutil.copytree(root / "openspec", fixture_root / "openspec")
        archived = ensure_archived_change_for_self_test(fixture_root)
        tasks = archived / "tasks.md"
        tasks.write_text("- [X]\n", encoding="utf-8")
        errors = governance_errors(
            fixture_root,
            active_change_dirs(fixture_root),
            require_complete=True,
        )
        print(
            "openspec-gate self-test: uppercase completed tasks without "
            "descriptions must fail completion mode"
        )
        return any(
            "without non-whitespace descriptions" in error for error in errors
        )


def crlf_unchecked_tasks_are_rejected(root: Path) -> bool:
    with tempfile.TemporaryDirectory(
        prefix="nautilus-openspec-crlf-unchecked-task-"
    ) as directory:
        fixture_root = Path(directory)
        shutil.copytree(root / "openspec", fixture_root / "openspec")
        archived = ensure_archived_change_for_self_test(fixture_root)
        tasks = archived / "tasks.md"
        tasks.write_bytes(
            b"- [x] Complete LF control\n"
            b"- [x] Complete CRLF control\r\n"
            b"- [ ] Deliberately incomplete CRLF task\r\n"
        )
        errors = governance_errors(
            fixture_root,
            active_change_dirs(fixture_root),
            require_complete=True,
        )
        print(
            "openspec-gate self-test: mixed LF/CRLF unchecked tasks must fail "
            "completion mode"
        )
        return any(
            "archived change" in error
            and "1/3" in error
            and "unchecked tasks" in error
            for error in errors
        )


def crlf_undescribed_tasks_are_rejected(root: Path) -> bool:
    with tempfile.TemporaryDirectory(
        prefix="nautilus-openspec-crlf-undescribed-task-"
    ) as directory:
        fixture_root = Path(directory)
        shutil.copytree(root / "openspec", fixture_root / "openspec")
        archived = ensure_archived_change_for_self_test(fixture_root)
        tasks = archived / "tasks.md"
        tasks.write_bytes(b"- [x]\r\n")
        errors = governance_errors(
            fixture_root,
            active_change_dirs(fixture_root),
            require_complete=True,
        )
        print(
            "openspec-gate self-test: CRLF completed tasks without "
            "descriptions must fail completion mode"
        )
        return any(
            "without non-whitespace descriptions" in error for error in errors
        )


def lifecycle_schema_controls_are_enforced(root: Path) -> bool:
    with tempfile.TemporaryDirectory(prefix="nautilus-openspec-schema-") as directory:
        fixture_root = Path(directory)
        shutil.copytree(root / "openspec", fixture_root / "openspec")
        archived = ensure_archived_change_for_self_test(fixture_root)
        (archived / ".openspec.yaml").write_text(
            "schema: minimal\ncreated: 2000-01-01\n", encoding="utf-8"
        )
        schema = fixture_root / "openspec" / "schemas" / "minimal" / "schema.yaml"
        schema.parent.mkdir(parents=True)
        schema.write_text(
            "name: minimal\nversion: 1\nartifacts:\n  tasks:\n    generates: tasks.md\n",
            encoding="utf-8",
        )
        errors = governance_errors(
            fixture_root,
            active_change_dirs(fixture_root),
            require_complete=False,
        )
        print(
            "openspec-gate self-test: every lifecycle must use the built-in "
            "spec-driven schema and project-local overrides must fail"
        )
        return any("must select exactly the built-in" in error for error in errors) and any(
            "project-local OpenSpec schemas are forbidden" in error for error in errors
        )


def merge_bound_mode_requires_archived_evidence(root: Path) -> bool:
    with tempfile.TemporaryDirectory(prefix="nautilus-openspec-merge-mode-") as directory:
        fixture_root = Path(directory)
        shutil.copytree(root / "openspec", fixture_root / "openspec")
        mark_active_tasks_complete(fixture_root)
        source = ensure_archived_change_for_self_test(fixture_root)
        match = archived_change_match(source.name)
        if match is None:
            raise RuntimeError(f"self-test found invalid archived change: {source}")
        identifier = match.group("name")
        active_change = changes_root(fixture_root) / identifier
        shutil.copytree(source, active_change)
        shutil.rmtree(source)
        active = active_change_dirs(fixture_root)
        pre_archive_errors = governance_errors(
            fixture_root,
            active,
            require_complete=True,
            require_archived=False,
        )
        merge_bound_errors = governance_errors(
            fixture_root,
            active,
            require_complete=True,
            require_archived=True,
        )
        entries = [
            ("A", f"openspec/changes/{identifier}/.openspec.yaml"),
            ("A", "src/implementation.py"),
        ]
        pre_archive_scope = branch_scope_errors(
            fixture_root,
            "base-self-test",
            entries,
            require_archived=False,
        )
        merge_bound_scope = branch_scope_errors(
            fixture_root,
            "base-self-test",
            entries,
            require_archived=True,
        )
        print(
            "openspec-gate self-test: pre-archive mode may validate one active "
            "lifecycle, but merge-bound mode must require archived evidence"
        )
        return (
            not pre_archive_errors
            and not pre_archive_scope
            and any("requires zero active changes" in error for error in merge_bound_errors)
            and any(
                "lifecycle evidence must be archived" in error
                for error in merge_bound_scope
            )
        )


def self_test(
    root: Path,
    *,
    require_complete: bool,
    require_archived: bool,
    base: str | None = None,
) -> int:
    print("openspec-gate self-test: valid repository must pass")
    if validate(
        root,
        require_complete=require_complete,
        require_archived=require_archived,
        base=base,
    ) != 0:
        print("openspec-gate self-test: valid repository failed", file=sys.stderr)
        return 1

    checks = (
        expect_invalid(root, "malformed spec must fail", malformed_spec),
        malformed_archived_specs_are_rejected(root),
        expect_invalid(root, "reserved archive change must fail", reserved_archive_change),
        expect_invalid(root, "incomplete archive must fail", incomplete_archive),
        multiple_active_changes_are_rejected(root),
        multiple_lifecycle_paths_are_distinct(),
        openspec_symlinks_are_rejected(root),
        hidden_lifecycle_directories_are_rejected(root),
        branch_scope_evidence_is_required(),
        active_baseline_presynchronization_is_rejected(),
        maintenance_exemption_controls_are_enforced(),
        malformed_archive_names_are_rejected(root),
        invalid_archive_calendar_dates_are_rejected(root),
        missing_archived_artifacts_are_rejected(root),
        incomplete_active_tasks_are_rejected(root),
        undescribed_tasks_are_rejected(root),
        archived_spec_sync_is_enforced(root),
        asterisk_unchecked_tasks_are_rejected(root),
        tab_unchecked_tasks_are_rejected(root),
        unicode_separator_unchecked_tasks_are_rejected(root),
        all_openspec_task_whitespace_is_counted(),
        uppercase_undescribed_tasks_are_rejected(root),
        crlf_unchecked_tasks_are_rejected(root),
        crlf_undescribed_tasks_are_rejected(root),
        lifecycle_schema_controls_are_enforced(root),
        merge_bound_mode_requires_archived_evidence(root),
        archived_identifier_reuse_is_rejected(root),
        duplicate_archived_identifiers_are_rejected(root),
        expect_invalid(
            root,
            "mixed-case identifier must fail",
            lambda fixture: invalid_identifier(fixture, "Bad_Name"),
        ),
        expect_invalid(
            root,
            "option-like identifier must fail",
            lambda fixture: invalid_identifier(fixture, "--all"),
        ),
    )
    failed = [str(index) for index, passed in enumerate(checks, start=1) if not passed]
    if failed:
        print(
            "openspec-gate self-test: negative control(s) accepted at "
            + ", ".join(failed),
            file=sys.stderr,
        )
        return 1

    print("openspec-gate self-test: PASS")
    return 0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Strictly validate all Nautilus OpenSpec changes and specs."
    )
    parser.add_argument(
        "--require-complete",
        action="store_true",
        help="reject active changes with incomplete artifacts or unchecked tasks",
    )
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument(
        "--merge-bound",
        action="store_true",
        help="require complete work with no active lifecycle and archived evidence",
    )
    mode.add_argument(
        "--pre-archive",
        action="store_true",
        help="require complete artifacts and tasks while allowing one active lifecycle",
    )
    parser.add_argument(
        "--self-test",
        action="store_true",
        help="prove the gate accepts this repository and rejects invalid copies",
    )
    parser.add_argument(
        "--base",
        help=(
            "require branch diffs to add exactly one change lifecycle or one "
            "path-scoped maintenance exemption"
        ),
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    require_complete = args.require_complete or args.merge_bound or args.pre_archive
    try:
        if args.self_test:
            return self_test(
                ROOT,
                require_complete=require_complete,
                require_archived=args.merge_bound,
                base=args.base,
            )
        return validate(
            ROOT,
            require_complete=require_complete,
            require_archived=args.merge_bound,
            base=args.base,
        )
    except (OSError, RuntimeError) as error:
        print(f"openspec-gate: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
