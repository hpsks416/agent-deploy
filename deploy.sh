#!/usr/bin/env bash
# ============================================================================
# agent-deploy —— AGENT 框架跨框架部署器（bash 版）
# 移植自 deploy.ps1：换框架 / 换中间商 / 换模型，一键铺到位。Mac/Linux/Windows 通用。
#
# 用法（在 agent-deploy 仓库根目录运行）：
#   ./deploy.sh --framework codex --provider commandcode --model deepseek-v4-pro
#   ./deploy.sh --framework claude --provider deepseek --model deepseek-flash
#   ./deploy.sh --framework dsh    --provider commandcode
#   ./deploy.sh --framework codex --source gitee --owner <你的账号>
#   ./deploy.sh --framework codex --dry-run
#
# 三个维度独立可换：
#   --framework  codex | claude | dsh        （框架）
#   --provider   providers.json 里的任意键   （中间商）
#   --model      该中间商 models 里的任意别名 （模型）
#
# 说明：codex 的 auth 命令按 OS 自动选 sh(Unix)/powershell(Windows)；
#       claude 的 env 文件按 OS 生成 .sh(Unix)/.ps1(Windows)。
# ============================================================================

set -u

# ---------- 参数解析 ----------
FRAMEWORK="codex"
PROVIDER="commandcode"
MODEL=""
SOURCE="github"
OWNER="${OWNER:-}"
SKIP_SKILLS=0
SKIP_CONFIG=0
DRY_RUN=0

while [ $# -gt 0 ]; do
  case "$1" in
    --framework) FRAMEWORK="$2"; shift 2 ;;
    --provider)  PROVIDER="$2";  shift 2 ;;
    --model)     MODEL="$2";     shift 2 ;;
    --source)    SOURCE="$2";    shift 2 ;;
    --owner)     OWNER="$2";     shift 2 ;;
    --skip-skills) SKIP_SKILLS=1; shift ;;
    --skip-config) SKIP_CONFIG=1; shift ;;
    --dry-run)   DRY_RUN=1;      shift ;;
    -h|--help)
      echo "用法: ./deploy.sh --framework codex|claude|dsh [--provider <key>] [--model <alias>] [--source github|gitee] [--owner <账号>] [--skip-skills] [--skip-config] [--dry-run]"
      exit 0 ;;
    *) echo "未知参数: $1（--help 看用法）" >&2; exit 2 ;;
  esac
done

SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROVIDERS_JSON="$SCRIPT_ROOT/providers.json"
CORE_SKILLS="$SCRIPT_ROOT/core-skills.txt"

# python3 优先，退回 python（解析 JSON 零新增依赖）
PY=python3
command -v python3 >/dev/null 2>&1 || PY=python

case "$FRAMEWORK" in
  codex|claude|dsh) ;;
  *) echo "x 未知框架 '$FRAMEWORK'（可用: codex claude dsh）" >&2; exit 1 ;;
esac
case "$SOURCE" in
  github|gitee) ;;
  *) echo "x 未知源 '$SOURCE'（可用: github gitee）" >&2; exit 1 ;;
esac

# ---------- 1. 解析 providers.json ----------
jget() {
  "$PY" - "$PROVIDERS_JSON" "$PROVIDER" "$1" "${2:-}" <<'PY'
import json, sys
path, pkey, field, model = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
p = json.load(open(path, encoding="utf-8")).get(pkey)
if p is None:
    sys.exit(1)
if model:
    print(p.get("models", {}).get(model, "") or "")
else:
    print(p.get(field, "") or "")
PY
}

PNAME=$(jget name)
if [ -z "$PNAME" ]; then
  echo "x 未知中间商 '$PROVIDER'（可用键见 providers.json）" >&2
  exit 1
fi
if [ -z "$MODEL" ]; then MODEL=$(jget default_model); fi
MODEL_ID=$(jget models "$MODEL")
if [ -z "$MODEL_ID" ]; then
  echo "x 中间商 '$PROVIDER' 无模型 '$MODEL'" >&2
  exit 1
fi
OPENAI_BASE=$(jget openai_base_url)
ANTHROPIC_BASE=$(jget anthropic_base_url)
API_KEY_ENV=$(jget api_key_env)

# ---------- 2. 框架目录映射 ----------
HOME_DIR="${HOME:-$HOME}"
OS_KIND="$(uname -s 2>/dev/null || echo Windows)"
case "$OS_KIND" in
  Windows*|MINGW*|MSYS*|CYGWIN*) IS_WINDOWS=1 ;;
  *) IS_WINDOWS=0 ;;
esac

case "$FRAMEWORK" in
  codex)  SKILLS_DIR="$HOME_DIR/.codex/skills";  INSTR_PATH="$HOME_DIR/.codex/AGENTS.md";  CFG_PATH="$HOME_DIR/.codex/config.toml" ;;
  claude) SKILLS_DIR="$HOME_DIR/.claude/skills"; INSTR_PATH="$HOME_DIR/.claude/CLAUDE.md"; CFG_PATH="$HOME_DIR/.claude/claude-env.$([ "$IS_WINDOWS" = 1 ] && echo ps1 || echo sh)" ;;
  dsh)    SKILLS_DIR="$HOME_DIR/.dsh/skills";    INSTR_PATH="$HOME_DIR/.dsh/AGENTS.md";    CFG_PATH="$HOME_DIR/.dsh/settings.yaml" ;;
