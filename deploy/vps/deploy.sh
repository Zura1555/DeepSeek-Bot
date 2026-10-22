#!/usr/bin/env bash
set -euo pipefail
umask 077

fail() {
  printf 'deployment error: %s\n' "$*" >&2
  exit 1
}

[[ $# -eq 2 ]] || fail 'expected: deploy.sh <commit-sha> <plugin-tarball>'
expected_sha=$1
plugin_tarball=$2
[[ $expected_sha =~ ^[0-9a-f]{40}$ ]] || fail 'invalid tested commit SHA'
[[ -f $plugin_tarball && ! -L $plugin_tarball ]] || fail 'plugin artifact is missing or not a regular file'
bundle_dir=$(dirname -- "$plugin_tarball")
rollback_source="$bundle_dir/rollback.sh"
[[ -f $rollback_source && ! -L $rollback_source ]] || fail 'rollback helper is missing from the tested bundle'
bash -n "$rollback_source" || fail 'rollback helper does not parse'

config=${DSB_DEPLOY_CONFIG:-$HOME/.config/ds-bot-deploy/config}
[[ -f $config && ! -L $config && -O $config ]] || fail 'deployment config must be an owned regular file'
config_mode=$(stat -c '%a' "$config")
(( (8#$config_mode & 077) == 0 )) || fail 'deployment config permissions must be 600 or stricter'
# This is a locally managed, owner-only config file; it contains paths and health settings.
# shellcheck disable=SC1090
. "$config"

: "${DSB_ROOT:=$HOME/apps/DeepSeek-Bot}"
: "${DSB_PROFILE:=$HOME/.dsh/profiles/web}"
: "${DSB_PLUGIN_LINK:?set DSB_PLUGIN_LINK to the existing linked ds-bot path in the profile}"
: "${DSB_LEGACY_PLUGIN_TARGET:=$DSB_ROOT/ds-bot}"
: "${DSB_SERVICE:=dsh-web.service}"
: "${DSB_HEALTH_URL:=https://dsh.zura.tr/}"
: "${DSB_RELEASES_DIR:=$DSB_ROOT/.deploy/releases}"
: "${DSB_KEEP_RELEASES:=5}"
: "${DSB_HEALTH_MARKER:=}"

[[ $DSB_ROOT == /* && $DSB_ROOT != / && -d $DSB_ROOT ]] || fail 'DSB_ROOT must be an absolute existing repository directory'
[[ $DSB_PROFILE == /* && $DSB_PROFILE != / && -d $DSB_PROFILE ]] || fail 'DSB_PROFILE must be an absolute existing profile directory'
profile_modules=$(realpath -e -- "$DSB_PROFILE/node_modules") || fail 'profile node_modules directory does not exist'
plugin_link_parent=$(realpath -e -- "$(dirname -- "$DSB_PLUGIN_LINK")") || fail 'plugin link parent directory does not exist'
[[ $plugin_link_parent == "$profile_modules" && $(basename -- "$DSB_PLUGIN_LINK") == ds-bot ]] || fail 'DSB_PLUGIN_LINK must be the ds-bot entry inside profile node_modules'
[[ $DSB_LEGACY_PLUGIN_TARGET == "$DSB_ROOT/ds-bot" ]] || fail 'legacy plugin target must be the repository-local DS Bot'
[[ $DSB_RELEASES_DIR == "$DSB_ROOT/.deploy/releases" ]] || fail 'release storage must stay under the production repository'
[[ ! -L $DSB_ROOT/.deploy && ! -L $DSB_RELEASES_DIR ]] || fail 'deployment storage must not be a symlink'
[[ $DSB_SERVICE =~ ^[A-Za-z0-9_.@-]+\.service$ ]] || fail 'invalid systemd service name'
[[ $DSB_HEALTH_URL =~ ^https?://[^[:space:]]+$ && $DSB_HEALTH_URL != *'@'* ]] || fail 'health URL must be HTTP(S) without embedded credentials'
[[ $DSB_KEEP_RELEASES =~ ^[2-9][0-9]*$ ]] || fail 'DSB_KEEP_RELEASES must be at least 2'
[[ -L $DSB_PLUGIN_LINK ]] || fail 'the existing plugin installation is not a symlink; refusing to replace it'
mkdir -p -- "$DSB_RELEASES_DIR"
lock_file="$DSB_ROOT/.deploy/deploy.lock"
[[ ! -L $lock_file && ( ! -e $lock_file || -f $lock_file ) ]] || fail 'deployment lock must be a regular file, not a symlink'
exec 9>>"$lock_file"
flock -w 600 9 || fail 'another DS Bot deployment or rollback is still running'

legacy_target=$(readlink -f -- "$DSB_LEGACY_PLUGIN_TARGET") || fail 'legacy linked plugin target does not exist'
old_target=$(readlink -f -- "$DSB_PLUGIN_LINK") || fail 'the existing plugin link target is missing'
if [[ $old_target != "$legacy_target" ]]; then
  prefix="$DSB_RELEASES_DIR/"
  [[ $old_target == "$prefix"*/package ]] || fail 'plugin link points outside the legacy package and managed releases'
  old_release=${old_target#"$prefix"}
  old_release=${old_release%/package}
  [[ $old_release =~ ^[0-9a-f]{40}$ ]] || fail 'current release link is not a managed commit release'
fi

work=$(mktemp -d "$DSB_RELEASES_DIR/.stage-$expected_sha.XXXXXX")
health_body=$(mktemp)
active_target=$old_target
switched=0
completed=0
rollback_temp="$DSB_ROOT/.deploy/.rollback.$$"

atomic_link() {
  local target=$1 temp="$DSB_PLUGIN_LINK.deploy.$$"
  rm -f -- "$temp"
  ln -s -- "$target" "$temp"
  mv -Tf -- "$temp" "$DSB_PLUGIN_LINK"
}

restart_service() {
  sudo -n /usr/bin/systemctl restart "$DSB_SERVICE"
}

healthy() {
  systemctl is-active --quiet "$DSB_SERVICE" || return 1
  curl --fail --silent --show-error --location --connect-timeout 5 --max-time 15 \
    "$DSB_HEALTH_URL" --output "$health_body" 2>/dev/null || return 1
  [[ -s $health_body ]] || return 1
  [[ -z $DSB_HEALTH_MARKER ]] || grep -Fq -- "$DSB_HEALTH_MARKER" "$health_body"
}

wait_for_health() {
  local attempt
  for ((attempt = 0; attempt < 30; attempt++)); do
    healthy && return 0
    sleep 2
  done
  return 1
}

cleanup() {
  local status=$?
  trap - EXIT
  if (( switched && ! completed )); then
    printf 'deployment failed; restoring previous DS Bot release.\n' >&2
    if atomic_link "$active_target" && restart_service && wait_for_health; then
      printf 'rollback restored the previous release and passed the health check.\n' >&2
    else
      printf 'rollback could not verify recovery; inspect %s and %s.\n' "$DSB_SERVICE" "$DSB_HEALTH_URL" >&2
    fi
  fi
  rm -rf -- "$work" "$health_body" "$rollback_temp"
  exit "$status"
}
trap cleanup EXIT

# Reject archive paths outside npm's package/ root before extraction.
while IFS= read -r member; do
  [[ $member == package/ || $member == package/* ]] || fail 'plugin archive contains an unexpected path'
  [[ $member != /* && $member != *'/../'* && $member != ../* ]] || fail 'plugin archive contains an unsafe path'
done < <(tar -tzf "$plugin_tarball")
while IFS= read -r details; do
  [[ ${details:0:1} == '-' || ${details:0:1} == 'd' ]] || fail 'plugin archive contains a link or non-file entry'
done < <(tar -tvzf "$plugin_tarball")


tar --no-same-owner --no-same-permissions -xzf "$plugin_tarball" -C "$work"
new_package="$work/package"
[[ -d $new_package && ! -L $new_package ]] || fail 'plugin package directory is missing'
node - "$new_package" <<'NODE'
const fs = require('node:fs')
const path = require('node:path')
const root = process.argv[2]
const pkg = JSON.parse(fs.readFileSync(path.join(root, 'package.json'), 'utf8'))
if (pkg.name !== 'ds-bot' || !pkg.version) throw new Error('artifact is not a versioned ds-bot package')
for (const file of ['index.js', 'web-search.js', 'client.js', 'src/host', 'src/shared']) {
  if (!fs.existsSync(path.join(root, file))) throw new Error(`artifact is missing ${file}`)
}
NODE
node --check "$new_package/index.js"
node --check "$new_package/client.js"

release_dir="$DSB_RELEASES_DIR/$expected_sha"
release_package="$release_dir/package"
if [[ -e $release_dir || -L $release_dir ]]; then
  [[ -d $release_dir && ! -L $release_dir && -d $release_package && ! -L $release_package ]] || fail 'incomplete or unsafe release directory already exists'
  diff -qr -- "$new_package" "$release_package" >/dev/null || fail 'artifact differs from the existing release for this commit'
else
  mkdir -- "$release_dir"
  mv -- "$new_package" "$release_package"
fi

cp -- "$rollback_source" "$rollback_temp"
chmod 700 "$rollback_temp"
mv -f -- "$rollback_temp" "$DSB_ROOT/.deploy/rollback.sh"
if [[ $old_target != "$release_package" ]]; then
  atomic_link "$release_package"
  switched=1
  restart_service || fail 'systemd restart failed'
fi
wait_for_health || fail 'service or HTTP health check did not pass'
completed=1
printf 'deployed tested commit %s; service and HTTP health checks passed.\n' "$expected_sha"

# Keep the newest releases and always retain the active target for rollback.
current_target=$(readlink -f -- "$DSB_PLUGIN_LINK")
count=0
while IFS= read -r directory; do
  ((count += 1))
  if (( count > DSB_KEEP_RELEASES )) && [[ "$directory/package" != "$current_target" ]]; then
    rm -rf -- "$directory"
  fi
done < <(find "$DSB_RELEASES_DIR" -mindepth 1 -maxdepth 1 -type d -regextype posix-extended -regex '.*/[0-9a-f]{40}' -printf '%T@ %p\n' | sort -rn | cut -d' ' -f2-)
