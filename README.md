# DeepSeek Bot — Mobile Fork

English | [中文](README.zh.md)

[Zura1555’s fork](https://github.com/Zura1555/DeepSeek-Bot) of [DeepSeek-Bot](https://github.com/Fei2411/DeepSeek-Bot), a Bot-team plugin for [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness) (DSH).

## What’s different

Mobile improvements are included in this fork’s [`main`](https://github.com/Zura1555/DeepSeek-Bot/tree/main) branch:

- Full-width chat and a sidebar drawer at widths up to 768px.
- Full-screen details, memory, and settings panels.
- Safe-area and keyboard-aware composer; touch-accessible message actions.
- Desktop layout unchanged above 768px. Existing Bots, groups, memory, approvals, and tools remain available.

No DSH core modifications.

## Install this fork

Requires Git, Node.js 22.19+ and pnpm. Configure a model in DSH first.

1. In the sidebar, select **Plugins** → **Add plugin**.
2. In **Package name or address**, enter `ds-bot`. In mainland China, set **Registry** to **Mainland China mirror**.
3. Select **Install**, then **Enable now**. If DSH says the change takes effect at the next start, quit DSH completely and open it again.

If npm is not reachable, in step 2 you can also enter the full path of `ds-bot-0.1.7.tgz` downloaded from [Releases](https://github.com/Fei2411/DeepSeek-Bot/releases), or `github:Fei2411/DeepSeek-Bot#v0.1.7&path:/ds-bot` (needs Git).

**DSH Web (Windows, macOS, Linux)**

Needs Node.js `22.19` or later, and pnpm.

```sh
npx @deepseek-ai/dsh@0.2.0-rc.2 plugin --profile web add 'github:Zura1555/DeepSeek-Bot#main&path:/ds-bot'
npx @deepseek-ai/dsh@0.2.0-rc.2 web
```

For DSH Desktop, use the same GitHub package address in **Plugins → Add plugin**. Restart DSH if prompted.

**Docker (NAS, Linux server)**

The [`docker/`](docker/) directory builds an image with DSH Web and DS Bot, for a NAS or any always-on machine. The container is the Bots' sandbox: they get full access to what you mount into it, and nothing else. See [`docker/README.md`](docker/README.md).

## Setup

Talk to **Chief**, the Main Bot, to set up your team. Installing the npm package `ds-bot` installs upstream, not this mobile fork.

## Docs and safety

[Plugin documentation](ds-bot/README.md) · [Development](CONTRIBUTING.md) · [Upstream](https://github.com/Fei2411/DeepSeek-Bot)

Data stays in the DSH home directory. Bots use your model quota and can run tools; review important actions. Keep DSH authentication enabled when exposing it remotely.

## License

[Apache-2.0](LICENSE). Original project by [Fei2411 and contributors](https://github.com/Fei2411/DeepSeek-Bot); third-party notices in [NOTICE](NOTICE). Independent community project, not an official DeepSeek product.
