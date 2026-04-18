#!/usr/bin/env python3
"""Shared Chelis toolchain resolution helpers."""
from __future__ import annotations

import os
import shutil
from pathlib import Path


CHELIS_ENV_VAR = "CHELIS_BIN"
CHELIS_PATH_FALLBACK = "chelis"


def resolve_chelis_bin() -> str:
    """Resolve the configured `chelis` binary or raise a clear error."""
    explicit = os.environ.get(CHELIS_ENV_VAR)
    if explicit:
        path = Path(explicit).expanduser()
        if path.is_file() and os.access(path, os.X_OK):
            return str(path)
        if shutil.which(explicit):
            return explicit
        raise SystemExit(
            f"{CHELIS_ENV_VAR} is set to {explicit!r}, but that binary was not found. "
            f"Set {CHELIS_ENV_VAR} to an executable path or put {CHELIS_PATH_FALLBACK!r} on PATH."
        )

    found = shutil.which(CHELIS_PATH_FALLBACK)
    if found:
        return found

    raise SystemExit(
        "Could not find the Chelis compiler. "
        f"Set {CHELIS_ENV_VAR}=/path/to/chelis or put {CHELIS_PATH_FALLBACK!r} on PATH."
    )
