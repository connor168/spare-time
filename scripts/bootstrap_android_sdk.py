from __future__ import annotations

import argparse
import hashlib
import os
import re
import shutil
import subprocess
import sys
import urllib.parse
import urllib.request
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
TOOLS = ROOT / ".tools"
DOWNLOADS = TOOLS / "downloads"
ANDROID_SDK_ROOT = TOOLS / "android-sdk"
CMDLINE_TOOLS_ROOT = ANDROID_SDK_ROOT / "cmdline-tools" / "latest"
SDKMANAGER = CMDLINE_TOOLS_ROOT / "bin" / "sdkmanager.bat"

JDK_ROOT = TOOLS / "jdk-17"
JAVA_EXE = JDK_ROOT / "bin" / "java.exe"

ANDROID_STUDIO_URL = "https://developer.android.com/studio"
MICROSOFT_JDK_URL = "https://aka.ms/download-jdk/microsoft-jdk-17.0.20-windows-x64.zip"
MICROSOFT_JDK_SHA_URL = (
    "https://aka.ms/download-jdk/"
    "microsoft-jdk-17.0.20-windows-x64.zip.sha256sum.txt"
)

DEFAULT_ANDROID_PACKAGES = (
    "platform-tools",
    "platforms;android-36",
    "build-tools;36.0.0",
)


def info(message: str) -> None:
    print(f"[android-bootstrap] {message}", flush=True)


def resolved_inside(path: Path, parent: Path) -> bool:
    try:
        path.resolve().relative_to(parent.resolve())
        return True
    except ValueError:
        return False


def safe_rmtree(path: Path) -> None:
    if not path.exists():
        return
    if not resolved_inside(path, TOOLS):
        raise RuntimeError(f"Refusing to remove path outside {TOOLS}: {path}")
    shutil.rmtree(path)


def fetch_text(url: str) -> str:
    with urllib.request.urlopen(url, timeout=60) as response:
        return response.read().decode("utf-8", errors="replace")


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
                    info(
                        f"downloaded {done // (1024 * 1024)} MB / "
                        f"{total // (1024 * 1024)} MB ({percent:.1f}%)"
                    )
                    next_report = done + 50 * 1024 * 1024


def verify_or_download(url: str, expected_hash: str, archive_path: Path) -> None:
    if archive_path.exists():
        info(f"Reusing existing archive {archive_path}")
    else:
        info(f"Downloading {url}")
        download(url, archive_path)

    actual_hash = sha256_file(archive_path)
    if actual_hash.lower() != expected_hash.lower():
        archive_path.unlink(missing_ok=True)
        raise RuntimeError(
            "Checksum mismatch. "
            f"Expected {expected_hash.lower()}, got {actual_hash.lower()}."
        )


def select_windows_cmdline_tools() -> tuple[str, str]:
    html = fetch_text(ANDROID_STUDIO_URL)
    match = re.search(r"commandlinetools-win-[^<>\s]+?\.zip", html)
    if not match:
        raise RuntimeError("Could not find Windows command-line tools on Android Studio page.")

    filename = match.group(0)
    url = f"https://dl.google.com/android/repository/{filename}"
    window = html[max(0, match.start() - 5000) : match.end() + 5000]
    checksum_match = re.search(r"[A-Fa-f0-9]{64}", window)
    if not checksum_match:
        raise RuntimeError("Could not find checksum for Windows command-line tools.")

    return url, checksum_match.group(0).lower()


def install_jdk() -> None:
    if JAVA_EXE.exists():
        info(f"JDK 17 already installed at {JDK_ROOT}")
        return

    checksum_text = fetch_text(MICROSOFT_JDK_SHA_URL)
    checksum_match = re.search(r"[A-Fa-f0-9]{64}", checksum_text)
    if not checksum_match:
        raise RuntimeError("Microsoft JDK checksum text did not include a SHA-256 hash.")

    archive_path = DOWNLOADS / Path(urllib.parse.urlparse(MICROSOFT_JDK_URL).path).name
    verify_or_download(MICROSOFT_JDK_URL, checksum_match.group(0), archive_path)

    temp_dir = TOOLS / "_jdk17_extract"
    safe_rmtree(temp_dir)
    temp_dir.mkdir(parents=True, exist_ok=True)
    info(f"Extracting JDK to {temp_dir}")
    with zipfile.ZipFile(archive_path) as archive:
        archive.extractall(temp_dir)

    candidates = sorted(temp_dir.glob("*/bin/java.exe"))
    if not candidates:
        raise RuntimeError("Downloaded JDK archive did not contain bin/java.exe.")

    if JDK_ROOT.exists():
        raise RuntimeError(f"{JDK_ROOT} exists but does not contain bin/java.exe.")

    shutil.move(str(candidates[0].parents[1]), str(JDK_ROOT))
    safe_rmtree(temp_dir)
    info(f"JDK 17 installed at {JDK_ROOT}")