esac

echo ""
echo "============================================================"
echo " agent-deploy  框架=$FRAMEWORK  中间商=$PNAME  模型=$MODEL ($MODEL_ID)  源=$SOURCE"
echo " skill 目录 : $SKILLS_DIR"
echo " 指令文件   : $INSTR_PATH"
echo " 配置文件   : $CFG_PATH"
[ "$DRY_RUN" = 1 ] && echo " [DRY RUN] 只预览，不实际写入"
echo "============================================================"

TS=$(date +%Y%m%d-%H%M%S)
BACKUP_ROOT="$HOME_DIR/.agent-deploy_backup_$TS"

# ---------- 3. 铺 skill ----------
if [ "$SKIP_SKILLS" = 0 ]; then
  echo ""
  echo "[1/3] 铺核心 skill"
  mkdir -p "$SKILLS_DIR"
  ok=0; skip=0; fail=0
  while IFS= read -r line; do
    case "$line" in ''|\#*) continue ;; esac
    name=$(printf '%s' "$line" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $1); print $1}')
    coupling=$(printf '%s' "$line" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print $2}')
    [ -z "$name" ] && continue
    dst="$SKILLS_DIR/$name"
    if [ -f "$dst/SKILL.md" ]; then
      echo "  [已存在] $name"; skip=$((skip+1)); continue
    fi
    if [ -z "$OWNER" ]; then
      echo "  [FAIL] $name：未指定 owner（--owner 或 OWNER 环境变量）"; fail=$((fail+1)); continue
    fi
    if [ "$SOURCE" = "github" ]; then url="https://github.com/$OWNER/$name.git"; else url="https://gitee.com/$OWNER/$name.git"; fi
    if [ "$DRY_RUN" = 1 ]; then
      echo "  [DRY] git clone --depth 1 $url -> $dst"; ok=$((ok+1)); continue
    fi
    if git clone --depth 1 "$url" "$dst" >/dev/null 2>&1 && [ -f "$dst/SKILL.md" ]; then
      echo "  [OK] $name"; ok=$((ok+1))
    else
      echo "  [FAIL] $name"; fail=$((fail+1))
    fi
  done < "$CORE_SKILLS"
  echo "  结果: 安装 $ok / 已存在 $skip / 失败 $fail"
else
  echo ""
  echo "[1/3] 跳过 skill 铺放（--skip-skills）"
fi

