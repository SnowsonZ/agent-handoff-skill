#!/bin/sh
# Install or inspect the repository-local handoff protocol.
set -eu

ROOT=$(cd "$(dirname "$0")/.." && pwd)
VERSION=$(tr -d '\r\n' < "$ROOT/VERSION")
AGENTS_SOURCE=$ROOT/assets/runtime/AGENTS.block.md
SKILL_SOURCE=$ROOT/assets/runtime/repo/agents/skills/handoff/SKILL.md
TEMPLATE_SOURCE=$ROOT/assets/runtime/repo/agents/tasks/TEMPLATE.md
IMPORT_SOURCE=$ROOT/assets/runtime/repo/CLIENT_IMPORT
LEDGER_SOURCE=$ROOT/scripts/ledger.sh
BEGIN='<!-- handoff:begin -->'
END='<!-- handoff:end -->'

MODE=${1:-status}
case "$MODE" in
  status|install|update|adopt-existing) ;;
  *)
    printf 'usage: install.sh <status|install|update|adopt-existing> [target-repo]\n' >&2
    exit 2
    ;;
esac

TARGET=${2:-$(pwd)}
[ -d "$TARGET" ] || {
  printf 'target is not a directory: %s\n' "$TARGET" >&2
  exit 1
}
TARGET=$(cd "$TARGET" && pwd)
git -C "$TARGET" rev-parse --git-dir >/dev/null 2>&1 || {
  printf 'target is not a git repository: %s\n' "$TARGET" >&2
  exit 1
}

LOCK=$TARGET/.agents/handoff.lock
TRANSACTION=$TARGET/.agents/handoff.transaction
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

validate_payload_sources() {
  for _source in \
    "$ROOT/VERSION" \
    "$AGENTS_SOURCE" \
    "$SKILL_SOURCE" \
    "$TEMPLATE_SOURCE" \
    "$IMPORT_SOURCE" \
    "$LEDGER_SOURCE"
  do
    if [ ! -f "$_source" ]; then
      printf 'installer package incomplete: missing %s\n' "${_source#"$ROOT"/}" >&2
      return 1
    fi
  done
  if ! valid_version "$VERSION"; then
    printf 'installer package has an invalid version: %s\n' "$VERSION" >&2
    return 1
  fi
}

valid_version() {
  printf '%s\n' "$1" | awk '
    /^[0-9]+\.[0-9]+\.[0-9]+$/ { valid=1 }
    END { exit !valid }
  '
}

compare_versions() {
  # Prints -1 when the first version is older, 0 when equal, and 1 when newer.
  awk -F . -v left="$1" -v right="$2" '
    BEGIN {
      split(left, l, "."); split(right, r, ".")
      for (i = 1; i <= 3; i++) {
        if ((l[i] + 0) < (r[i] + 0)) { print -1; exit }
        if ((l[i] + 0) > (r[i] + 0)) { print 1; exit }
      }
      print 0
    }
  '
}

sha256_stream() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum | awk '{print $1}'
  else
    printf 'no SHA-256 command available\n' >&2
    exit 1
  fi
}

hash_file() {
  if [ -f "$1" ]; then
    sha256_stream < "$1"
  else
    printf 'missing\n'
  fi
}

hash_text() {
  printf '%s' "$1" | sha256_stream
}

hash_agents_block() {
  _file=$1
  if [ ! -f "$_file" ] || ! grep -qF "$BEGIN" "$_file"; then
    printf 'missing\n'
    return
  fi
  awk -v b="$BEGIN" -v e="$END" '$0==b{f=1} f{print} $0==e{exit}' "$_file" | sha256_stream
}

hash_import() {
  if [ -f "$1" ] && [ "$(head -1 "$1")" = "$(tr -d '\r\n' < "$IMPORT_SOURCE")" ]; then
    head -1 "$1" | sha256_stream
  else
    printf 'missing\n'
  fi
}

hash_skill_link() {
  if [ -L "$1" ]; then
    hash_text "$(readlink "$1")"
  else
    printf 'missing\n'
  fi
}

