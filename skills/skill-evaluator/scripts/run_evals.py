#!/usr/bin/env python3
"""CI 版动态 evals：对单个 skill 的 evals.yaml 跑 A/B（with-skill vs without-skill）。

与 skill-evaluator 的「subagent A/B」不同：这里直接用 OpenAI 兼容 API 调模型，
只能判「最终答复」（无中间消息），用于 GitHub Actions 自动回归。
判定逻辑与 judge.py 的 run_checks 一致（contains/not_contains/regex/not_regex/json_schema）。

用法：
  python run_evals.py <skill_dir>

环境变量：
  EVAL_BASE_URL   OpenAI 兼容端点（如 https://api.commandcode.ai/provider/v1）
  EVAL_API_KEY    API key
  EVAL_MODEL      模型 id（如 deepseek/deepseek-v4-pro）

退出码：0 = 所有用例 with-skill 通过；1 = 有用例未通过。
"""
import json
import os
import re
import sys
import urllib.request
from pathlib import Path

try:
    import yaml
except ImportError:
    print("需要 pyyaml：pip install pyyaml", file=sys.stderr)
    sys.exit(2)


def run_checks(text, checks):
    """与 judge.py 相同的判定逻辑，返回 (all_passed, per_check_results)。"""
    results = []
    for c in checks:
        t = c.get("type")
        passed = False
        if t == "contains":
            passed = c.get("value", "") in text
        elif t == "not_contains":
            passed = c.get("value", "") not in text
        elif t == "regex":
            passed = bool(re.search(c.get("pattern", ""), text))
        elif t == "not_regex":
            passed = not re.search(c.get("pattern", ""), text)
        elif t == "json_schema":
            try:
                obj = json.loads(text)
                req = c.get("schema", {}).get("required", [])
                passed = all(k in obj for k in req)
            except Exception:
                passed = False
        results.append({"type": t, "passed": passed})
    return all(r["passed"] for r in results), results


def call_llm(base_url, api_key, model, messages):
    payload = json.dumps({"model": model, "messages": messages}).encode("utf-8")
    req = urllib.request.Request(
        f"{base_url.rstrip('/')}/chat/completions",
        data=payload,
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=180) as resp:
        data = json.loads(resp.read().decode("utf-8"))
    return data["choices"][0]["message"]["content"] or ""


def main():
    if len(sys.argv) < 2:
        print(json.dumps({"error": "usage: run_evals.py <skill_dir>"}), file=sys.stderr)
        return 1

    skill_dir = Path(sys.argv[1])
    base_url = os.environ.get("EVAL_BASE_URL", "")
    api_key = os.environ.get("EVAL_API_KEY", "")
    model = os.environ.get("EVAL_MODEL", "")
    if not (base_url and api_key and model):
        print(json.dumps({"error": "缺少 EVAL_BASE_URL / EVAL_API_KEY / EVAL_MODEL 环境变量"}), file=sys.stderr)
        return 1

    skill_md = (skill_dir / "SKILL.md").read_text(encoding="utf-8")
    evals = yaml.safe_load((skill_dir / "evals.yaml").read_text(encoding="utf-8"))
    cases = evals.get("cases", [])

    results = []
    for case in cases:
        task = case.get("task", "")
        checks = case.get("checks", [])
        with_text = call_llm(base_url, api_key, model, [
            {"role": "system", "content": f"你是一个编码 agent，必须遵守以下 skill 正文：\n\n{skill_md}"},
            {"role": "user", "content": task},
        ])
        without_text = call_llm(base_url, api_key, model, [
            {"role": "user", "content": task},
        ])
        with_pass, _ = run_checks(with_text, checks)
        without_pass, _ = run_checks(without_text, checks)
        results.append({
            "id": case.get("id"),
            "with_skill_pass": with_pass,
            "without_skill_pass": without_pass,
        })

    with_pass = sum(1 for r in results if r["with_skill_pass"])
    without_pass = sum(1 for r in results if r["without_skill_pass"])
    total = len(results)
    with_rate = with_pass / total if total else 0.0
    without_rate = without_pass / total if total else 0.0
    lift = with_rate - without_rate

    print(json.dumps({
        "skill": skill_dir.name,
        "cases_total": total,
        "with_skill_passed": with_pass,
        "without_skill_passed": without_pass,
        "lift": round(lift, 3),
        "cases": results,
    }, ensure_ascii=False, indent=2))

    # 闸门：with-skill 全过 且 lift > 0（with 必须严格优于 without，否则 dead weight 也绿）
    if with_pass != total:
        return 1
    if lift <= 0:
        print("lift=%s <= 0：with-skill 未优于 without-skill（dead weight），闸门不放行" % round(lift, 3), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
