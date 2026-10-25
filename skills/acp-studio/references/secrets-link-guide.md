# secrets-link 加密存储完整指南

> secrets-link 面板 + 三层加密链（age 密文 + AES 备份 + zip 标记）的完整操作手册。

## 一、依赖

- `age` 二进制：本机在 `G:\CodexDS\DSH\INTRO\age\age\age.exe`（`age-keygen.exe` 同目录）。
- Python + `cryptography`（本机已装 50.0.1，无需 pip）。
- 面板：`node` 起 `secrets-link-web.mjs`（**必须在沙箱外跑**，沙箱内 `execFileSync` 被命名管道 EPERM 挡）。

## 二、配置 links.json

`G:\CodexDS\DSH\INTRO\secrets-link\links.json`：

```json
{
  "workspaces": [
    {
      "name": "DSH 本机",
      "target": "C:\\Users\\Razer\\Documents\\Codex\\2026-09-20\\y\\acp-studio\\secrets.cmd",
      "age": {
        "bin": "G:\\CodexDS\\DSH\\INTRO\\age\\age\\age.exe",
        "identity": "C:\\Users\\Razer\\.dsh\\age-identity.txt"
      },
      "tokens": [
        { "var": "GITHUB_TOKEN", "file": "G:\\KEY\\GITHUB token\\416.txt.zip" },
        { "var": "COMMANDCODE_API_KEY", "file": "G:\\KEY\\DS\\commandcode\\416.txt.zip" }
      ],
      "extra": { "GITEE_USERNAME": "hpsks416" }
    }
  ],
  "active": 0
}
```

- `age.bin`：age.exe 全路径。
- `age.identity`：私钥文件（放 `~/.dsh` 而非 `G:\KEY`，G:\KEY 泄露时不连带私钥）。
- token `file` **必须是 `.zip`**（加密产物）；非 zip 面板拒绝生成 secrets.cmd。

## 三、生成私钥

```cmd
G:\CodexDS\DSH\INTRO\age\age\age-keygen.exe -o C:\Users\Razer\.dsh\age-identity.txt
```

输出记下 `Public key: age1...`（公钥，公开可分享）。私钥 `age-identity.txt` **单独保管**，泄露 = 全解密。

## 四、加密（面板一键）

1. 打开面板（沙箱外）：`node G:\CodexDS\DSH\INTRO\secrets-link\secrets-link-web.mjs`
2. 勾选要加密的 token → 点「🔒 加密选中」。
3. 自动三层加密，原明文删除：
   - `<file>.backup.enc` = AES-256-GCM 密文（密码 = 私钥，PBKDF2-SHA256 600k 次派生）
   - age 密文（公钥加密）
   - `<file>.zip` = 内含 age 密文（zip 密码 = 公钥，作「已加密」格式标记）

## 五、恢复 / 运行时解密

- **从 AES 备份恢复明文**（zip/age 密文损坏时）：
  `python decrypt-token.py <file>.backup.enc <identity> <out.txt>`
- **运行时解密**（secrets.cmd 的 `for /f` 用）：
  `python decrypt-runtime.py <file>.zip <age_bin> <identity>`
  输出明文到 stdout（解 zip → age 解密）。

## 六、多 AGENT 工作区

- 面板顶部下拉切换/新建工作区，各工作区独立 `target` + `tokens` + `age`。
- 换 token：重新走「加密选中」生成新 `.zip`，或改 token 的 `.zip` 路径。

## 七、安全模型（诚实）

| 层 | 保护 | 强度 |
|---|---|---|
| age 密文（zip 内） | 无私钥无法解 | X25519 + ChaCha20-Poly1305，**强** |
| AES 备份 `.backup.enc` | 无密码（私钥）无法解 | AES-256-GCM 认证，**强** |
| zip（外层） | zip 密码 = 公钥（**公开**） | **非安全加密**，只作格式标记（防误操作） |

- 私钥是**唯一主密钥**：丢了它，age 密文 + AES 备份同时报废。
- zip 的作用是「认得出加密没加密」（面板只认 zip），防的是「未加密就生成 secrets.cmd」，不是防泄露。

## 八、已知坑

- `for /f` 命令执行**路径不能含空格**（cmd 引号坑），含空格用 8.3 短路径。
- 面板必须在**沙箱外**跑（沙箱内 `execFileSync` 命名管道 EPERM）。
- `age-keygen` 会警告「writing secret key to a world-readable file」，单机可忽略（多用户机需收紧权限）。
- 加密前确认 `age.identity` 已配好，否则加密报「没找到 public key / 私钥」。

## 脚本清单

- `scripts/secrets-link/secrets-link-web.mjs` — 面板（多工作区 + 一键加密）。
- `scripts/secrets-link/encrypt-token.py` — 三层加密（AES 备份 + age + zip）。
- `scripts/secrets-link/decrypt-runtime.py` — 运行时解密（解 zip + age 解密）。
- `scripts/secrets-link/decrypt-token.py` — 从 AES 备份恢复明文。
