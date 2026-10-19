#!/usr/bin/env python3
"""Import arbitrary consumer video into DaVinci Resolve on Linux.

Run from Workspace -> Scripts -> Utility -> Import Any Video.
The selected file is transcoded with resolve-ingest to DNxHR HQX + PCM,
then imported into the current Media Pool folder.
"""

import os
import shutil
import subprocess
import sys
from pathlib import Path


def get_resolve():
    try:
        import DaVinciResolveScript as bmd
    except ImportError:
        sys.path.insert(0, "/opt/resolve/Developer/Scripting/Modules")
        import DaVinciResolveScript as bmd
    return bmd.scriptapp("Resolve")


def show_message(fusion, title, text):
    try:
        fusion.UIManager
        fusion.RequestDir  # force API lookup; AskUser is on Fusion
        fusion.AskUser(title, {"msg": {"Name": text, "ReadOnly": True}})
    except Exception:
        print(f"{title}: {text}")


def choose_file(fusion):
    try:
        return fusion.RequestFile("Select video to import")
    except Exception:
        return None


def find_ingest():
    candidates = [
        shutil.which("resolve-ingest"),
        "/etc/profiles/per-user/mart/bin/resolve-ingest",
        str(Path.home() / ".nix-profile/bin/resolve-ingest"),
    ]
    for candidate in candidates:
        if candidate and os.path.isfile(candidate) and os.access(candidate, os.X_OK):
            return candidate
    raise RuntimeError("resolve-ingest was not found in PATH")


def main():
    resolve = get_resolve()
    if not resolve:
        raise RuntimeError("Could not access DaVinci Resolve scripting API")

    fusion = resolve.Fusion()
    if not fusion:
        raise RuntimeError("Could not access Fusion scripting API")

    source = choose_file(fusion)
    if not source:
        return
    source = os.path.abspath(os.path.expanduser(source))
    if not os.path.isfile(source):
        raise RuntimeError(f"Selected file does not exist: {source}")

    project = resolve.GetProjectManager().GetCurrentProject()
    if not project:
        raise RuntimeError("Open a Resolve project first")
    media_pool = project.GetMediaPool()
    if not media_pool:
        raise RuntimeError("Could not access Media Pool")

    cache_dir = Path.home() / ".cache" / "DaVinciResolve" / "resolve-ingest"
    cache_dir.mkdir(parents=True, exist_ok=True)
    stem = Path(source).stem
    output = cache_dir / f"{stem}_dnxhr.mov"

    env = os.environ.copy()
    env["RESOLVE_INGEST_DIR"] = str(cache_dir)
    ingest = find_ingest()

    print(f"Import Any Video: transcoding {source}")
    result = subprocess.run(
        [ingest, source],
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
    )
    print(result.stdout)
    if result.returncode != 0:
        raise RuntimeError(f"Transcode failed (exit {result.returncode}). See Console for ffmpeg output.")
    if not output.is_file():
        raise RuntimeError(f"Transcode finished but output was not found: {output}")

    imported = media_pool.ImportMedia([str(output)])
    if not imported:
        raise RuntimeError("Resolve refused to import the transcoded file")

    print(f"Import Any Video: imported {output}")
    show_message(fusion, "Import Any Video", f"Imported successfully:\n{output.name}")


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"Import Any Video ERROR: {exc}")
        try:
            r = get_resolve()
            f = r.Fusion() if r else None
            if f:
                show_message(f, "Import Any Video - Error", str(exc))
        except Exception:
            pass
        raise
