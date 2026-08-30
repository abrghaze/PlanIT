from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


SEMVER = re.compile(r"^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$")


def _extract(path: Path, pattern: str, label: str) -> str:
    match = re.search(pattern, path.read_text(encoding="utf-8"), flags=re.MULTILINE)
    if match is None:
        raise ValueError(f"Could not read {label} from {path}.")
    return match.group(1)


def validate(root: Path, tag: str | None) -> str:
    mobile_version = _extract(
        root / "mobile" / "pubspec.yaml",
        r"^version:\s*([^+\s]+)\+(\d+)\s*$",
        "mobile version",
    )
    backend_project_version = _extract(
        root / "backend" / "pyproject.toml",
        r'^version\s*=\s*"([^"]+)"\s*$',
        "backend package version",
    )
    backend_runtime_version = _extract(
        root / "backend" / "app" / "core" / "config.py",
        r'^\s*app_version:\s*str\s*=\s*"([^"]+)"\s*$',
        "backend runtime version",
    )
    backend_module_version = _extract(
        root / "backend" / "app" / "__init__.py",
        r'^__version__\s*=\s*"([^"]+)"\s*$',
        "backend module version",
    )

    if not SEMVER.fullmatch(mobile_version):
        raise ValueError(f"Mobile version {mobile_version!r} is not strict semantic versioning.")
    versions = {
        mobile_version,
        backend_project_version,
        backend_runtime_version,
        backend_module_version,
    }
    if len(versions) != 1:
        raise ValueError(
            "Release versions disagree: "
            f"mobile={mobile_version}, backend={backend_project_version}, "
            f"runtime={backend_runtime_version}, module={backend_module_version}."
        )
    if tag is not None and tag != f"v{mobile_version}":
        raise ValueError(f"Tag {tag!r} must equal v{mobile_version}.")
    return mobile_version


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate PlanIT release metadata.")
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--tag")
    args = parser.parse_args()
    try:
        version = validate(args.root.resolve(), args.tag)
    except ValueError as exc:
        print(f"release validation failed: {exc}", file=sys.stderr)
        return 1
    print(version)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
