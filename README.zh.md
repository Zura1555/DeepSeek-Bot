# DeepSeek Bot — 移动端分支

[English](README.md) | 中文

这是 [Zura1555](https://github.com/Zura1555/DeepSeek-Bot) 维护的 [DeepSeek-Bot](https://github.com/Fei2411/DeepSeek-Bot) 分支。DS Bot 是 [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness)（DSH）的 Bot 团队插件。

## 本分支的改动

移动端改进已包含在本仓库的 [`main`](https://github.com/Zura1555/DeepSeek-Bot/tree/main) 分支：

- 宽度不超过 768px 时，对话全宽显示，侧栏改为抽屉。
- 详情、记忆和设置使用全屏面板。
- 输入框适应安全区域和键盘视口，消息操作支持触屏。
- 超过 768px 保持原有桌面布局，保留 Bot、群聊、记忆、审批和工具功能。

没有修改 DSH 核心。

## 安装本分支

需要 Git、Node.js 22.19+ 和 pnpm，并先在 DSH 中配置模型。

```sh
npx @deepseek-ai/dsh@0.2.0-rc.2 plugin --profile web add 'github:Zura1555/DeepSeek-Bot#main&path:/ds-bot'
npx @deepseek-ai/dsh@0.2.0-rc.2 web
```

DSH Desktop 可在 **插件 → 添加插件** 中使用同一 GitHub 包地址；如有提示，请重启 DSH。

与主 Bot **Chief** 对话来配置团队。安装 npm 包 `ds-bot` 得到的是上游版本，不是本移动端分支。

## 文档与安全

[插件文档](ds-bot/README.md) · [开发指南](CONTRIBUTING.zh.md) · [上游仓库](https://github.com/Fei2411/DeepSeek-Bot)

数据保存在 DSH 主目录。Bot 会消耗模型额度并运行工具，请检查重要操作。远程访问时请保持 DSH 身份验证开启。

## 许可

[Apache-2.0](LICENSE)。原项目由 [Fei2411 及贡献者](https://github.com/Fei2411/DeepSeek-Bot) 开发，第三方声明见 [NOTICE](NOTICE)。本项目是独立社区项目，不是 DeepSeek 官方产品。
