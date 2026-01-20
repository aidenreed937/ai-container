# ai-container

一个配置完善的 AI 全栈开发容器环境，集成了 OpenAI Codex、Google Gemini、Anthropic Claude Code 等常用 AI CLI 工具。

## 📋 项目简介

本项目提供了一个开箱即用的 Dev Container 开发环境,专为 AI 辅助开发设计。通过 Docker 容器化技术,确保开发环境的一致性和可移植性。

## 🚀 功能特性

- **预配置的 Node.js 环境**:  基于 Microsoft 官方的 Node.js 20 开发容器镜像
- **AI 工具集成**: 
  - OpenAI Codex CLI (`@openai/codex`)
  - Google Gemini CLI (`@google/gemini-cli`)
  - Claude Code (`@anthropic-ai/claude-code`)
- **VS Code 优化配置**:
  - ESLint 代码检查
  - Prettier 代码格式化
  - Material Icon 主题
  - Zsh 默认终端
- **端口转发**: 自动转发 3000 端口用于 Web 开发
- **持久化配置**: AI 工具配置文件挂载到本地,数据不丢失
- **自动示例项目**: 容器初始化后会运行最新的 bootstrap prompt（默认提供 React + TypeScript + Vite 示例，需设置 `AI_CONTAINER_CODEX_API_KEY`）

## 🛠️ 环境要求

- [Docker](https://www.docker.com/products/docker-desktop)
- [Visual Studio Code](https://code.visualstudio.com/)
- [Dev Containers 扩展](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)

## 📦 快速开始

1. **克隆仓库**
   ```bash
   git clone https://github.com/aidenreed937/ai-container.git
   cd ai-container
   ```

2. **配置环境变量**
   
   推荐使用 **宿主机环境变量**（不落盘到仓库），并使用统一前缀避免与宿主机现有变量冲突；Dev Container 会将其注入容器环境（映射为工具可识别的标准变量名）：
   - `AI_CONTAINER_CODEX_API_KEY`
   - `AI_CONTAINER_GEMINI_API_KEY`（可选：`AI_CONTAINER_GOOGLE_GEMINI_BASE_URL`）
   - `AI_CONTAINER_ANTHROPIC_API_KEY`（可选：`AI_CONTAINER_ANTHROPIC_BASE_URL`）

   如需“无人值守”（减少/避免交互确认），可在宿主机额外设置：
   - `AI_CONTAINER_UNATTENDED=1`
   - `AI_CONTAINER_CLAUDE_UNATTENDED_FLAGS` / `AI_CONTAINER_CODEX_UNATTENDED_FLAGS` / `AI_CONTAINER_GEMINI_UNATTENDED_FLAGS`（参考 `.devcontainer/.env.example`）

   快速初始化（会写入宿主机的持久化 env 文件，并自动在你的 shell rc 中 source；可重复运行覆盖更新）：
   ```bash
   ./scripts/init-host-env.sh
   ```
   Fish 用户：
   ```bash
   ./scripts/init-host-env.fish
   ```

   “主控分发提示词”（由宿主机决定要让容器内 Codex 执行什么）：
   - 默认：不设置任何 `AI_CONTAINER_BOOTSTRAP_*` 时，会从 `.devcontainer/prompts/` 读取**最新的** `*.txt` 并执行一次（记录在 `/home/node/.codex/bootstrap.last`）
   - 覆盖：`AI_CONTAINER_BOOTSTRAP_PROFILE=<name>`（使用 `.devcontainer/prompts/<name>.txt`）
   - 覆盖：`AI_CONTAINER_BOOTSTRAP_PROMPT_FILE=/path/to/prompt.txt`
   - 覆盖：`AI_CONTAINER_BOOTSTRAP_PROMPT=...`（短提示词）

3. **在容器中打开**
   
   - 在 VS Code 中打开项目文件夹
   - 按 `F1` 或 `Ctrl+Shift+P` (Mac: `Cmd+Shift+P`)
   - 选择 **"Dev Containers: Reopen in Container"**
   - 等待容器构建和初始化完成

4. **开始开发**
   
   容器启动后,所有工具将自动安装配置完成,您可以立即开始使用 AI 辅助开发功能。

## 📁 项目结构

```
ai-container/
├── .devcontainer/          # Dev Container 配置目录
│   ├── devcontainer.json   # 容器配置文件
│   ├── .env.example        # 环境变量示例
│   └── .env                # 环境变量配置 (需自行创建)
├── .gitignore             # Git 忽略文件配置
├── demo/                  # 示例代码目录
├── scripts/               # 工具脚本
│   ├── ai                 # 统一入口（可附加无人值守 flags）
│   └── init-host-env.sh   # 初始化宿主机持久化环境变量
└── README.md              # 项目说明文档
```

## 🔧 配置说明

### Dev Container 配置

- **基础镜像**: `mcr.microsoft.com/devcontainers/javascript-node:1-20`
- **默认用户**: `node`
- **默认端口**: `3000`
- **数据挂载**: 
  - `.codex` → `/home/node/.codex`
  - `.gemini` → `/home/node/.gemini`
  - `.claude` → `/home/node/.claude`

### VS Code 扩展

容器会自动安装以下扩展: 
- **ESLint**: JavaScript 代码质量检查
- **Prettier**: 代码格式化工具
- **Material Icon Theme**: 文件图标美化

### Codex Provider（env_key 推荐写法）

建议在 Codex 的 provider 配置中使用容器内标准变量名，例如：
- `env_key = "CODEX_API_KEY"`

并在宿主机仅设置带前缀的变量（避免冲突）：
- `AI_CONTAINER_CODEX_API_KEY=...`

仓库提供示例文件：`.codex/config.toml.example`（可按需复制为 `.codex/config.toml`）。

## 💡 使用建议

1. 优先用宿主机环境变量（`AI_CONTAINER_*`）管理 API 密钥，不落盘到仓库
2. `.codex`、`.gemini`、`.claude` 目录用于存储 AI 工具的配置和缓存,已添加到 `.gitignore`
3. 可以在 `demo/` 目录下创建测试和示例代码
4. 根据项目需求,可以在 `devcontainer.json` 中添加更多 VS Code 扩展
5. 建议用 `scripts/ai` 运行三方 CLI（可统一“无人值守” flags）：`scripts/ai codex ...` / `scripts/ai gemini ...` / `scripts/ai claude ...`
6. 容器初始化后会把工作区 `bin/` 加入 `PATH`，`codex`/`gemini`/`claude` 默认会走本仓库的 shim（内部转到 `scripts/ai`），从而自动套用无人值守 flags（由 `AI_CONTAINER_UNATTENDED` 控制）

## 🤝 贡献

欢迎提交 Issue 和 Pull Request 来改进这个项目!

## 📄 许可证

本项目使用 MIT 许可证 - 详见 [LICENSE](LICENSE) 文件

## 🔗 相关链接

- [Dev Containers 文档](https://code.visualstudio.com/docs/devcontainers/containers)
- [OpenAI API 文档](https://platform.openai.com/docs)
- [Google Gemini API 文档](https://ai.google.dev/docs)
