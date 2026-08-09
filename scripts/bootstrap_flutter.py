from __future__ import annotations

import hashlib
import json
import shutil
import sys
import urllib.request
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
TOOLS = ROOT / ".tools"
DOWNLOADS = TOOLS / "downloads"
FLUTTER_ROOT = TOOLS / "flutter"
FLUTTER_BAT = FLUTTER_ROOT / "bin" / "flutter.bat"
RELEASES_URL = "https://storage.googleapis.com/flutter_infra_release/releases/releases_windows.json"
BASE_URL = "https://storage.googleapis.com/flutter_infra_release/releases/"


def info(message: str) -> None:
    print(f"[flutter-bootstrap] {message}", flush=True)


def fetch_json(url: str) -> dict:
    with urllib.request.urlopen(url, timeout=60) as response:
        return json.loads(response.read())


def select_stable_release(metadata: dict) -> dict:
    stable_ref = metadata.get("current_release", {}).get("stable")
    releases = metadata.get("releases", [])
    for release in releases:
        if release.get("hash") == stable_ref or release.get("version") == stable_ref:
            return release
    for release in releases:
        if release.get("channel") == "stable":
            return release
    raise RuntimeError("No stable Flutter release found in metadata.")


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as file:
        for chunk in iter(lambda: file.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def download(url: str, target: Path) -> None:
    target.parent.mkdir(parents=True, exist_ok=True)
    with urllib.request.urlopen(url, timeout=120) as response:
        total_header = response.headers.get("Content-Length")
        total = int(total_header) if total_header else 0
        done = 0
        next_report = 0
        with target.open("wb") as file:
            while True:
                chunk = response.read(1024 * 1024)
                if not chunk:
                    break
                file.write(chunk)
                done += len(chunk)
                if total and done >= next_report:
                    percent = done * 100 / total
                    info(f"downloaded {done // (1024 * 1024)} MB / {total // (1024 * 1024)} MB ({percent:.1f}%)")
                    next_report = done + 100 * 1024 * 1024


def main() -> int:
    if FLUTTER_BAT.exists():
        info(f"Flutter already installed at {FLUTTER_ROOT}")
        return 0

    info(f"Reading release metadata from {RELEASES_URL}")
    metadata = fetch_json(RELEASES_URL)
    release = select_stable_release(metadata)
    archive = release["archive"]
    expected_hash = release["sha256"].lower()
    archive_url = BASE_URL + archive
    archive_path = DOWNLOADS / Path(archive).name

    info(f"Selected Flutter {release['version']} stable")
    if archive_path.exists():
        info(f"Reusing existing archive {archive_path}")
    else:
        info(f"Downloading {archive_url}")
        download(archive_url, archive_path)

    actual_hash = sha256_file(archive_path)
    if actual_hash != expected_hash:
        archive_path.unlink(missing_ok=True)
        raise RuntimeError(f"Checksum mismatch. Expected {expected_hash}, got {actual_hash}.")

    info(f"Extracting to {TOOLS}")
    TOOLS.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(archive_path) as archive_file:
        archive_file.extractall(TOOLS)

    if not FLUTTER_BAT.exists():
        raise RuntimeError(f"Flutter executable was not found at {FLUTTER_BAT}")

    info(f"Flutter installed at {FLUTTER_ROOT}")
    info(f"Run: {FLUTTER_BAT} doctor")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"[flutter-bootstrap] ERROR: {exc}", file=sys.stderr)
        raise SystemExit(1)
