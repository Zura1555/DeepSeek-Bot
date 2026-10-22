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

Bot 回复包含网页链接时，会显示带动态网站图标的**来源**卡片，群聊消息和已加载的历史消息也支持。卡片列出当前显示的回复中的链接，不代表经过独立核验的引用；Markdown 行内图标不变。图标按需从 DuckDuckGo 图标服务加载，只发送主机名，不发送来源页面地址。该服务能看到你的 IP 和请求的主机名；IP 地址、单段主机名及保留的本地/测试域名不请求图标，保留地球图标。图标加载失败时也保留地球图标。

## 安装本分支

需要 Git、Node.js 22.19+ 和 pnpm，并先在 DSH 中配置模型。

1. 侧栏点 **插件** → **添加插件**。
2. **包名或地址** 填 `github:Zura1555/DeepSeek-Bot#main&path:/ds-bot`。
3. 点 **安装**，再点 **立即启用**。如果提示“下次启动生效”，完全退出 dsh 再打开。

**dsh Web（Windows、macOS、Linux）**

需要 Node.js `22.19` 以上和 pnpm。

```sh
npx @deepseek-ai/dsh@0.2.1-rc.2 plugin --profile web add 'github:Zura1555/DeepSeek-Bot#main&path:/ds-bot'
npx @deepseek-ai/dsh@0.2.1-rc.2 web
```

DSH Desktop 可在 **插件 → 添加插件** 中使用同一 GitHub 包地址；如有提示，请重启 DSH。

**Docker（NAS、Linux 服务器）**

[`docker/`](docker/) 目录构建一个带 dsh Web 和 DS Bot 的镜像，适合 NAS 或其他常开的机器。CI 已配置为向 GHCR 发布 linux/amd64 预构建镜像。容器就是 bot 的沙箱：bot 对挂进容器的目录有完全权限，其他的碰不到。见 [`docker/README.md`](docker/README.md)（英文）。

## 配置

与主 Bot **Chief** 对话来配置团队。安装 npm 包 `ds-bot` 得到的是上游版本，不是本移动端分支。

## 文档与安全

[插件文档](ds-bot/README.md) · [开发指南](CONTRIBUTING.zh.md) · [上游仓库](https://github.com/Fei2411/DeepSeek-Bot)

数据保存在 DSH 主目录。Bot 会消耗模型额度并运行工具，请检查重要操作。远程访问时请保持 DSH 身份验证开启。

## 许可

[Apache-2.0](LICENSE)。原项目由 [Fei2411 及贡献者](https://github.com/Fei2411/DeepSeek-Bot) 开发，第三方声明见 [NOTICE](NOTICE)。本项目是独立社区项目，不是 DeepSeek 官方产品。