current_object_hash() {
  _kind=$1
  _id=$2
  case "$_kind:$_id" in
    file:*) hash_file "$TARGET/$_id" ;;
    fragment:AGENTS.md#handoff) hash_agents_block "$TARGET/AGENTS.md" ;;
    fragment:CLAUDE.md#handoff) hash_import "$TARGET/CLAUDE.md" ;;
    fragment:.claude/skills/handoff#target) hash_skill_link "$TARGET/.claude/skills/handoff" ;;
    *) printf 'unknown transaction object: %s %s\n' "$_kind" "$_id" >&2; return 1 ;;
  esac
}

new_object_hash() {
  _kind=$1
  _id=$2
  case "$_kind:$_id" in
    file:.agents/skills/handoff/SKILL.md) hash_file "$SKILL_SOURCE" ;;
    file:.agents/tasks/TEMPLATE.md) hash_file "$TEMPLATE_SOURCE" ;;
    file:tools/ledger.sh) hash_file "$LEDGER_SOURCE" ;;
    fragment:AGENTS.md#handoff) hash_file "$AGENTS_SOURCE" ;;
    fragment:CLAUDE.md#handoff) head -1 "$IMPORT_SOURCE" | sha256_stream ;;
    fragment:.claude/skills/handoff#target) hash_text '../../.agents/skills/handoff' ;;
    *) printf 'unknown transaction object: %s %s\n' "$_kind" "$_id" >&2; return 1 ;;
  esac
}

transaction_objects() {
  printf '%s\t%s\n' \
    file .agents/skills/handoff/SKILL.md \
    file .agents/tasks/TEMPLATE.md \
    file tools/ledger.sh \
    fragment AGENTS.md#handoff \
    fragment CLAUDE.md#handoff \
    fragment .claude/skills/handoff#target
}

valid_stored_hash() {
  case "$1" in
    missing) return 0 ;;
  esac
  printf '%s\n' "$1" | grep -Eq '^[0-9a-f]{64}$'
}

valid_new_hash() {
  printf '%s\n' "$1" | grep -Eq '^[0-9a-f]{64}$'
}

is_transaction_object() {
  transaction_objects | awk -F '\t' -v kind="$1" -v id="$2" '
    $1 == kind && $2 == id { found=1 }
    END { exit !found }
  '
}

validate_transaction_shape() {
  [ -s "$TRANSACTION" ] || {
    printf 'invalid transaction: no records\n' >&2
    return 1
  }
  _tab=$(printf '\t')
  : > "$WORK/transaction-objects"
  _count=0
  while IFS="$_tab" read -r _kind _id _old _new _extra
  do
    _count=$((_count + 1))
    if [ -z "$_kind" ] || [ -z "$_id" ] || [ -z "$_old" ] || [ -z "$_new" ] || [ -n "$_extra" ] || \
       ! is_transaction_object "$_kind" "$_id" || ! valid_stored_hash "$_old" || ! valid_new_hash "$_new"; then
      printf 'invalid transaction record: %s\n' "$_id" >&2
      return 1
    fi
    printf '%s\t%s\n' "$_kind" "$_id" >> "$WORK/transaction-objects"
  done < "$TRANSACTION"
  if [ "$_count" -ne 6 ] || [ "$(sort "$WORK/transaction-objects" | uniq | wc -l | tr -d ' ')" -ne 6 ]; then
    printf 'invalid transaction: expected six unique managed objects\n' >&2
    return 1
  fi
  transaction_objects | while IFS="$_tab" read -r _kind _id
  do
    if ! grep -q "^$_kind$_tab$_id$" "$WORK/transaction-objects"; then
      printf 'invalid transaction: missing managed object %s\n' "$_id" >&2
      return 1
    fi
  done
}

