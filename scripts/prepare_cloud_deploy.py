#!/usr/bin/env python3
"""Prepare (never deploy) a minimal Serverpod Cloud workspace.

Only allowlisted runtime files are read (tracked or new and non-ignored). No
runtime configs, passwords, inbox attachments or client files are scanned.
Run pub get locally afterwards; Cloud
CLI 1.0.1 filters unused development lock entries when creating its ZIP.
"""

import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import stat
import subprocess
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request


DART_SDK = "3.13.5"
SERVERPOD_VERSION = "4.0.3"
STAGE_PATH = Path(".tooling/cloud-deploy")
MANIFEST = ".deploy-manifest.json"
SQLITE_VERSION = "3.7.0"
SQLITE_FILENAME = "libsqlite3.x64.linux.so"
SQLITE_SHA256 = "0f947ebe629e8d9d02d7f408bef36e056bfc63ea47e02e0d45a7bae454f04ace"
SQLITE_SIZE = 1788664
SQLITE_URL = ("https://github.com/simolus3/sqlite3.dart/releases/download/"
              "sqlite3-3.7.0/" + SQLITE_FILENAME)
SQLITE_DIRECTORY = "native/sqlite3"
SQLITE_PATH = SQLITE_DIRECTORY + "/" + SQLITE_FILENAME
SQLITE_CACHE = Path(".tooling/cloud-asset-cache/sqlite3-3.7.0") / SQLITE_FILENAME
ASSET_PACKAGE = "closecall_deploy_sqlite3_asset"
FETCH_TIMEOUT = 30
FETCH_DEADLINE = 60
SQLITE_HOOKS = """hooks:
  user_defines:
    sqlite3:
      source:
        linux: test-sqlite3
        default: sqlite3
      directory: native/sqlite3/
"""
ASSET_PUBSPEC = """name: closecall_deploy_sqlite3_asset
description: Verified deployment-only SQLite native asset; no Dart implementation.
publish_to: none
environment:
  sdk: ^3.12.2
resolution: workspace
"""
SQLITE_NOTICES = """SQLite native library
---------------------
This is the upstream SQLite binary, not SQLite3MultipleCiphers or SQLCipher.
SQLite is in the public domain: https://sqlite.org/copyright.html
Release source: https://github.com/simolus3/sqlite3.dart/releases/tag/sqlite3-3.7.0
The sqlite3 Dart package's hook documentation identifies this build as upstream
SQLite and documents its public-domain status:
https://github.com/simolus3/sqlite3.dart/blob/sqlite3-3.7.0/sqlite3/doc/hook.md

sqlite3 Dart library attribution (MIT)
------------------------------------
Source: https://pub.dev/packages/sqlite3/versions/3.7.0/license

MIT License

Copyright (c) 2020 Simon Binder

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
"""
SCLOUD_CONFIG = """# Public project link only. Never add credentials or generation hooks here.
project:
  projectId: closecall
  dartSdk: 3.13.5
  scripts:
    pre_deploy: []
    post_deploy: []
"""
ROOT_PUBSPEC = """name: closecall_cloud_deploy
publish_to: none
environment:
  sdk: ^3.12.2
workspace:
  - closecall_server
  - closecall_shared
  - native/sqlite3
"""
MIGRATION_FILES = {
    "definition.json", "definition_project.json", "definition.sql",
    "migration.json", "migration.sql",
}
REQUIRED = {
    "closecall_server/bin/main.dart", "closecall_server/lib/server.dart",
    "closecall_server/lib/src/generated/protocol.dart",
    "closecall_server/lib/src/generated/protocol.yaml",
    "closecall_server/lib/src/generated/serverpod.dart",
    "closecall_server/pubspec.yaml", "closecall_server/pubspec.lock",
    "closecall_shared/pubspec.yaml",
    "closecall_server/migrations/migration_registry.txt",
}


def allowed_runtime_path(value):
    """Positive allowlist; filename checks happen before opening any file."""
    path = PurePosixPath(value)
    parts = path.parts
    if not parts or path.is_absolute() or any(p in (".", "..") for p in parts):
        return False
    if not re.fullmatch(r"[A-Za-z0-9_./-]+", value):
        return False
    if any(p.startswith(".") for p in parts):
        return False
    if any(re.search(r"secret|password|firebase|credential|private", p, re.I)
           for p in parts):
        return False
    if value in REQUIRED or value == "closecall_shared/pubspec.lock":
        return True
    if len(parts) >= 3 and parts[:2] in (
            ("closecall_server", "lib"), ("closecall_shared", "lib")):
        return path.suffix == ".dart"
    return (len(parts) == 4 and parts[:2] == ("closecall_server", "migrations")
            and re.fullmatch(r"[0-9]{17}", parts[2]) is not None
            and parts[3] in MIGRATION_FILES)


