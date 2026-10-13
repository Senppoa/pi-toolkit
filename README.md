# pi-toolkit

一套 **Pi Agent**（[pi coding agent](https://pi.dev)）配置的声明式备份与一键恢复方案，适用于 Linux / WSL。

不备份整个 `~/.pi`：仓库只保存配置声明、自定义文件和少量技能；插件在恢复时由 `pi install`
从 npm / GitHub 官方源重新拉取。因此仓库体积小、不含密钥，可跨机器复用。

## 快速恢复（新机器）

```bash
git clone https://github.com/Senppoa/pi-toolkit.git ~/pi-toolkit
cd ~/pi-toolkit
bash bootstrap.sh
```

`bootstrap.sh` 是幂等的：已存在的配置会先备份到 `~/.pi-backup-<时间戳>/`。恢复后还需手动完成：

1. **认证**：运行 `pi` 完成 OAuth 登录，或配置对应 provider 的 API Key（`pi auth status` 查看状态）
2. **MCP 密钥**（仅当使用 supermemory MCP）：`export SUPERMEMORY_API_KEY=<你的 token>`，
   写入 `~/.bashrc` / `~/.zshrc` 持久化

## 参考环境

| 项目 | 值 |
|---|---|
| Pi | `1.2.0`（自管理安装：`~/.pi/agent/install/releases/`，入口 `~/.local/bin/pi`） |
| Node.js | v24.14.0 |
| 配置目录 | `~/.pi/agent` |
| 技能目录 | `~/.agents/skills`（软链到 `~/.pi/agent/skills/`） |
| 快照日期 | 2026-10-13 |

## 仓库内容 → 恢复位置

| 仓库路径 | 恢复目标 | 说明 |
|---|---|---|
| `agent/settings.json` | `~/.pi/agent/settings.json` | 主题、默认模型、packages 声明 |
| `agent/open-tui.json` | `~/.pi/agent/open-tui.json` | pi-open-tui 配置 |
| `agent/mcp.example.json` | `~/.pi/agent/mcp-adapter.json`（仅当不存在） | 脱敏示例，token 走环境变量 `SUPERMEMORY_API_KEY` |
| `agent/lazy.json` | `~/.pi/agent/lazy.json` | pi-lazy 懒加载规格 |
| `agent/hermes-memory-config.json` | `~/.pi/agent/hermes-memory-config.json` | pi-hermes-memory 模型覆盖 |
| `agent/themes/*.json` | `~/.pi/agent/themes/` | 自定义主题 my-dark / my-light |
| `agent/extensions/effort.ts` | `~/.pi/agent/extensions/` | 自定义 `/effort` 扩展 |
| `agent/npm/package.json`、`package-lock.json` | 不直接复制 | 版本记录，`pi install` 会重新生成 |
| `skills/<name>/` | `~/.agents/skills/<name>/` + 软链到 `~/.pi/agent/skills/` | 随仓库跟踪的技能（当前为 slidev） |

## 已安装 packages（`agent/settings.json` 声明，bootstrap 自动 `pi install`）

| 来源 | 版本 |
|---|---|
| `npm:@smoose/pi-beautify` | 0.1.9 |
| `npm:pi-open-tui` | 0.3.11 |
| `npm:pi-mcp-adapter` | 5.2.0 |
| `npm:pi-web-access` | 0.39.0 |
| `npm:pi-subagents` | 0.77.0 |
| `npm:pi-background-tasks` | 2.6.9 |
| `npm:pi-cache-optimizer` | 2.8.24 |
| `npm:pi-markdown-preview` | 0.21.4 |
| `npm:@juicesharp/rpiv-todo` | 2.13.8 |
| `npm:pi-hermes-memory` | 0.9.10 |
| `npm:pi-loop` | 0.1.5 |
| `npm:@narumitw/pi-goal` | 0.54.11 |
| `npm:pi-notify` | 1.4.0（对象形式，`extensions: []`） |
| `git:github.com/DietrichGebert/ponytail` | 70d0065 (2026-10-13) |
| `npm:@firstpick/pi-extension-safety-guard` | 0.3.2 |
| `npm:@firstpick/pi-extension-reverse-last` | 0.2.2 |
| `npm:@rahularya01/pi-lazy` | 0.3.1 |
| `npm:pi-tool-search` | 0.3.6 |
| `npm:@blueocean223/pi-provider` | 0.2.1 |
| `npm:pi-terminal-signals` | 0.1.0 |

`settings.json` 同时声明 `"extensions": ["-builtin:mcp"]`：内置 MCP 由 `pi-mcp-adapter` 接管。
`pi-lens` 已不再直接安装，改为 `agent/lazy.json` 中的懒加载规格（按需触发）。

`bootstrap.sh` 按包名重新安装，会解析各包当前可用版本；如需严格锁定版本，可手动执行
`cd ~/.pi/agent/npm && npm ci`（lock 文件已随仓库提供）。

## 脚本

| 脚本 | 作用 |
|---|---|
| `bootstrap.sh` | 新机器一键恢复：安装 pi → 重装 packages → 拷贝配置 → 恢复技能 |
| `sync.sh` | 把本机配置反向同步回仓库：拷贝 → 密钥扫描 → commit（不 push） |

`sync.sh` 会在 commit 前扫描 `sk-`、`ghp_`、`AKIA`、私钥头、`bearerToken`、`apiKey`、
`password` 等常见密钥形态，命中疑似 secret 直接中止。

## 安全

- 仓库不包含任何真实凭据：`agent/mcp.example.json` 只引用环境变量 `SUPERMEMORY_API_KEY`，
  恢复后需自行注入。
- `.gitignore` 已覆盖凭据、缓存、日志与 `node_modules`；提交前仍建议检查一遍 `git status`。

## 用作自己的配置模板

这是一个个人配置仓库，可以直接 fork 后改成自己的：

1. 修改 `agent/settings.json` 中的 packages、主题与默认模型
2. 按需增删 `agent/`、`skills/` 下的文件，调整 `agent/mcp.example.json`
3. 在你的机器上运行 `bash sync.sh` 采集配置，确认后 `git push`
