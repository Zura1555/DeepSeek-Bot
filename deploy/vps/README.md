# VPS deployment and recovery

`Fork CI` checks the merged commit, builds the client, runs unit tests and lint, and exercises the Web UI at 390, 768, and 1280 px with the mock model. Only a successful push to `feat/mobile-bot-layout` creates a two-day release artifact. `Deploy production` downloads that same run's artifact, verifies its commit SHA and checksums, then sends it over SSH. The VPS extracts a versioned npm package and atomically switches only the existing `ds-bot` profile symlink. It does not build on the VPS, run `git pull`, install the npm `ds-bot` package, or edit DSH data or other plugins.

Harness proposals are separate: the weekly workflow reads npm's `latest` stable tag and proposes a PR updating the pinned test/lint Harness version and its npm lockfile. Fork CI validates against the matching `dsh-v<version>` source tag; if that tag is missing, compatibility remains blocked. The workflow never changes the systemd Harness version.

## Required GitHub setup

These are required before automatic deployment can work; none are configured by this change.

1. Put `.github/workflows/fork-ci.yml`, `deploy-production.yml`, `upstream-sync.yml`, and `harness-update.yml` on the repository's **default branch**. GitHub only schedules workflows from the default branch, and `workflow_run` requires its workflow there. The default can be `feat/mobile-bot-layout`, or copy the workflow files to the existing default branch.
2. Protect `feat/mobile-bot-layout`: require pull requests, required review, and the `Fork CI / validate` check; block direct pushes and force pushes. The sync PR is never auto-merged. Keep Actions allowed to create pull requests.
3. Create the GitHub Actions environment `production`. Add environment secrets:
   - `VPS_DEPLOY_KEY`: a dedicated private SSH key, never a personal or general-purpose key.
   - `VPS_KNOWN_HOSTS`: the exact SSH host-key line, verified out of band. Do not trust an unverified `ssh-keyscan` result.
4. Add environment variables:
   - `VPS_SSH_HOST`: the VPS SSH hostname or IPv4 address (not assumed to be `dsh.zura.tr`).
   - `VPS_SSH_PORT`: SSH port; omit for 22.
   Do not add app, DSH, Tailscale, or model credentials to Actions. Do not add a required environment reviewer if deployment must remain automatic after a reviewed merge.

## One-time VPS setup

Run these steps on the VPS as the `ubuntu` deployment account, using administrator privileges for `visudo` only. `$HOME` refers to that account's home directory. These steps do not run from this workspace.

1. Confirm the existing plugin entry is a symlink and points to the repository's custom plugin. Adjust `DSB_PLUGIN_LINK` only after inspecting the actual profile:

   ```sh
   test -L "$HOME/.dsh/profiles/web/node_modules/ds-bot"
   readlink -f "$HOME/.dsh/profiles/web/node_modules/ds-bot"
   ```

   The resolved target must be `$HOME/apps/DeepSeek-Bot/ds-bot`. If the installed path or target differs, stop; do not replace a directory, package-store entry, or unrelated plugin.

2. Install `deploy/vps/ssh-entrypoint.sh` from the reviewed production commit at `$HOME/apps/DeepSeek-Bot/deploy/vps/ssh-entrypoint.sh`. Add the dedicated public key to `$HOME/.ssh/authorized_keys` with this restriction (replace the public-key placeholder locally):

   ```text
   command="/bin/bash $HOME/apps/DeepSeek-Bot/deploy/vps/ssh-entrypoint.sh",restrict ssh-ed25519 AAAA... actions-ds-bot-deploy
   ```

   The forced command accepts only a SHA-pinned deployment bundle; forwarding and interactive shells are disabled.

3. Grant only the service restart permission. Validate the file with `visudo`:

   ```text
   ubuntu ALL=(root) NOPASSWD: /usr/bin/systemctl restart dsh-web.service
   ```

4. Create `$HOME/.config/ds-bot-deploy/config`, owned by `ubuntu`, mode `600`. It is sourced as shell configuration, so keep it owner-writable only; the paths below expand the deployment account's `$HOME`:

   ```sh
   DSB_ROOT=$HOME/apps/DeepSeek-Bot
   DSB_PROFILE=$HOME/.dsh/profiles/web
   DSB_PLUGIN_LINK=$HOME/.dsh/profiles/web/node_modules/ds-bot
   DSB_LEGACY_PLUGIN_TARGET=$HOME/apps/DeepSeek-Bot/ds-bot
   DSB_SERVICE=dsh-web.service
   DSB_HEALTH_URL=https://dsh.zura.tr/
   DSB_HEALTH_MARKER=
   DSB_RELEASES_DIR=$HOME/apps/DeepSeek-Bot/.deploy/releases
   DSB_KEEP_RELEASES=5
   ```

   Set `DSB_PLUGIN_LINK` to the symlink verified in step 1. Test `DSB_HEALTH_URL` from the VPS: it must return a non-empty successful HTTP response without weakening startup authentication. Set `DSB_HEALTH_MARKER` to a stable, visible application string if the response has one; the deployment then requires that marker too. Do not put credentials in the URL.

The first deployment must find the existing link and the matching legacy target. Deploys stage and parse-check the package before switching; `dsh-web.service` restarts only when the active plugin target changes. The deployment health gate requires both an active systemd service and a successful HTTP response. A failed restart or probe switches the old symlink back, restarts the service, and probes the restored app. The five newest versioned releases are retained, plus the active release if it is older than those five.

## Recovery

Automatic rollback runs on the VPS and its result is returned as a failed deployment if the new release does not recover. For a deliberate manual rollback, run as `ubuntu` with the previous retained commit SHA:

```sh
bash "$HOME/apps/DeepSeek-Bot/.deploy/rollback.sh" <40-character-commit-sha>
```

The helper restores the prior target if its own restart/health check fails. Check `readlink -f` on the configured plugin link and `systemctl status dsh-web.service` after recovery. Do not delete release directories while one is active. A rollback changes only the plugin symlink; it does not revert the Git branch or DSH profile data.

## Activation status

This repository change does not access the VPS, install an SSH key, add sudoers rules, configure GitHub secrets, or test production rollback. Treat deployment as **not enabled** until the GitHub environment, restricted VPS key/config, branch protections, and workflow placement are configured and an approved end-to-end deployment plus rollback has succeeded.