def read_regular(root, relative):
    """Reject file and ancestor symlinks before reading their targets."""
    path = root
    for component in PurePosixPath(relative).parts:
        path /= component
        if path.is_symlink():
            raise ValueError(f"Symlinks are not deployable: {relative}")
    if not path.is_file():
        raise ValueError(f"Missing runtime file: {relative}")
    return path.read_bytes()


def runtime_pubspec(content, package):
    """Transform only conventional pubspec top-level blocks, fail on drift."""
    if re.search(r"^(workspace|resolution|dependency_overrides):", content, re.M):
        raise ValueError(f"Review new workspace/override configuration: {package}")
    if not re.search(rf"^name: {package}$", content, re.M):
        raise ValueError(f"Unexpected package name: {package}")
    if re.search(r"\bflutter\b", content):
        raise ValueError(f"Flutter is not supported in the deployment: {package}")
    content = re.sub(r"^dev_dependencies:[\s\S]*?(?=^[A-Za-z_]|\Z)",
                     "", content, flags=re.M)
    if package == "closecall_server":
        if not re.search(r"^  serverpod: 4\.0\.3$", content, re.M):
            raise ValueError("The deployment requires Serverpod 4.0.3")
        if "  closecall_shared:\n    path: ../closecall_shared\n" not in content:
            raise ValueError("Review changed relative shared-package dependency")
    return content.rstrip() + "\nresolution: workspace\n"


def workspace_lock(content):
    # Workspace members do not appear in the workspace lockfile. Keep all other
    # proven versions/hashes byte-for-byte; pub get/CLI prunes dev-only packages.
    if not content.startswith("# Generated by pub\n") or "\npackages:\n" not in content:
        raise ValueError("Unsupported pub lockfile format")
    content, count = re.subn(
        r"^  closecall_shared:\n(?:    .*\n)+", "", content, flags=re.M)
    if count != 1:
        raise ValueError("Expected exactly one shared path dependency in lockfile")
    return content


def locked_packages(content):
    """Extract canonical pub package blocks for version/hash preservation checks."""
    return dict(re.findall(r"^  ([a-zA-Z0-9_]+):\n((?:    .*\n)+)",
                           content, re.M))


def require_sqlite_lock(content):
    block = locked_packages(content).get("sqlite3", "")
    if (not re.search(r'^    version: "3\.7\.0"$', block, re.M)
            or not re.search(r'^    source: hosted$', block, re.M)
            or not re.search(r'^      name: sqlite3$', block, re.M)
            or not re.search(r'^      url: "https://pub\.dev"$', block, re.M)):
        raise ValueError("SQLite asset bundling requires locked hosted sqlite3 exactly 3.7.0")


def verify_sqlite_asset(data):
    if len(data) != SQLITE_SIZE:
        raise ValueError("SQLite asset byte count mismatch")
    if hashlib.sha256(data).hexdigest() != SQLITE_SHA256:
        raise ValueError("SQLite asset SHA256 mismatch; refusing unverified bytes")
    if (data[:7] != b"\x7fELF\x02\x01\x01"
            or int.from_bytes(data[16:18], "little") != 3
            or int.from_bytes(data[18:20], "little") != 62
            or int.from_bytes(data[20:24], "little") != 1
            or int.from_bytes(data[52:54], "little") != 64):
        raise ValueError("SQLite asset is not an ELF64 little-endian x86-64 shared library")
    return data


def bounded_asset_read(stream, deadline=None):
    data = bytearray()
    while len(data) <= SQLITE_SIZE:
        if deadline is not None and time.monotonic() > deadline:
            raise ValueError("SQLite asset download deadline exceeded")
        # HTTPResponse.read1 avoids an unbounded internal read loop for a slow
        # response; each socket read also has FETCH_TIMEOUT applied.
        reader = getattr(stream, "read1", stream.read)
        chunk = reader(min(65536, SQLITE_SIZE + 1 - len(data)))
        if not chunk:
            break
        data.extend(chunk)
    return verify_sqlite_asset(bytes(data))


def validate_asset_url(url):
    parsed = urllib.parse.urlsplit(url)
    if (parsed.scheme != "https" or parsed.hostname not in {
            "github.com", "release-assets.githubusercontent.com", "objects.githubusercontent.com"}
            or parsed.username or parsed.password or parsed.port not in (None, 443)):
        raise ValueError("Refusing non-official HTTPS SQLite asset redirect")


class OfficialAssetRedirects(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, request, fp, code, message, headers, newurl):
        validate_asset_url(newurl)
        return super().redirect_request(request, fp, code, message, headers, newurl)


