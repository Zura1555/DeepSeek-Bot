#!/usr/bin/env bash
set -euo pipefail

[[ $# -eq 1 && -f $1 ]] || { echo 'usage: test.sh <npm-plugin-tarball>' >&2; exit 2; }
plugin_tarball=$(realpath -- "$1")
bundle_dir=$(dirname -- "$plugin_tarball")
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
[[ -f $bundle_dir/rollback.sh ]] || { echo 'rollback.sh must be beside the plugin tarball' >&2; exit 2; }

temp=$(mktemp -d)
trap 'rm -rf -- "$temp"' EXIT
root="$temp/repository"
profile="$temp/profile"
mockbin="$temp/mockbin"
mkdir -p "$root/ds-bot" "$profile/node_modules" "$mockbin"
plugin_link="$profile/node_modules/ds-bot"
ln -s "$root/ds-bot" "$plugin_link"
config="$temp/config"
printf 'DSB_ROOT=%s\nDSB_PROFILE=%s\nDSB_PLUGIN_LINK=%s\nDSB_LEGACY_PLUGIN_TARGET=%s/ds-bot\nDSB_SERVICE=dsh-web.service\nDSB_HEALTH_URL=http://example.invalid/\nDSB_HEALTH_MARKER=test-application\nDSB_RELEASES_DIR=%s/.deploy/releases\nDSB_KEEP_RELEASES=5\n' \
  "$root" "$profile" "$plugin_link" "$root" "$root" > "$config"
chmod 600 "$config"

cat > "$mockbin/sudo" <<'MOCK'
#!/usr/bin/env bash
[[ $1 == -n && $2 == /usr/bin/systemctl && $3 == restart && $4 == dsh-web.service ]] || exit 1
printf 'restart\n' >> "$TEST_SERVICE_LOG"
MOCK
cat > "$mockbin/systemctl" <<'MOCK'
#!/usr/bin/env bash
[[ $1 == is-active && $2 == --quiet && $3 == dsh-web.service ]]
MOCK
cat > "$mockbin/curl" <<'MOCK'
#!/usr/bin/env bash
output=''
want_output=0
for arg in "$@"; do
  if (( want_output )); then output=$arg; want_output=0; continue; fi
  [[ $arg == --output ]] && want_output=1
done
[[ -n $output ]] || exit 2
current=$(readlink -f -- "$TEST_PLUGIN_LINK")
if [[ -n ${FAIL_RELEASE_SHA:-} && $current == *"$FAIL_RELEASE_SHA"* ]]; then exit 22; fi
printf 'test-application\n' > "$output"
MOCK
cat > "$mockbin/sleep" <<'MOCK'
#!/usr/bin/env bash
exit 0
MOCK
chmod 700 "$mockbin"/*
export PATH="$mockbin:$PATH"
export DSB_DEPLOY_CONFIG="$config"
export TEST_PLUGIN_LINK="$plugin_link"
export TEST_SERVICE_LOG="$temp/service.log"

sha1=1111111111111111111111111111111111111111
sha2=2222222222222222222222222222222222222222
sha3=3333333333333333333333333333333333333333
sha4=4444444444444444444444444444444444444444
upload="$temp/upload"
mkdir -p "$upload"
cp -- "$plugin_tarball" "$upload/plugin.tgz"
cp -- "$script_dir/deploy.sh" "$upload/deploy.sh"
cp -- "$bundle_dir/rollback.sh" "$upload/rollback.sh"
printf '%s\n' "$sha1" > "$upload/commit.txt"
(cd "$upload" && sha256sum plugin.tgz deploy.sh rollback.sh > SHA256SUMS)
tar -czf "$temp/upload.tar.gz" -C "$upload" plugin.tgz SHA256SUMS commit.txt deploy.sh rollback.sh
if SSH_ORIGINAL_COMMAND='bash -c id' bash "$script_dir/ssh-entrypoint.sh" </dev/null; then
  echo 'restricted SSH receiver accepted an arbitrary command' >&2
  exit 1
fi
SSH_ORIGINAL_COMMAND="deploy $sha1" TMPDIR="$temp" bash "$script_dir/ssh-entrypoint.sh" < "$temp/upload.tar.gz"
[[ $(readlink -f -- "$plugin_link") == "$root/.deploy/releases/$sha1/package" ]]
bash "$script_dir/deploy.sh" "$sha2" "$plugin_tarball"
[[ $(readlink -f -- "$plugin_link") == "$root/.deploy/releases/$sha2/package" ]]
bash "$root/.deploy/rollback.sh" "$sha1"
[[ $(readlink -f -- "$plugin_link") == "$root/.deploy/releases/$sha1/package" ]]
lock_target="$temp/protected-lock"
printf 'protected\n' > "$lock_target"
mv "$root/.deploy/deploy.lock" "$temp/deploy.lock"
ln -s "$lock_target" "$root/.deploy/deploy.lock"
if bash "$script_dir/deploy.sh" "$sha3" "$plugin_tarball"; then
  echo 'deployment followed a symlinked lock file' >&2
  exit 1
fi
if bash "$root/.deploy/rollback.sh" "$sha1"; then
  echo 'rollback followed a symlinked lock file' >&2
  exit 1
fi
[[ $(cat "$lock_target") == protected ]]
rm "$root/.deploy/deploy.lock"
mv "$temp/deploy.lock" "$root/.deploy/deploy.lock"
ln -s "$root/.deploy/releases/$sha2" "$root/.deploy/releases/$sha4"
if bash "$script_dir/deploy.sh" "$sha4" "$plugin_tarball"; then
  echo 'deployment accepted a symlinked release directory' >&2
  exit 1
fi
if bash "$root/.deploy/rollback.sh" "$sha4"; then
  echo 'manual rollback accepted a symlinked release directory' >&2
  exit 1
fi
[[ $(readlink -f -- "$plugin_link") == "$root/.deploy/releases/$sha1/package" ]]
if FAIL_RELEASE_SHA=$sha3 bash "$script_dir/deploy.sh" "$sha3" "$plugin_tarball"; then
  echo 'failed health probe unexpectedly kept the new release' >&2
  exit 1
fi
[[ $(readlink -f -- "$plugin_link") == "$root/.deploy/releases/$sha1/package" ]]
[[ $(wc -l < "$TEST_SERVICE_LOG") -eq 5 ]]
rm -- "$root/.deploy/releases/$sha4"
for sha in \
  5555555555555555555555555555555555555555 \
  6666666666666666666666666666666666666666 \
  7777777777777777777777777777777777777777 \
  8888888888888888888888888888888888888888 \
  9999999999999999999999999999999999999999 \
  aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
do
  bash "$script_dir/deploy.sh" "$sha" "$plugin_tarball" >/dev/null
done
retained=$(find "$root/.deploy/releases" -mindepth 1 -maxdepth 1 -type d | wc -l)
[[ $retained -eq 5 ]] || { echo "expected 5 retained releases, found $retained" >&2; exit 1; }
printf 'deployment smoke test passed: exact release switch, manual and automatic rollback, and five-release retention.\n'
