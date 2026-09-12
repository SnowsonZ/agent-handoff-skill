#!/usr/bin/env python3
"""Upgrade the global handoff skill and explicitly selected repository runtimes."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
from datetime import datetime, timezone

PROJECT = "snowsonz/agent-handoff-skill"
SKILL_NAME = "handoff-installer"
TRANSITIONAL_NAME = "handoff"
NAMES = (SKILL_NAME, TRANSITIONAL_NAME)
AGENTS = ("codex", "claude-code")
SKILLS_VERSION = "1.5.26"


class UpgradeError(RuntimeError):
    pass


def exists(path: Path) -> bool:
    return path.exists() or path.is_symlink()


def plain_ancestors(path: Path) -> None:
    for parent in (path, *path.parents):
        if parent.is_symlink():
            raise UpgradeError(f"Refusing to write through directory symlink: {parent}")
        if parent.exists() and not parent.is_dir():
            raise UpgradeError(f"Not a directory: {parent}")


def fingerprint(root: Path) -> str:
    digest = hashlib.sha256()
    for path in sorted(root.rglob("*")):
        if path.is_symlink():
            raise UpgradeError(f"Package contains a symlink: {path}")
        if path.is_file():
            digest.update(path.relative_to(root).as_posix().encode() + b"\0" + path.read_bytes() + b"\0")
    return digest.hexdigest()


def package_identity(root: Path, legacy: bool = False) -> bool:
    try:
        name = re.search(r"^name: (.+)$", (root / "SKILL.md").read_text(), re.M)
        accepted = NAMES if legacy else (SKILL_NAME,)
        payload = root / "assets/runtime/repo/agents"
        global_runtime = ((root / "PROTOCOL.md").is_file()
                          and (root / "scripts/migrate.py").is_file()
                          and (root / "scripts/setup.py").is_file())
        old_runtime = ((payload / "handoff/PROTOCOL.md").is_file()
                       or (payload / "skills/handoff/SKILL.md").is_file())
        return bool(name and name.group(1) in accepted
                    and re.fullmatch(r"\d+\.\d+\.\d+", (root / "VERSION").read_text().strip())
                    and (global_runtime or (legacy and old_runtime
                         and (root / "scripts/install.sh").is_file()
                         and (root / "assets/runtime/AGENTS.block.md").is_file())))
    except (OSError, UnicodeError):
        return False


def validate_package(root: Path) -> str:
    if not package_identity(root):
        raise UpgradeError(f"Not a complete new handoff package: {root}")
    for relative in ("assets/TEMPLATE.md", "scripts/ledger.sh", "scripts/setup.py", "scripts/migrate.py"):
        if not (root / relative).is_file():
            raise UpgradeError(f"Missing package file: {relative}")
    fingerprint(root)
    return (root / "VERSION").read_text().strip()


def registry_path(user: Path) -> Path:
    state = os.environ.get("XDG_STATE_HOME")
    if state and not Path(state).is_absolute():
        raise UpgradeError("XDG_STATE_HOME must be absolute")
    return Path(state) / "skills/.skill-lock.json" if state else user / ".agents/.skill-lock.json"


def read_registry(path: Path) -> dict:
    if path.is_symlink():
        raise UpgradeError(f"Installation registry is a symlink: {path}")
    if not path.exists():
        return {"version": 3, "skills": {}}
    data = json.loads(path.read_text())
    if not isinstance(data, dict) or not isinstance(data.get("skills"), dict) or data.get("version") != 3:
        raise UpgradeError(f"Unsupported skills registry: {path}")
    return data


def write_registry(path: Path, data: dict) -> None:
    plain_ancestors(path.parent)
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temp = tempfile.mkstemp(prefix=".handoff-registry-", dir=path.parent)
    try:
        with os.fdopen(fd, "w") as stream:
            json.dump(data, stream, ensure_ascii=False, indent=2)
            stream.write("\n")
        os.replace(temp, path)
    finally:
        if os.path.exists(temp):
            os.unlink(temp)


def owned(entry: dict | None, path: Path) -> bool:
    if entry:
        source = str(entry.get("source", "")).lower().removesuffix(".git")
        url = str(entry.get("sourceUrl", "")).lower().removesuffix(".git").rstrip("/")
        return (source == PROJECT or url == "https://github.com/" + PROJECT
                or entry.get("handoffProject") == PROJECT)
    return package_identity(path, legacy=True)


def remove(path: Path) -> None:
    if path.is_symlink() or path.is_file():
        path.unlink()
    elif path.exists():
        shutil.rmtree(path)


def agent_dirs(user: Path) -> tuple[Path, Path]:
    claude = Path(os.environ.get("CLAUDE_CONFIG_DIR", "").strip() or user / ".claude")
    codex = Path(os.environ.get("CODEX_HOME", "").strip() or user / ".codex")
    if not claude.is_absolute() or not codex.is_absolute():
        raise UpgradeError("CODEX_HOME and CLAUDE_CONFIG_DIR must be absolute when set")
    return claude / "skills", codex / "skills"


def global_paths(user: Path, names: tuple[str, ...] = (SKILL_NAME,)) -> list[Path]:
    return [directory / name for directory in (user / ".agents/skills", *agent_dirs(user)) for name in names]


class SkillsCLI:
    def __init__(self):
        self.command = ["npx", "--yes", f"skills@{SKILLS_VERSION}"]

    def run(self, *args: str, cwd: Path) -> None:
        env = dict(os.environ, DISABLE_TELEMETRY="1", DO_NOT_TRACK="1")
        result = subprocess.run([*self.command, *args], cwd=cwd, env=env, stdin=subprocess.DEVNULL,
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=180)
        if result.returncode:
            raise UpgradeError(f"skills {' '.join(args[:2])} failed:\n{result.stdout[-3000:]}")


def repo_state(migration: Path, repo: Path) -> str:
    result = subprocess.run([sys.executable, str(migration), "status", str(repo)], text=True,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=30)
    try:
        data = json.loads(result.stdout)
    except ValueError as exc:
        raise UpgradeError(f"Cannot inspect repository {repo}: {result.stdout.strip()}") from exc
    state = data.get("state")
    if result.returncode or state not in ("clean", "legacy", "interrupted"):
        raise UpgradeError(f"Repository {repo}: {data.get('reason', state)}; resolve it before upgrading")
    return state


def upgrade_repos(migration: Path, repos: list[Path]) -> None:
    for repo in repos:
        state = repo_state(migration, repo)
        if state != "clean":
            result = subprocess.run([sys.executable, str(migration), "migrate", str(repo)], text=True,
                                    stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=120)
            if result.returncode:
                raise UpgradeError(f"Global skill is upgraded; repository {repo} needs attention. "
                                   f"Rerun with the same --repo to resume.\n{result.stdout.strip()}")
        if repo_state(migration, repo) != "clean":
            raise UpgradeError(f"Repository cleanup did not finish: {repo}")
        print(f"Repository uses global runtime: {repo}")


def upgrade(source: Path, repos: list[Path], copy_to: Path | None, replace_conflict: bool,
            *, user: Path | None = None, cli=None) -> str:
    user = user or Path.home()
    cli = cli or SkillsCLI()
    source = source.expanduser().resolve()
    repos = list(dict.fromkeys(p.expanduser().resolve() for p in repos))
    copy_to = copy_to.expanduser().absolute() if copy_to else None
    version = validate_package(source)
    source_hash = fingerprint(source)
    paths = global_paths(user)
    canonical = user / ".agents/skills" / SKILL_NAME
    registry = registry_path(user)
    for parent in {p.parent for p in paths} | {registry.parent}:
        plain_ancestors(parent)
    plain_ancestors(user / ".agents")
    (user / ".agents").mkdir(parents=True, exist_ok=True)
    guard = user / ".agents/.handoff-upgrade-running"
    try:
        guard.mkdir()
    except FileExistsError as exc:
        raise UpgradeError(f"Another upgrade may be running: {guard}. Check before removing this guard.") from exc
    work = None
    preserve_backup = False
    try:
        original_registry = read_registry(registry)
        entries = original_registry["skills"]
        transitional = user / ".agents/skills" / TRANSITIONAL_NAME
        # Only undo this project's unpublished rename; leave unrelated handoff skills alone.
        transitional_entry = entries.get(TRANSITIONAL_NAME)
        owned_transitional = bool(transitional_entry) and owned(transitional_entry, transitional)
        names = NAMES if owned_transitional else (SKILL_NAME,)
        installed_paths = global_paths(user, names)
        paths = list(installed_paths)
        for name in names:
            path = user / ".agents/skills" / name
            entry = entries.get(name)
            if exists(path) or entry:
                if not owned(entry, path) and not (name == SKILL_NAME and replace_conflict):
                    raise UpgradeError(f"Unrelated or unregistered skill {name}; obtain approval before "
                                       f"using --replace-conflict for {SKILL_NAME}")
                if path.is_symlink():
                    raise UpgradeError(f"Canonical skill is a symlink: {path}")
                if path.is_dir() and package_identity(path, legacy=True):
                    installed_version = (path / "VERSION").read_text().strip()
                    if tuple(map(int, installed_version.split("."))) > tuple(map(int, version.split("."))):
                        raise UpgradeError(f"Refusing to downgrade {path} from {installed_version} to {version}")
                recorded = (entry or {}).get("handoffContentHash")
                if recorded and path.exists() and fingerprint(path) != recorded:
                    raise UpgradeError(f"Installed skill has local modifications: {path}")
            for parent in agent_dirs(user):
                link = parent / name
                if link.is_symlink():
                    if link.resolve() != path.resolve():
                        raise UpgradeError(f"Unrelated discovery link: {link}")
                elif exists(link):
                    if not path.is_dir() or fingerprint(link) != fingerprint(path):
                        raise UpgradeError(f"Independent or locally modified agent skill: {link}")
        copy_names = (SKILL_NAME,)
        if copy_to:
            plain_ancestors(copy_to)
            copy_to = copy_to.resolve()
            old_copy = copy_to / TRANSITIONAL_NAME
            if (not old_copy.is_symlink() and package_identity(old_copy, legacy=True)
                    and owned_transitional):
                copy_names = NAMES
            for name in copy_names:
                path = copy_to / name
                if path.is_symlink() or (path.exists() and not package_identity(path, legacy=True)):
                    raise UpgradeError(f"Unrelated retained copy: {path}")
            if any(copy_to == p.parent or copy_to in p.parents or p in copy_to.parents for p in paths):
                raise UpgradeError("--copy-to must be separate from skill installation directories")
            paths.extend(copy_to / name for name in copy_names)
        if any(source == p or source in p.parents or p in source.parents for p in paths + repos):
            raise UpgradeError("Source must not overlap installation paths, retained copies, or target repositories")
        if copy_to and (copy_to == source or copy_to in source.parents or source in copy_to.parents):
            raise UpgradeError("Source must not overlap --copy-to")
        for repo in repos:
            if any(repo == p or repo in p.parents or p in repo.parents for p in paths):
                raise UpgradeError(f"Repository overlaps global skills or retained copies: {repo}")
            repo_state(source / "scripts/migrate.py", repo)
        work = Path(tempfile.mkdtemp(prefix="handoff-upgrade-"))
        stage = work / SKILL_NAME
        shutil.copytree(source, stage)
        validate_package(stage)
        wanted = fingerprint(stage)
        if wanted != source_hash:
            raise UpgradeError("Source package changed during preparation; retry with a stable package")
        claude_link = agent_dirs(user)[0] / SKILL_NAME
        codex_extra = agent_dirs(user)[1] / SKILL_NAME
        same = ((codex_extra in (canonical, claude_link) or not exists(codex_extra))
                and canonical.is_dir() and fingerprint(canonical) == wanted
                and claude_link.is_symlink() and claude_link.resolve() == canonical
                and (entries.get(SKILL_NAME) or {}).get("handoffContentHash") == wanted
                and all(not entries.get(name) for name in names if name != SKILL_NAME)
                and all(not exists(p) for p in paths if p.name == TRANSITIONAL_NAME)
                and (not copy_to or ((copy_to / SKILL_NAME).is_dir() and fingerprint(copy_to / SKILL_NAME) == wanted)))
        if not same:
            # Obtain the package manager before uninstalling anything.
            cli.run("--version", cwd=work)
            backups = {}
            for index, path in enumerate(paths):
                if exists(path):
                    saved = work / f"backup-{index}"
                    if path.is_symlink():
                        saved.symlink_to(os.readlink(path))
                    else:
                        shutil.copytree(path, saved, symlinks=True)
                    backups[path] = saved
            (work / "backup-manifest.json").write_text(json.dumps({
                "paths": {str(path): str(saved) for path, saved in backups.items()},
                "registry": str(registry), "entries": {name: entries.get(name) for name in names},
            }, indent=2) + "\n")
            try:
                for name in names:
                    if entries.get(name) or any(exists(p) for p in installed_paths if p.name == name):
                        cli.run("remove", name, "-g", "-a", *AGENTS, "-y", cwd=work)
                # skills may retain the shared canonical directory for other universal agents.
                # Cleanup is limited to the paths whose ownership was checked above.
                for path in installed_paths:
                    remove(path)
                cli.run("add", str(stage), "-g", "--skill", SKILL_NAME, "-a", *AGENTS, "-y", cwd=work)
                if not canonical.is_dir() or fingerprint(canonical) != wanted:
                    raise UpgradeError("Installed package does not match the staged package")
                if not claude_link.is_symlink() or claude_link.resolve() != canonical:
                    raise UpgradeError("Claude discovery link was not installed correctly")
                if codex_extra not in (canonical, claude_link) and exists(codex_extra):
                    raise UpgradeError("Unexpected duplicate Codex skill after installation")
                if any(exists(path) for path in installed_paths if path.name == TRANSITIONAL_NAME):
                    raise UpgradeError("Legacy global skill entries remain after installation")
                if copy_to:
                    copy_to.mkdir(parents=True, exist_ok=True)
                    for name in copy_names:
                        remove(copy_to / name)
                    shutil.copytree(stage, copy_to / SKILL_NAME)
                # skills 1.5.26 does not register global additions from local sources.
                # Merge only the names owned by this project; preserve unrelated registrations.
                data = read_registry(registry)
                for name in names:
                    if name != SKILL_NAME:
                        data["skills"].pop(name, None)
                now = datetime.now(timezone.utc).isoformat()
                data["skills"][SKILL_NAME] = {
                    "source": str(source), "sourceType": "local", "sourceUrl": str(source),
                    "skillPath": "SKILL.md", "skillFolderHash": "", "installedAt": now, "updatedAt": now,
                    "handoffProject": PROJECT, "handoffContentHash": wanted, "handoffVersion": version,
                }
                write_registry(registry, data)
            except BaseException:
                try:
                    for path in paths:
                        remove(path)
                        if path in backups:
                            path.parent.mkdir(parents=True, exist_ok=True)
                            saved = backups[path]
                            if saved.is_symlink():
                                path.symlink_to(os.readlink(saved))
                            else:
                                shutil.copytree(saved, path, symlinks=True)
                    restored = read_registry(registry)
                    for name in names:
                        restored["skills"].pop(name, None)
                        if name in entries:
                            restored["skills"][name] = entries[name]
                    write_registry(registry, restored)
                except BaseException as rollback_error:
                    preserve_backup = True
                    raise UpgradeError(f"Rollback needs manual recovery; backup preserved at {work}: {rollback_error}")
                raise
        print(f"Global {SKILL_NAME} {version}: {'already current' if same else 'upgraded'}")
        upgrade_repos(stage / "scripts/migrate.py", repos)
        return version
    finally:
        if work is not None and not preserve_backup:
            shutil.rmtree(work)
        guard.rmdir()


def default_source() -> Path:
    root = Path(__file__).resolve().parents[1]
    for candidate in (root / "plugins/agent-handoff/skills/handoff-installer", root / "skills/handoff-installer"):
        if candidate.is_dir():
            return candidate
    raise UpgradeError("Use --source to select a downloaded handoff package")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, help="Downloaded new handoff skill directory")
    parser.add_argument("--repo", action="append", type=Path, default=[], help="Explicit old repository to migrate to the global runtime; repeatable")
    parser.add_argument("--copy-to", type=Path, help="Retained skill parent directory")
    parser.add_argument("--replace-conflict", action="store_true", help="Explicit consent to replace an unrelated global handoff-installer")
    args = parser.parse_args()
    try:
        upgrade(args.source or default_source(), args.repo, args.copy_to, args.replace_conflict)
    except (UpgradeError, OSError, ValueError, subprocess.SubprocessError) as exc:
        print(f"Upgrade stopped: {exc}", file=sys.stderr)
        return 1
    print("Upgrade verified. Start a new client session if it still shows the old skill name.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