write_transaction() {
  mkdir -p "$TARGET/.agents"
  : > "$WORK/transaction"
  transaction_objects | while IFS="$(printf '\t')" read -r _kind _id
  do
    _old=$(current_object_hash "$_kind" "$_id")
    _new=$(new_object_hash "$_kind" "$_id")
    printf '%s\t%s\t%s\t%s\n' "$_kind" "$_id" "$_old" "$_new" >> "$WORK/transaction"
  done
  mv "$WORK/transaction" "$TRANSACTION"
}

validate_transaction() {
  validate_transaction_shape || return 1
  _tab=$(printf '\t')
  while IFS="$_tab" read -r _kind _id _old _new
  do
    [ -n "$_kind" ] || continue
    _actual=$(current_object_hash "$_kind" "$_id") || return 1
    if [ "$_actual" != "$_old" ] && [ "$_actual" != "$_new" ]; then
      printf 'transaction conflict: %s has content outside old/new hashes\n' "$_id" >&2
      return 1
    fi
  done < "$TRANSACTION"
}

transaction_matches_payload() {
  validate_transaction_shape || return 1
  _tab=$(printf '\t')
  while IFS="$_tab" read -r _kind _id _old _new
  do
    [ -n "$_kind" ] || continue
    _expected=$(new_object_hash "$_kind" "$_id") || return 1
    if [ "$_new" != "$_expected" ]; then
      printf 'transaction package mismatch: %s does not match this installer\n' "$_id" >&2
      return 1
    fi
  done < "$TRANSACTION"
}

lock_value() {
  awk -v key="$1:" '$1==key {print $2; exit}' "$LOCK"
}

verify_lock() {
  [ "$(lock_value '.agents/skills/handoff/SKILL.md')" = "$(hash_file "$TARGET/.agents/skills/handoff/SKILL.md")" ] || return 1
  [ "$(lock_value '.agents/tasks/TEMPLATE.md')" = "$(hash_file "$TARGET/.agents/tasks/TEMPLATE.md")" ] || return 1
  [ "$(lock_value 'tools/ledger.sh')" = "$(hash_file "$TARGET/tools/ledger.sh")" ] || return 1
  [ "$(lock_value 'AGENTS.md#handoff')" = "$(hash_agents_block "$TARGET/AGENTS.md")" ] || return 1
  [ "$(lock_value 'CLAUDE.md#handoff')" = "$(hash_import "$TARGET/CLAUDE.md")" ] || return 1
  [ "$(lock_value '.claude/skills/handoff#target')" = "$(hash_skill_link "$TARGET/.claude/skills/handoff")" ] || return 1
}

complete_legacy_install() {
  [ -f "$TARGET/.agents/skills/handoff/SKILL.md" ] || return 1
  [ -f "$TARGET/.agents/tasks/TEMPLATE.md" ] || return 1
  [ -f "$TARGET/tools/ledger.sh" ] || return 1
  [ "$(hash_agents_block "$TARGET/AGENTS.md")" != missing ] || return 1
  [ "$(hash_import "$TARGET/CLAUDE.md")" != missing ] || return 1
  [ "$(hash_skill_link "$TARGET/.claude/skills/handoff")" = "$(hash_text '../../.agents/skills/handoff')" ] || return 1
}

current_payload_matches() {
  transaction_objects | while IFS="$(printf '\t')" read -r _kind _id
  do
    _actual=$(current_object_hash "$_kind" "$_id") || return 1
    _expected=$(new_object_hash "$_kind" "$_id") || return 1
    [ "$_actual" = "$_expected" ] || return 1
  done
}

validate_target_conflicts() {
  _entry=$TARGET/.claude/skills/handoff
  if [ -e "$_entry" ] || [ -L "$_entry" ]; then
    if [ ! -L "$_entry" ] || [ "$(readlink "$_entry")" != '../../.agents/skills/handoff' ]; then
      printf 'conflicting skill entry: %s\n' "$_entry" >&2
      return 1
    fi
  fi
}

