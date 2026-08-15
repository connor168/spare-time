"""Export the Focus Flow icon master to review, web, and Android sizes."""

from __future__ import annotations

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
MASTER = ROOT / "assets" / "branding" / "focus-flow-icon-master.png"


def save_png(image: Image.Image, path: Path, size: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    resized = image.resize((size, size), Image.Resampling.LANCZOS)
    resized.save(path, format="PNG", optimize=True)


def main() -> None:
    with Image.open(MASTER) as source:
        image = source.convert("RGBA")
        if image.width != image.height:
            edge = min(image.width, image.height)
            left = (image.width - edge) // 2
            top = (image.height - edge) // 2
            image = image.crop((left, top, left + edge, top + edge))

        exports = {
            ROOT / "assets" / "branding" / "focus-flow-wechat-28.png": 28,
            ROOT / "assets" / "branding" / "focus-flow-wechat-108.png": 108,
            ROOT / "assets" / "branding" / "focus-flow-store-512.png": 512,
            ROOT / "site" / "assets" / "app-icon.png": 512,
            ROOT / "android" / "app" / "src" / "main" / "res" / "mipmap-mdpi" / "ic_launcher.png": 48,
            ROOT / "android" / "app" / "src" / "main" / "res" / "mipmap-hdpi" / "ic_launcher.png": 72,
            ROOT / "android" / "app" / "src" / "main" / "res" / "mipmap-xhdpi" / "ic_launcher.png": 96,
            ROOT / "android" / "app" / "src" / "main" / "res" / "mipmap-xxhdpi" / "ic_launcher.png": 144,
            ROOT / "android" / "app" / "src" / "main" / "res" / "mipmap-xxxhdpi" / "ic_launcher.png": 192,
        }

        for path, size in exports.items():
            save_png(image, path, size)
            print(f"{path.relative_to(ROOT)}: {size}x{size}, {path.stat().st_size} bytes")


if __name__ == "__main__":
    main()
