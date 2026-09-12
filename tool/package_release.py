"""Package Flutter outputs without losing native permissions or app symlinks."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tarfile
import zipfile


ROOT = Path(__file__).resolve().parent.parent
APP = ROOT / "apps/gomoku_app"
VERSION = re.search(
    r"^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$",
    (APP / "pubspec.yaml").read_text(encoding="utf-8"),
    re.MULTILINE,
)
if VERSION is None:
    raise SystemExit("pubspec.yaml must contain a release version and build number")
NAME, BUILD = VERSION.groups()
FILES = {
    "web": f"Gomoku-{NAME}-web.zip",
    "windows": f"Gomoku-{NAME}-windows-x64.zip",
    "linux": f"Gomoku-{NAME}-linux-x64.tar.gz",
    "apk": f"Gomoku-{NAME}-android.apk",
    "macos": f"Gomoku-{NAME}-macos-universal.zip",
    "ios": f"Gomoku-{NAME}-ios-unsigned.zip",
    "server": f"Gomoku-{NAME}-server-debian12-x64.tar.gz",
}


def require(path):
    if not path.exists():
        raise SystemExit(f"Missing build output: {path}")
    return path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("target", choices=[*FILES, "manifest", "check-version"])
    parser.add_argument("--output", type=Path, default=ROOT / "artifacts/releases")
    parser.add_argument("--server-binary", type=Path, default=ROOT / "artifacts/native/gomoku-server")
    args = parser.parse_args()
    if os.environ.get("GITHUB_REF_TYPE") == "tag":
        if not re.fullmatch(rf"v{re.escape(NAME)}(?:-rc\.\d+)?", os.environ.get("GITHUB_REF_NAME", "")):
            raise SystemExit("Git tag and pubspec.yaml version do not match")
    notes = require(ROOT / f"docs/releases/v{NAME}.md")
    if args.target == "check-version":
        print(f"Version {NAME}+{BUILD}")
        return
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    if args.target == "manifest":
        # A partial platform build must never become a published release.
        assets = [require(output / name) for name in FILES.values()]
        assets.append(require(output / "android-signature.txt"))
        for asset in assets:
            if asset.stat().st_size == 0:
                raise SystemExit(f"Empty release asset: {asset.name}")
        metadata = output / "build-info.json"
        metadata.write_text(
            json.dumps(
                {
                    "version": NAME,
                    "buildNumber": int(BUILD),
                    "commit": os.environ.get("GITHUB_SHA"),
                    "workflowRun": (
                        f"https://github.com/{os.environ.get('GITHUB_REPOSITORY')}/"
                        f"actions/runs/{os.environ.get('GITHUB_RUN_ID')}"
                    ),
                    "flutter": json.loads((ROOT / ".fvmrc").read_text())["flutter"],
                    "platforms": FILES,
                    "androidApplicationId": "com.xqd922.gomoku",
                    "iosSigned": False,
                    "macosNotarized": False,
                },
                ensure_ascii=False,
                indent=2,
            ) + "\n",
            encoding="utf-8",
        )
        readme = output / "RELEASE_NOTES.md"
        shutil.copyfile(notes, readme)
        assets.extend([metadata, readme])
        checksums = []
        for asset in sorted(assets, key=lambda path: path.name):
            with asset.open("rb") as stream:
                digest = hashlib.file_digest(stream, "sha256").hexdigest()
            checksums.append(f"{digest}  {asset.name}\n")
        (output / "SHA256SUMS.txt").write_text("".join(checksums), encoding="ascii")
        print(f"Verified {len(FILES)} platform packages and wrote SHA256SUMS.txt")
        return

    archive = output / FILES[args.target]
    if archive.exists():
        raise SystemExit(f"Refusing to replace an existing package: {archive}")
    if args.target == "server":
        commit = os.environ.get("GITHUB_SHA") or subprocess.check_output(
            ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
        if not re.fullmatch(r"[0-9a-f]{40}", commit):
            raise SystemExit("A server release must have a source commit")
        import io
        with tarfile.open(archive, "w:gz") as bundle:
            bundle.add(require(args.server_binary), arcname="gomoku-server")
            bundle.add(require(ROOT / "infra/native/production.yaml"), arcname="config/production.yaml")
            for source, target in [(ROOT / "apps/server/db", "db"),
                                   (ROOT / "apps/server/migrations", "migrations"),
                                   (APP / "build/web", "web"),
                                   (ROOT / "infra/native", "native")]:
                require(source)
                for path in sorted(source.rglob("*")):
                    if path.is_file() and "__pycache__" not in path.parts:
                        bundle.add(path, arcname=f"{target}/{path.relative_to(source).as_posix()}")
            for name, value in {
                "build-info.json": json.dumps({"version": NAME, "buildNumber": int(BUILD), "commit": commit}) + "\n",
                "build.env": f"GOMOKU_VERSION={NAME}\nGOMOKU_COMMIT={commit}\n",
            }.items():
                payload = value.encode("utf-8")
                entry = tarfile.TarInfo(name)
                entry.size, entry.mode = len(payload), 0o644
                bundle.addfile(entry, io.BytesIO(payload))
            bundle.add(notes, arcname="README-release.md")
    elif args.target in ("windows", "web"):
        relative = "windows/x64/runner/Release" if args.target == "windows" else "web"
        source = require(APP / "build" / relative)
        if args.target == "windows":
            require(source / "Gomoku.exe")
            require(source / "flutter_windows.dll")
            require(source / "data/flutter_assets")
        else:
            for name in ("index.html", "main.dart.js", "sqlite3.wasm", "drift_worker.js", "offline_worker.js"):
                require(source / name)
        with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as bundle:
            for path in sorted(source.rglob("*")):
                if path.is_file():
                    bundle.write(path, path.relative_to(source).as_posix())
            bundle.write(notes, "README-release.md")
    elif args.target == "linux":
        source = require(APP / "build/linux/x64/release/bundle")
        executable = require(source / "Gomoku")
        if not os.access(executable, os.X_OK):
            raise SystemExit("Linux application is not executable")
        with tarfile.open(archive, "w:gz", dereference=False) as bundle:
            bundle.add(source, arcname="Gomoku")
            bundle.add(notes, arcname="Gomoku/README-release.md")
    elif args.target == "apk":
        shutil.copyfile(require(APP / "build/app/outputs/flutter-apk/app-release.apk"), archive)
    else:
        relative = "macos/Build/Products/Release/Gomoku.app" if args.target == "macos" else "ios/iphoneos/Runner.app"
        source = require(APP / "build" / relative)
        if args.target == "macos":
            subprocess.run(
                ["lipo", str(source / "Contents/MacOS/Gomoku"), "-verify_arch", "arm64", "x86_64"],
                check=True,
            )
        subprocess.run(
            ["ditto", "-c", "-k", "--sequesterRsrc", "--keepParent", str(source), str(archive)],
            check=True,
        )
        with zipfile.ZipFile(archive, "a", zipfile.ZIP_DEFLATED) as bundle:
            bundle.write(notes, "README-release.md")
    print(f"Packaged {archive.name} ({archive.stat().st_size:,} bytes)")


if __name__ == "__main__":
    main()