detect_state() {
  if [ -f "$TRANSACTION" ]; then
    printf 'interrupted\n'
    return
  fi
  if [ -f "$LOCK" ]; then
    if ! verify_lock; then
      printf 'modified\n'
    else
      _locked_version=$(awk '$1=="version:" {print $2; exit}' "$LOCK")
      if [ "$_locked_version" = unknown ]; then
        printf 'adopted\n'
      elif ! valid_version "$_locked_version"; then
        printf 'invalid-version\n'
      elif ! valid_version "$VERSION"; then
        printf 'invalid-version\n'
      else
        case "$(compare_versions "$_locked_version" "$VERSION")" in
          -1) printf 'outdated\n' ;;
          0) printf 'current\n' ;;
          1) printf 'newer\n' ;;
        esac
      fi
    fi
  elif [ -f "$TARGET/.agents/skills/handoff/SKILL.md" ] || \
       [ -f "$TARGET/.agents/tasks/TEMPLATE.md" ] || \
       [ -f "$TARGET/tools/ledger.sh" ] || \
       grep -qF "$BEGIN" "$TARGET/AGENTS.md" 2>/dev/null; then
    printf 'legacy\n'
  else
    printf 'uninstalled\n'
  fi
}

write_lock() {
  _lock_version=${1:-$VERSION}
  mkdir -p "$TARGET/.agents"
  {
    printf 'version: %s\n' "$_lock_version"
    printf 'managed_files:\n'
    printf '  .agents/skills/handoff/SKILL.md: %s\n' "$(hash_file "$TARGET/.agents/skills/handoff/SKILL.md")"
    printf '  .agents/tasks/TEMPLATE.md: %s\n' "$(hash_file "$TARGET/.agents/tasks/TEMPLATE.md")"
    printf '  tools/ledger.sh: %s\n' "$(hash_file "$TARGET/tools/ledger.sh")"
    printf 'managed_fragments:\n'
    printf '  AGENTS.md#handoff: %s\n' "$(hash_agents_block "$TARGET/AGENTS.md")"
    printf '  CLAUDE.md#handoff: %s\n' "$(hash_import "$TARGET/CLAUDE.md")"
    printf '  .claude/skills/handoff#target: %s\n' "$(hash_skill_link "$TARGET/.claude/skills/handoff")"
  } > "$WORK/lock"
  mv "$WORK/lock" "$LOCK"
}

write_agents_block() {
  _target=$TARGET/AGENTS.md
  if [ -f "$_target" ] && grep -qF "$BEGIN" "$_target"; then
    awk -v b="$BEGIN" -v e="$END" '$0==b{skip=1} !skip{print} $0==e{skip=0}' "$_target" > "$WORK/agents-body"
  elif [ -f "$_target" ]; then
    cp "$_target" "$WORK/agents-body"
    printf '\n' >> "$WORK/agents-body"
  else
    : > "$WORK/agents-body"
  fi
  { sed -n '1,$p' "$WORK/agents-body"; sed -n '1,$p' "$AGENTS_SOURCE"; } > "$WORK/AGENTS.md"
  mv "$WORK/AGENTS.md" "$_target"
}

write_import() {
  _target=$TARGET/CLAUDE.md
  _line=$(tr -d '\r\n' < "$IMPORT_SOURCE")
  if [ ! -f "$_target" ]; then
    printf '%s\n' "$_line" > "$_target"
  elif [ "$(head -1 "$_target")" != "$_line" ]; then
    { printf '%s\n' "$_line"; sed -n '1,$p' "$_target"; } > "$WORK/import"
    mv "$WORK/import" "$_target"
  fi
}

write_skill_link() {
  _target=$TARGET/.claude/skills/handoff
  mkdir -p "$TARGET/.claude/skills"
  if [ -e "$_target" ] || [ -L "$_target" ]; then
    if [ ! -L "$_target" ] || [ "$(readlink "$_target")" != '../../.agents/skills/handoff' ]; then
      printf 'conflicting skill entry: %s\n' "$_target" >&2
      exit 1
    fi
  else
    ln -s ../../.agents/skills/handoff "$_target"
  fi
}

