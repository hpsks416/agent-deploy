#!/usr/bin/env bash
# demo.sh — agent-deploy 五分钟跑通 demo
# 跑一遍：依赖检查 → 部署预览 → 评估体检 → 安全扫描，全绿即框架可用。
# 用法（在 agent-deploy 仓库根目录）：bash demo.sh
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"
PY=python3
command -v python3 >/dev/null 2>&1 || PY=python

PASS=0; FAIL=0
ok()  { echo "  ✓ $1"; PASS=$((PASS+1)); }
bad() { echo "  ✗ $1"; FAIL=$((FAIL+1)); }

echo "============================================================"
echo " agent-deploy 五分钟 demo"
echo "============================================================"

echo ""
echo "[1/4] 依赖检查"
for c in git "$PY"; do
  command -v "$c" >/dev/null 2>&1 && ok "$c" || bad "缺 $c"
done

echo ""
echo "[2/4] 部署（--dry-run 预览，不实际写入）"
if ./deploy.sh --framework dsh --dry-run >/dev/null 2>&1; then
  ok "deploy.sh 可跑"
else
  bad "deploy.sh 报错"
fi

echo ""
echo "[3/4] skill-evaluator 静态体检（secret-scan）"
if "$PY" skills/skill-evaluator/scripts/static_check.py --skill skills/secret-scan >/dev/null 2>&1; then
  ok "static_check 跑通"
else
  bad "static_check 报错"
fi

echo ""
echo "[4/4] secret-scan 检出假密钥（fixtures/leaky）"
if "$PY" skills/secret-scan/scripts/scan_secrets.py --local skills/secret-scan/fixtures/leaky 2>/dev/null | grep -q "!"; then
  ok "检出假密钥"
else
  bad "未检出假密钥"
fi

echo ""
echo "============================================================"
echo " demo 结果: $PASS pass / $FAIL fail"
if [ "$FAIL" -eq 0 ]; then
  echo " 全绿 ✓ — 框架可用，下一步：./deploy.sh --framework <codex|claude|dsh>"
else
  echo " 有失败 ✗ — 检查上面的报错"
fi
echo "============================================================"
exit "$FAIL"
