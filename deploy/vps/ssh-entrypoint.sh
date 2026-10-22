#!/usr/bin/env bash
set -euo pipefail
umask 077

fail() {
  printf 'deployment rejected: %s\n' "$*" >&2
  exit 1
}

[[ ${SSH_ORIGINAL_COMMAND:-} =~ ^deploy\ ([0-9a-f]{40})$ ]] || fail 'only the fixed deploy <40-character-commit-sha> command is allowed'
expected_sha=${BASH_REMATCH[1]}
upload=$(mktemp -d "${TMPDIR:-/tmp}/ds-bot-deploy.XXXXXX")
trap 'rm -rf -- "$upload"' EXIT
archive="$upload/bundle.tar.gz"
head -c 52428801 > "$archive"
size=$(stat -c '%s' "$archive")
(( size > 0 && size <= 52428800 )) || fail 'deployment bundle is empty or exceeds 50 MiB'

members=$(tar -tzf "$archive") || fail 'deployment bundle is not a valid gzip tar archive'
[[ $(printf '%s\n' "$members" | wc -l) -eq 5 ]] || fail 'deployment bundle must contain exactly five files'
while IFS= read -r member; do
  case "$member" in
    plugin.tgz|SHA256SUMS|commit.txt|deploy.sh|rollback.sh) ;;
    *) fail 'deployment bundle contains an unexpected path' ;;
  esac
done <<< "$members"
while IFS= read -r details; do
  [[ ${details:0:1} == '-' ]] || fail 'deployment bundle may contain only regular files'
done < <(tar -tvzf "$archive")

tar --no-same-owner --no-same-permissions -xzf "$archive" -C "$upload"
for file in plugin.tgz SHA256SUMS commit.txt deploy.sh rollback.sh; do
  [[ -f $upload/$file && ! -L $upload/$file ]] || fail "bundle member $file is not a regular file"
done
printf '%s\n' "$expected_sha" | cmp -s - "$upload/commit.txt" || fail 'bundle commit does not match the tested commit'
(
  cd "$upload"
  [[ $(wc -l < SHA256SUMS) -eq 3 ]] || fail 'invalid deployment checksum manifest'
  sha256sum plugin.tgz deploy.sh rollback.sh | cmp -s - SHA256SUMS || fail 'deployment checksum manifest does not match its files'
  sha256sum --check --status SHA256SUMS || fail 'deployment artifact checksum mismatch'
)
bash -n "$upload/deploy.sh" "$upload/rollback.sh" || fail 'deployment scripts do not parse'
bash "$upload/deploy.sh" "$expected_sha" "$upload/plugin.tgz"