apply_payload() {
  mkdir -p "$TARGET/.agents/skills/handoff" "$TARGET/.agents/tasks/archive" "$TARGET/tools"
  cp "$SKILL_SOURCE" "$TARGET/.agents/skills/handoff/SKILL.md"
  cp "$TEMPLATE_SOURCE" "$TARGET/.agents/tasks/TEMPLATE.md"
  cp "$LEDGER_SOURCE" "$TARGET/tools/ledger.sh"
  chmod +x "$TARGET/tools/ledger.sh"
  write_skill_link
  write_agents_block
  write_import
}

commit_payload() {
  validate_target_conflicts
  write_transaction
  apply_payload
  write_lock
  rm -f "$TRANSACTION"
}

recover_transaction() {
  [ -f "$TRANSACTION" ] || return 0
  transaction_matches_payload || return 1
  if [ -f "$LOCK" ]; then
    _locked_version=$(awk '$1=="version:" {print $2; exit}' "$LOCK")
    if [ "$_locked_version" != unknown ] && ! valid_version "$_locked_version"; then
      printf 'transaction recovery refuses an invalid installed version\n' >&2
      return 1
    fi
    if valid_version "$_locked_version" && valid_version "$VERSION" && \
       [ "$(compare_versions "$_locked_version" "$VERSION")" = 1 ]; then
      printf 'transaction recovery would downgrade version %s\n' "$_locked_version" >&2
      return 1
    fi
  fi
  validate_transaction || return 1
  apply_payload
  write_lock
  rm -f "$TRANSACTION"
}

STATE=$(detect_state)
printf 'state=%s\n' "$STATE"

if [ "$MODE" != status ]; then
  validate_payload_sources || exit 1
fi

if [ "$STATE" = interrupted ] && [ "$MODE" != status ]; then
  if [ "$MODE" = adopt-existing ]; then
    printf 'interrupted handoff transaction found; use install or update to recover\n' >&2
    exit 2
  fi
  recover_transaction || exit 3
  STATE=$(detect_state)
  printf 'state=%s\n' "$STATE"
fi

case "$MODE:$STATE" in
  status:*) exit 0 ;;
  install:uninstalled) commit_payload ;;
  install:current|update:current|adopt-existing:current)
    printf 'already installed at version %s; no changes\n' "$VERSION"
    ;;
  install:outdated)
    printf 'older handoff version found; use update\n' >&2
    exit 2
    ;;
  install:adopted)
    printf 'adopted handoff files differ from this version; use update\n' >&2
    exit 2
    ;;
  install:newer|update:newer)
    printf 'newer handoff version found; refusing to downgrade\n' >&2
    exit 2
    ;;
  install:invalid-version|update:invalid-version)
    printf 'installed handoff version is missing or invalid; refusing to overwrite\n' >&2
    exit 2
    ;;
  install:legacy|update:legacy)
    printf 'handoff files exist without a lock; use adopt-existing\n' >&2
    exit 2
    ;;
  update:outdated|update:adopted) commit_payload ;;
  update:uninstalled)
    printf 'handoff is not installed; use install\n' >&2
    exit 2
    ;;
  adopt-existing:legacy)
    if ! complete_legacy_install; then
      printf 'cannot adopt an incomplete handoff installation\n' >&2
      exit 2
    fi
    if current_payload_matches; then
      write_lock "$VERSION"
    else
      write_lock unknown
    fi
    ;;
  adopt-existing:uninstalled|adopt-existing:outdated|adopt-existing:newer|adopt-existing:invalid-version)
    printf 'adopt-existing requires a complete lockless installation\n' >&2
    exit 2
    ;;
  *:modified)
    printf 'managed handoff files have local changes; refusing to overwrite\n' >&2
    exit 3
    ;;
  *)
    printf 'unsupported transition: mode=%s state=%s\n' "$MODE" "$STATE" >&2
    exit 2
    ;;
esac

STATE=$(detect_state)
printf 'state=%s\n' "$STATE"
