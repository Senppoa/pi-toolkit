# pi-toolkit

个人 **Pi Agent**（pi coding agent）配置仓库：在任何 Linux / WSL 终端上尽量一键恢复完整环境。
采用「配置声明 + 自动重装依赖」模式，不备份整个 `~/.pi`，也不包含任何密钥。

## 快速恢复（新机器）

```bash
git clone https://github.com/Senppoa/pi-toolkit.git ~/pi-toolkit
cd ~/pi-toolkit
bash bootstrap.sh
```

之后只需：

1. 认证：运行 `pi` 完成 OAuth 登录，或设置对应 provider 的 API Key（`pi auth status` 可查看状态）
2. MCP 密钥：`export SUPERMEMORY_API_KEY=<你的 token>`（写入 `~/.bashrc` / `~/.zshrc` 持久化）

## 本机采集信息

| 项目 | 值 |
|---|---|
| Pi 版本 | `0.85.1` |
| 安装方式 | `npm install -g @earendil-works/pi-coding-agent`（Node v24.14.0，nvm 管理） |
| 配置目录 | `~/.pi/agent` |
| 技能目录 | `~/.agents/skills`（由 `~/.pi/agent/skills/*` 符号链接引用） |
| 依赖快照日期 | 2026-09-16 |

## 仓库内容 → 恢复位置

| 仓库路径 | 恢复目标 | 说明 |
|---|---|---|
| `agent/settings.json` | `~/.pi/agent/settings.json` | 主题、默认模型、packages 声明 |
| `agent/open-tui.json` | `~/.pi/agent/open-tui.json` | pi-open-tui 配置 |
| `agent/mcp.example.json` | `~/.pi/agent/mcp.json`（仅当不存在） | 已脱敏，token 走环境变量 |
| `agent/themes/*.json` | `~/.pi/agent/themes/` | 自定义主题 my-dark / my-light |
| `agent/extensions/effort.ts` | `~/.pi/agent/extensions/` | 自定义 `/effort` 扩展 |
| `agent/npm/package.json`、`package-lock.json` | 不直接复制 | 仅作版本记录，`pi install` 会重新生成 |
| `skills/<name>/` | `~/.agents/skills/<name>/` + 软链到 `~/.pi/agent/skills/` | slidev（其余技能有意不追踪，见下表） |

## 已安装 packages（`agent/settings.json` 声明，bootstrap 自动 `pi install`）

| 来源 | 版本 |
|---|---|
| `npm:@smoose/pi-beautify` | 0.1.9 |
| `npm:pi-open-tui` | 0.3.5 |
| `npm:pi-mcp-adapter` | 2.33.0 |
| `npm:pi-web-access` | 0.29.0 |
| `npm:pi-subagents` | 0.67.0 |
| `npm:pi-background-tasks` | 2.5.0 |
| `npm:pi-cache-optimizer` | 2.8.10 |
| `npm:pi-markdown-preview` | 0.16.0 |
| `npm:pi-lens` | 4.1.6 |
| `npm:@juicesharp/rpiv-todo` | 2.10.1 |
| `npm:pi-hermes-memory` | 0.9.9 |
| `npm:pi-loop` | 0.1.5 |
| `npm:@narumitw/pi-goal` | 0.54.4 |
| `npm:pi-notify` | 1.4.0 |
| `git:github.com/DietrichGebert/ponytail` | 356918e (2026-09-07) |

`bootstrap.sh` 按包名重新安装，会解析各包当前可用版本；如需严格锁定版本，可手动执行
`cd ~/.pi/agent/npm && npm ci`（lock 文件已随仓库提供备份）。

## 明确排除的内容（不会上传）

| 内容 | 原因 |
|---|---|
| `auth.json` | OAuth / provider 凭据 |
| `mcp.json`（真实 token） | 含 bearer token；仓库只提供 `mcp.example.json` |
| `.env`、`*.key`、`*.pem`、private key | 密钥类文件 |
| `sessions/`、`tasks/`、`logs/`、`fff/`、`web-search-cache/`、`mcp-cache.json`、`trust.json` | 会话、运行日志与缓存，机器相关 |
| `node_modules/`、`~/.pi/agent/npm/`（node_modules）、`~/.pi/agent/git/` 源码 | 第三方依赖，可重新安装 |
| `~/.pi/agent/bin/{fd,rg}` | 预编译二进制，由系统包或 pi 自行获取 |
| `pi-hermes-memory/`、`projects-memory/` | 个人记忆数据（约 6.5MB，含个人笔记），非配置；如需迁移请另行手动备份 |
| `models-store.json`、`models.json` | 模型目录缓存，`pi update` 自动刷新 |
| `extensions/pi-permission-system/` | 仅含日志，无代码 |
| `skills/{codex-prove,rendercv,sol-control}/` | 本机保留但不追踪；`sync.sh` 中 `SKIP_SKILLS` 显式跳过 |

## 日常同步

```bash
cd ~/pi-toolkit
bash sync.sh     # 拉取本机配置 → 仓库 → 敏感扫描 → commit（不 push）
git push         # 确认无误后手动推送
```

`sync.sh` 会在 commit 前用正则扫描常见密钥形态（`sk-`、`ghp_`、`AKIA`、私钥头、
`bearerToken`、`apiKey`、`password` 等），发现疑似 secret 直接中止。

## 安全说明

- 仓库从未包含真实 token；`mcp.example.json` 使用 pi-mcp-adapter 支持的
  `bearerTokenEnv`，从环境变量 `SUPERMEMORY_API_KEY` 读取密钥。
- 由于历史配置曾以明文形式存在于本机 `~/.pi/agent/mcp.json`，若该 token 曾外泄，
  建议到 supermemory 控制台轮换一次。
- `.gitignore` 已覆盖凭据、缓存、日志、`node_modules`，但仍建议每次 push 前过一眼 `git status`。