# ---------- 4 & 5. 铺铁律 + 生成配置 ----------
if [ "$SKIP_CONFIG" = 0 ]; then
  echo ""
  echo "[2/3] 铺铁律"
  if [ -f "$INSTR_PATH" ] && [ "$DRY_RUN" = 0 ]; then
    mkdir -p "$BACKUP_ROOT"
    cp "$INSTR_PATH" "$BACKUP_ROOT/$(basename "$INSTR_PATH")"
    echo "  备份旧指令 -> $BACKUP_ROOT"
  fi
  if [ "$DRY_RUN" = 1 ]; then
    echo "  [DRY] 写 $INSTR_PATH"
  else
    mkdir -p "$(dirname "$INSTR_PATH")"
    cp "$SCRIPT_ROOT/templates/agents-core.md" "$INSTR_PATH"
    echo "  已写 $INSTR_PATH"
  fi

  echo ""
  echo "[3/3] 生成中间商/模型配置"
  CFG_TEXT=""
  if [ "$FRAMEWORK" = "codex" ]; then
    if [ "$IS_WINDOWS" = 1 ]; then
      AUTH_CMD="powershell"
      AUTH_ARGS="[\"-NoProfile\", \"-Command\", \"Write-Output \$env:${API_KEY_ENV}\"]"
    else
      AUTH_CMD="sh"
      AUTH_ARGS="[\"-c\", \"echo \$${API_KEY_ENV}\"]"
    fi
    CFG_TEXT=$(printf '%s\n' \
      "# 由 agent-deploy 生成 | 框架: codex | 中间商: $PNAME | 模型: $MODEL" \
      "model = \"$MODEL_ID\"" \
      "model_provider = \"$PROVIDER\"" \
      "model_reasoning_effort = \"high\"" \
      "" \
      "[model_providers.$PROVIDER]" \
      "name = \"$PNAME\"" \
      "base_url = \"$OPENAI_BASE\"" \
      "wire_api = \"responses\"" \
      "" \
      "[model_providers.$PROVIDER.auth]" \
      "command = \"$AUTH_CMD\"" \
      "args = $AUTH_ARGS")
  elif [ "$FRAMEWORK" = "claude" ]; then
    if [ -z "$ANTHROPIC_BASE" ]; then
      echo "  x 中间商 '$PROVIDER' 无 Anthropic 端点，不支持 Claude Code。请在 providers.json 补 anthropic_base_url。" >&2
    elif [ "$IS_WINDOWS" = 1 ]; then
      CFG_TEXT=$(printf '%s\n' \
        "# 由 agent-deploy 生成 | 框架: claude | 中间商: $PNAME | 模型: $MODEL" \
        "# 用法: & \"<本文件路径>\"   或   加入 PowerShell \$PROFILE" \
        "\$env:ANTHROPIC_BASE_URL = \"$ANTHROPIC_BASE\"" \
        "\$env:ANTHROPIC_AUTH_TOKEN = \$env:${API_KEY_ENV}" \
        "\$env:ANTHROPIC_MODEL = \"$MODEL_ID\"" \
        "\$env:ANTHROPIC_DEFAULT_OPUS_MODEL = \"$MODEL_ID\"" \
        "\$env:ANTHROPIC_DEFAULT_SONNET_MODEL = \"$MODEL_ID\"" \
        "\$env:ANTHROPIC_DEFAULT_HAIKU_MODEL = \"$MODEL_ID\"" \
        "\$env:CLAUDE_CODE_SUBAGENT_MODEL = \"$MODEL_ID\"" \
        "\$env:CLAUDE_CODE_EFFORT_LEVEL = \"max\"")
    else
      CFG_TEXT=$(printf '%s\n' \
        "# 由 agent-deploy 生成 | 框架: claude | 中间商: $PNAME | 模型: $MODEL" \
        "# 用法: source <本文件路径>   或   加入 shell 启动脚本" \
        "export ANTHROPIC_BASE_URL=\"$ANTHROPIC_BASE\"" \
        "export ANTHROPIC_AUTH_TOKEN=\"\$${API_KEY_ENV}\"" \
        "export ANTHROPIC_MODEL=\"$MODEL_ID\"" \
        "export ANTHROPIC_DEFAULT_OPUS_MODEL=\"$MODEL_ID\"" \
        "export ANTHROPIC_DEFAULT_SONNET_MODEL=\"$MODEL_ID\"" \
        "export ANTHROPIC_DEFAULT_HAIKU_MODEL=\"$MODEL_ID\"" \
        "export CLAUDE_CODE_SUBAGENT_MODEL=\"$MODEL_ID\"" \
        "export CLAUDE_CODE_EFFORT_LEVEL=\"max\"")
    fi
  elif [ "$FRAMEWORK" = "dsh" ]; then
    CFG_TEXT=$(printf '%s\n' \
      "# 由 agent-deploy 生成 | 框架: dsh | 中间商: $PNAME | 模型: $MODEL" \
      "llm-pi-ai:" \
      "  providers:" \
      "    $PROVIDER:" \
      "      displayName: $PNAME" \
      "      api: openai-completions" \
      "      baseURL: $OPENAI_BASE" \
      "      apiKeyEnv: $API_KEY_ENV" \
      "      models:" \
      "        - id: $MODEL_ID" \
      "agent-default-model:" \
      "  provider: $PROVIDER" \
      "  model: $MODEL_ID" \
      "  reasoningEffort: high")
  fi

  if [ -n "$CFG_TEXT" ]; then
    if [ -f "$CFG_PATH" ] && [ "$DRY_RUN" = 0 ]; then
      mkdir -p "$BACKUP_ROOT"
      cp "$CFG_PATH" "$BACKUP_ROOT/$(basename "$CFG_PATH")"
      echo "  备份旧配置 -> $BACKUP_ROOT"
    fi
    if [ "$DRY_RUN" = 1 ]; then
      echo "  [DRY] 写 $CFG_PATH"
      printf '%s\n' "$CFG_TEXT" | sed 's/^/    /'
    else
      mkdir -p "$(dirname "$CFG_PATH")"
      printf '%s\n' "$CFG_TEXT" > "$CFG_PATH"
      echo "  已写 $CFG_PATH"
    fi
  fi
else
  echo ""
  echo "[2/3][3/3] 跳过铁律 + 配置（--skip-config）"
fi

# ---------- 6. 框架耦合清单 ----------
echo ""
echo "框架耦合清单（换框架后需人工核对，详见 FRAMEWORK-COUPLING.md）："
coupled=0
while IFS= read -r line; do
  case "$line" in ''|\#*) continue ;; esac
  name=$(printf '%s' "$line" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $1); print $1}')
  coupling=$(printf '%s' "$line" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print $2}')
  if [ "$coupling" != "none" ] && [ -n "$coupling" ]; then
    printf '  [%-8s] %s\n' "$coupling" "$name"
    coupled=$((coupled+1))
  fi
done < "$CORE_SKILLS"
[ "$coupled" = 0 ] && echo "  （本清单全部框架无关）"

echo ""
echo "============================================================"
echo " 完成。（备份目录: $BACKUP_ROOT，如有旧文件）"
echo " 换框架后请按 FRAMEWORK-COUPLING.md 核对轻/重耦合 skill。"
echo "============================================================"