def download_sqlite_asset():
    request = urllib.request.Request(SQLITE_URL, headers={
        "User-Agent": "CloseCall-deploy-preparation",
        "Accept": "application/octet-stream",
        "Accept-Encoding": "identity",
    })
    opener = urllib.request.build_opener(OfficialAssetRedirects())
    deadline = time.monotonic() + FETCH_DEADLINE
    try:
        with opener.open(request, timeout=FETCH_TIMEOUT) as response:
            validate_asset_url(response.geturl())
            if response.status != 200:
                raise ValueError("SQLite asset download did not return HTTP 200")
            length = response.headers.get("Content-Length")
            if length is not None and length != str(SQLITE_SIZE):
                raise ValueError("SQLite asset Content-Length mismatch")
            if response.headers.get("Content-Encoding", "identity") != "identity":
                raise ValueError("SQLite asset response must be unencoded bytes")
            return bounded_asset_read(response, deadline)
    except (urllib.error.URLError, OSError) as error:
        # Never log a redirect's signed URL or response body.
        raise ValueError("SQLite asset download failed; no asset was cached") from error


def verified_sqlite_asset(root):
    """Download once to ignored cache; verify EVERY use, fail closed on damage."""
    root = Path(root)
    directory = root
    for part in SQLITE_CACHE.parent.parts:
        directory /= part
        if directory.is_symlink():
            raise ValueError("Refusing symlinked SQLite asset cache")
        directory.mkdir(exist_ok=True)
        if not directory.is_dir():
            raise ValueError("SQLite asset cache parent is not a directory")
    cached = root / SQLITE_CACHE
    if cached.is_symlink():
        raise ValueError("Refusing symlinked SQLite asset cache")
    if cached.exists():
        descriptor = os.open(cached, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
        with os.fdopen(descriptor, "rb") as stream:
            info = os.fstat(stream.fileno())
            if not stat.S_ISREG(info.st_mode) or info.st_size != SQLITE_SIZE:
                raise ValueError("SQLite cached asset is not a regular file of the pinned size")
            return bounded_asset_read(stream)
    data = verify_sqlite_asset(download_sqlite_asset())
    descriptor, scratch = tempfile.mkstemp(prefix="sqlite3-verified-", dir=directory)
    try:
        with os.fdopen(descriptor, "wb") as stream:
            stream.write(data)
        os.replace(scratch, cached)
    finally:
        if os.path.exists(scratch):
            os.unlink(scratch)
    return data


def verify_resolved_lock(original, resolved):
    """Resolution may prune/demote dependencies, never change pinned artifacts."""
    before, after = locked_packages(original), locked_packages(resolved)
    for package, block in after.items():
        if package not in before:
            raise ValueError(f"Resolution introduced an unpinned dependency: {package}")
        normalize = lambda text: re.sub(r"^    dependency: .*\n", "", text, flags=re.M)
        if normalize(block) != normalize(before[package]):
            raise ValueError(f"Resolution changed a pinned dependency: {package}")
    if not after or 'version: "4.0.3"' not in after.get("serverpod", ""):
        raise ValueError("Missing pinned Serverpod dependency after resolution")
    require_sqlite_lock(resolved)


def cloud_ignore(files):
    """Exact file allowlist, including parents needed by gitignore semantics."""
    paths = set(files) | {".scloud/scloud_server_dir"}
    directories = set()
    for value in paths:
        for parent in PurePosixPath(value).parents:
            if str(parent) != ".":
                directories.add(str(parent) + "/")
    return ("# Generated allowlist. Cloud configs are injected; none are copied.\n"
            "**\n" + "".join("!" + p + "\n" for p in sorted(directories))
            + "".join("!" + p + "\n" for p in sorted(paths)))


def prepare(root, replace=False):
    root = Path(root).resolve()
    target = root / STAGE_PATH
    if (root / ".tooling").is_symlink() or target.is_symlink():
        raise ValueError("Refusing symlinked staging directories")
    if target.exists():
        if not replace:
            raise ValueError(f"Stage exists: {STAGE_PATH}; use --replace to rebuild it")
        marker = read_regular(target, MANIFEST)
        if json.loads(marker).get("format") != "closecall-cloud-deploy-v1":
            raise ValueError("Refusing to replace an unowned staging directory")

    # Git provides names only (including new, non-ignored runtime sources).
    # Ignored untracked files are not discovered; names outside the allowlist
    # are not read, even if they were accidentally added to the index.
    tracked = subprocess.check_output(
        ["git", "ls-files", "--cached", "--others", "--exclude-standard", "-z",
         "--", "closecall_server", "closecall_shared"],
        cwd=root).decode().split("\0")
    selected = sorted(set(p for p in tracked if allowed_runtime_path(p)))
    missing = REQUIRED - set(selected)
    if missing:
        raise ValueError("Missing runtime files: " + ", ".join(sorted(missing)))
    if not any(p.startswith("closecall_shared/lib/") for p in selected):
        raise ValueError("No shared Dart library files")
    files = {p: read_regular(root, p) for p in selected}
    source_hashes = {p: hashlib.sha256(data).hexdigest() for p, data in files.items()}
    # Cloud replaces production configuration. Do not copy even public local
    # configs, especially passwords.yaml or private service-account credentials.
    for package in ("closecall_server", "closecall_shared"):
        key = package + "/pubspec.yaml"
        files[key] = runtime_pubspec(files[key].decode(), package).encode()
    files["pubspec.lock"] = workspace_lock(
        files.pop("closecall_server/pubspec.lock").decode()).encode()
    # Guard the pin before configuring the hook or touching the asset cache.
    require_sqlite_lock(files["pubspec.lock"].decode())
    files.pop("closecall_shared/pubspec.lock", None)
    server_pubspec = files["closecall_server/pubspec.yaml"].decode()
    if re.search(r"^hooks:|closecall_deploy_sqlite3_asset", server_pubspec, re.M):
        raise ValueError("Review conflicting deployment-only hook/asset configuration")
    # Cloud CLI only archives reachable workspace members. This generated
    # resource package gets the root-level native/ directory into that set,
    # without patching sqlite3 or changing any existing hosted lock entry.
    server_pubspec = server_pubspec.replace(
        "dependencies:\n", "dependencies:\n  " + ASSET_PACKAGE + ":\n"
        "    path: ../native/sqlite3\n", 1)
    files["closecall_server/pubspec.yaml"] = server_pubspec.encode()
    files["pubspec.yaml"] = (ROOT_PUBSPEC + SQLITE_HOOKS).encode()
    # Use a known credential-free configuration, not arbitrary local CLI hooks.
    config = read_regular(root, "closecall_server/scloud.yaml")
    if config != SCLOUD_CONFIG.encode():
        raise ValueError("Review changed scloud.yaml before preparing deployment")
    files["closecall_server/scloud.yaml"] = config
    files[SQLITE_PATH] = verified_sqlite_asset(root)
    files[SQLITE_DIRECTORY + "/pubspec.yaml"] = ASSET_PUBSPEC.encode()
    notice_path = SQLITE_DIRECTORY + "/THIRD_PARTY_NOTICES.txt"
    files[notice_path] = SQLITE_NOTICES.encode()
    asset_metadata = {
        "package": "sqlite3", "packageVersion": SQLITE_VERSION,
        "path": SQLITE_PATH, "sourceUrl": SQLITE_URL,
        "sha256": SQLITE_SHA256, "sizeBytes": SQLITE_SIZE,
        "target": "linux-x64", "noticePath": notice_path,
        "licenses": {"nativeSQLite": "public domain", "sqlite3DartLibrary": "MIT"},
        "licenseSources": ["https://sqlite.org/copyright.html",
                           "https://pub.dev/packages/sqlite3/versions/3.7.0/license"],
    }
    metadata_path = SQLITE_DIRECTORY + "/asset.json"
    files[metadata_path] = (json.dumps(asset_metadata, indent=2, sort_keys=True) + "\n").encode()
    files[".scloudignore"] = cloud_ignore(files).encode()
    manifest = {
        "format": "closecall-cloud-deploy-v1",
        "dartSdk": DART_SDK,
        "serverpod": SERVERPOD_VERSION,
        "nativeAssets": [{**asset_metadata, "metadataPath": metadata_path}],
        "sourceSha256": source_hashes,
        "stagedSha256BeforePubGet": {p: hashlib.sha256(data).hexdigest()
                         for p, data in sorted(files.items())},
    }
    files[MANIFEST] = (json.dumps(manifest, indent=2, sort_keys=True) + "\n").encode()
    target.parent.mkdir(parents=True, exist_ok=True)
    scratch = Path(tempfile.mkdtemp(prefix="cloud-deploy-preparing-", dir=target.parent))
    try:
        for relative, data in sorted(files.items()):
            destination = scratch / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(data)
        if target.exists():
            # --replace is limited to this exact, ownership-marked generated stage.
            shutil.rmtree(target)
        scratch.rename(target)
    finally:
        if scratch.exists():
            shutil.rmtree(scratch)
    return target, len(files)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--replace", action="store_true",
                        help="Rebuild only the ownership-marked generated stage")
    args = parser.parse_args()
    try:
        target, count = prepare(Path(__file__).resolve().parents[1], args.replace)
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        parser.exit(1, f"Preparation failed: {error}\n")
    print(f"Prepared {count} files at {target}")
    print("No deployment, generation, provisioning or Cloud secret changes performed.")
    print("Next: run Dart 3.13.5 pub get --offline in the staged workspace.")
    print("Then review: scloud deploy --wet-run --output <local ZIP path> "
          "--project-dir .tooling/cloud-deploy/closecall_server")


if __name__ == "__main__":
    main()