def install_cmdline_tools() -> None:
    if SDKMANAGER.exists():
        info(f"Android command-line tools already installed at {CMDLINE_TOOLS_ROOT}")
        return

    url, expected_hash = select_windows_cmdline_tools()
    archive_path = DOWNLOADS / Path(urllib.parse.urlparse(url).path).name
    verify_or_download(url, expected_hash, archive_path)

    temp_dir = TOOLS / "_android_cmdline_tools_extract"
    safe_rmtree(temp_dir)
    temp_dir.mkdir(parents=True, exist_ok=True)
    info(f"Extracting Android command-line tools to {temp_dir}")
    with zipfile.ZipFile(archive_path) as archive:
        archive.extractall(temp_dir)

    extracted_root = temp_dir / "cmdline-tools"
    if not (extracted_root / "bin" / "sdkmanager.bat").exists():
        raise RuntimeError("Downloaded Android tools archive did not contain sdkmanager.bat.")

    CMDLINE_TOOLS_ROOT.parent.mkdir(parents=True, exist_ok=True)
    if CMDLINE_TOOLS_ROOT.exists():
        raise RuntimeError(f"{CMDLINE_TOOLS_ROOT} exists but sdkmanager.bat is missing.")

    shutil.move(str(extracted_root), str(CMDLINE_TOOLS_ROOT))
    safe_rmtree(temp_dir)
    info(f"Android command-line tools installed at {CMDLINE_TOOLS_ROOT}")


def proxy_args() -> list[str]:
    proxy_value = os.environ.get("HTTPS_PROXY") or os.environ.get("HTTP_PROXY")
    if not proxy_value:
        return []

    parsed = urllib.parse.urlparse(proxy_value)
    if not parsed.hostname or not parsed.port:
        return []

    proxy_kind = "socks" if parsed.scheme.startswith("socks") else "http"
    return [
        f"--proxy={proxy_kind}",
        f"--proxy_host={parsed.hostname}",
        f"--proxy_port={parsed.port}",
    ]


def run_sdkmanager(args: list[str], *, answer_yes: bool = False) -> None:
    env = os.environ.copy()
    env["JAVA_HOME"] = str(JDK_ROOT)
    env["ANDROID_HOME"] = str(ANDROID_SDK_ROOT)
    env["ANDROID_SDK_ROOT"] = str(ANDROID_SDK_ROOT)
    env["PATH"] = os.pathsep.join(
        [
            str(JDK_ROOT / "bin"),
            str(CMDLINE_TOOLS_ROOT / "bin"),
            str(ANDROID_SDK_ROOT / "platform-tools"),
            env.get("PATH", ""),
        ]
    )

    command = [str(SDKMANAGER), f"--sdk_root={ANDROID_SDK_ROOT}", *proxy_args(), *args]
    info("Running sdkmanager " + " ".join(args))
    result = subprocess.run(
        command,
        input=("y\n" * 200) if answer_yes else None,
        text=True,
        env=env,
        cwd=ROOT,
        check=False,
    )
    if result.returncode != 0:
        raise RuntimeError(f"sdkmanager failed with exit code {result.returncode}.")


def install_android_packages(packages: tuple[str, ...]) -> None:
    if not packages:
        return
    run_sdkmanager(list(packages), answer_yes=True)
    run_sdkmanager(["--licenses"], answer_yes=True)


def update_local_properties() -> None:
    local_properties = ROOT / "android" / "local.properties"
    values: dict[str, str] = {}
    if local_properties.exists():
        for raw_line in local_properties.read_text(encoding="utf-8").splitlines():
            if "=" not in raw_line:
                continue
            key, value = raw_line.split("=", 1)
            values[key.strip()] = value.strip()
    values["sdk.dir"] = str(ANDROID_SDK_ROOT)
    ordered_lines = [f"{key}={value}" for key, value in values.items()]
    local_properties.write_text("\n".join(ordered_lines) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description="Install the local Android SDK toolchain.")
    parser.add_argument(
        "--skip-packages",
        action="store_true",
        help="Only install JDK and Android command-line tools.",
    )
    args = parser.parse_args()

    TOOLS.mkdir(parents=True, exist_ok=True)
    install_jdk()
    install_cmdline_tools()
    if args.skip_packages:
        info("Skipping Android package installation.")
    else:
        install_android_packages(DEFAULT_ANDROID_PACKAGES)
    update_local_properties()

    info(f"Android SDK root: {ANDROID_SDK_ROOT}")
    info(f"JAVA_HOME: {JDK_ROOT}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"[android-bootstrap] ERROR: {exc}", file=sys.stderr)
        raise SystemExit(1)
