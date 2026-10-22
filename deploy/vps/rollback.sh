#!/usr/bin/env bash
set -euo pipefail
umask 077

fail() {
  printf 'rollback error: %s\n' "$*" >&2
  exit 1
}

[[ $# -eq 1 && $1 =~ ^[0-9a-f]{40}$ ]] || fail 'expected: rollback.sh <previous-commit-sha>'
release_sha=$1
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
[[ -L $DSB_PLUGIN_LINK ]] || fail 'the plugin installation is not a symlink'
[[ -d $DSB_ROOT/.deploy ]] || fail 'deployment metadata directory is missing'
lock_file="$DSB_ROOT/.deploy/deploy.lock"
[[ ! -L $lock_file && ( ! -e $lock_file || -f $lock_file ) ]] || fail 'deployment lock must be a regular file, not a symlink'
exec 9>>"$lock_file"
flock -w 600 9 || fail 'another DS Bot deployment or rollback is still running'

legacy_target=$(readlink -f -- "$DSB_LEGACY_PLUGIN_TARGET") || fail 'legacy linked plugin target does not exist'
old_target=$(readlink -f -- "$DSB_PLUGIN_LINK") || fail 'the current plugin link target is missing'
if [[ $old_target != "$legacy_target" ]]; then
  prefix="$DSB_RELEASES_DIR/"
  [[ $old_target == "$prefix"*/package ]] || fail 'current plugin link points outside managed releases'
  old_release=${old_target#"$prefix"}
  old_release=${old_release%/package}
  [[ $old_release =~ ^[0-9a-f]{40}$ ]] || fail 'current release link is not a managed commit release'
fi

release_dir="$DSB_RELEASES_DIR/$release_sha"
new_target="$release_dir/package"
[[ -d $release_dir && ! -L $release_dir && -d $new_target && ! -L $new_target ]] || fail 'requested retained release is missing or unsafe'

health_body=$(mktemp)
switched=0
completed=0
atomic_link() {
  local target=$1 temp="$DSB_PLUGIN_LINK.rollback.$$"
  rm -f -- "$temp"
  ln -s -- "$target" "$temp"
  mv -Tf -- "$temp" "$DSB_PLUGIN_LINK"
}
restart_service() { sudo -n /usr/bin/systemctl restart "$DSB_SERVICE"; }
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
    printf 'rollback failed; restoring the release that was active before this attempt.\n' >&2
    if atomic_link "$old_target" && restart_service && wait_for_health; then
      printf 'previous active release restored and health check passed.\n' >&2
    else
      printf 'recovery could not be verified; inspect %s and %s.\n' "$DSB_SERVICE" "$DSB_HEALTH_URL" >&2
    fi
  fi
  rm -f -- "$health_body"
  exit "$status"
}
trap cleanup EXIT

if [[ $old_target != "$new_target" ]]; then
  atomic_link "$new_target"
  switched=1
  restart_service || fail 'systemd restart failed'
fi
wait_for_health || fail 'service or HTTP health check did not pass'
completed=1
printf 'rolled back to DS Bot release %s; service and HTTP health checks passed.\n' "$release_sha"
