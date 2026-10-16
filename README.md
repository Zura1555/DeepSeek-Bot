# DeepSeek Bot — Mobile Fork

English | [中文](README.zh.md)

[Zura1555’s fork](https://github.com/Zura1555/DeepSeek-Bot) of [DeepSeek-Bot](https://github.com/Fei2411/DeepSeek-Bot), a Bot-team plugin for [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness) (DSH).

## What’s different

The mobile changes live on [`feat/mobile-bot-layout`](https://github.com/Zura1555/DeepSeek-Bot/tree/feat/mobile-bot-layout):

- Full-width chat and a sidebar drawer at widths up to 768px.
- Full-screen details, memory, and settings panels.
- Safe-area and keyboard-aware composer; touch-accessible message actions.
- Desktop layout unchanged above 768px. Existing Bots, groups, memory, approvals, and tools remain available.

No DSH core modifications. The default `main` branch does not yet include the mobile implementation.

## Install this fork

Requires Git, Node.js 22.19+ and pnpm. Configure a model in DSH first.

```sh
npx @deepseek-ai/dsh@0.2.0-rc.2 plugin --profile web add 'github:Zura1555/DeepSeek-Bot#feat/mobile-bot-layout&path:/ds-bot'
npx @deepseek-ai/dsh@0.2.0-rc.2 web
```

For DSH Desktop, use the same GitHub package address in **Plugins → Add plugin**. Restart DSH if prompted.

Talk to **Chief**, the Main Bot, to set up your team. Installing the npm package `ds-bot` installs upstream, not this fork’s mobile branch.

## Docs and safety

[Plugin documentation](ds-bot/README.md) · [Development](CONTRIBUTING.md) · [Upstream](https://github.com/Fei2411/DeepSeek-Bot)

Data stays in the DSH home directory. Bots use your model quota and can run tools; review important actions. Keep DSH authentication enabled when exposing it remotely.

## License

[Apache-2.0](LICENSE). Original project by [Fei2411 and contributors](https://github.com/Fei2411/DeepSeek-Bot); third-party notices in [NOTICE](NOTICE). Independent community project, not an official DeepSeek product.
