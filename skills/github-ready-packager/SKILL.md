---
name: github-ready-packager
description: 将本地项目整理为可直接提交 GitHub 的独立项目：补齐 .gitignore/README/依赖清单与启动脚本，排除密钥和大文件，校验后打成 zip（可选初始化 git 仓库）。适用于“打包/整理成 GitHub 项目、提交 GitHub”类请求，不用于普通代码编辑或提交后的 Git 操作。
---

# GitHub Ready Packager

把一个已有本地项目收敛成独立、干净、可直接 `git push` 或交给 GitHub 的项目。默认只准备“独立目录 + zip”，不擅自提交。

## 工作流程

1. **清点与收敛**：把要发布的代码放进一个独立目录；排除运行时产物（`__pycache__`、`.venv`、`out/`、`output/`、分轨输出等）、密钥、凭证、大二进制和测试临时文件。
2. **补齐 GitHub 必备文件**：
   - `.gitignore`：输出目录、`__pycache__/`、`*.pyc`、`.venv/`、`venv/`、`*.zip`（视项目需要）、`.env`、密钥文件。
   - 依赖清单：Python 用 `requirements.txt` 或 `pyproject.toml`，Node 用 `package.json`；标注“仅某功能需要”的可选依赖。
   - `README.md`：**开头先给「人话版总体介绍」三要素**——① 项目内容（一句话/一段人话说明这是什么、解决什么问题，不要用英文触发描述开头）；② 环境依赖（部署环境：操作系统 / 第三方软件 / 运行时）；③ 目录结构（放开头、安装之前）。然后才是环境要求、安装、快速开始（GUI/CLI）、参数表、输出结构、已知限制、免责声明、License 说明。
   - `LICENSE`：默认只在 README 写“许可证待定”，不替用户选；用户明确指定 MIT/GPL-3.0 等后再落 LICENSE 文件。
   - 启动脚本：Windows GUI 工具补 `start.cmd`；带浏览器界面时补 `index.html` + 本地 `server.py`。
3. **校验**：
   - Python：`python -m py_compile <file>...`
   - PowerShell：`[System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path '.\x.ps1'), [ref]$null, [ref]$null) | Out-Null`
   - HTTP 服务：用同进程 `ThreadingHTTPServer` + `urllib` 做最小烟测，不要直接跑 `main()`，避免触发 `webbrowser.open`。
   - Windows `.cmd`：写成 CRLF，避免双击启动时的行尾问题。
4. **打包**：`python scripts/package_for_github.py --src <dir> --out <dir>.zip`，按排除规则逐文件写入。
5. **交付**：报告“项目目录路径 + zip 路径 + 已验证项”，并提示（不执行）后续 `git init`/push 的下一步。

## 本环境的关键约束

- 文件编辑用 `apply_patch`；在 PowerShell 里一次 `exec_command` 只放一个 `apply_patch` 块，多个 heredoc 块会触发 PowerShell 解析错误。
- 清理文件用 `Remove-Item -LiteralPath <单个文件>`，先确认路径在目标范围内；不要用 `Remove-Item -Recurse -Force` 递归删除，沙箱可能自动拒绝。
- 打包用本 skill 的脚本，不要用 `Compress-Archive` 或 `ZipFile.CreateFromDirectory`，避免把 `__pycache__`、临时文件一起打进去。
- 文件改动后重建 zip，别留下旧包。

## 边界

- “打包”不等于“提交”。除非用户明确要求，否则不要 `git init`、`git commit`、`git push`；准备好目录/zip 后告诉用户下一步即可。
- 不包含密钥、`.env`、凭证、个人数据、受版权内容或大二进制；发现时提醒用户，而不是默默打包。
- 不替用户决定开源协议；默认“许可证待定”。
