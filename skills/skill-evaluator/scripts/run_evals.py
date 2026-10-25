#!/usr/bin/env python3
"""CI 版动态 evals：对单个 skill 的 evals.yaml 跑 A/B（with-skill vs without-skill）。

与 skill-evaluator 的「subagent A/B」不同：这里直接用 OpenAI 兼容 API 调模型，
只判最终答复，用于 GitHub Actions 自动回归。

两种能力：
1. 纯文本 A/B（contains/not_contains/regex/not_regex/json_schema 判最终答复）。
2. function-calling mock harness：内置 mock `web_search` 工具（记录调用 + 返回假结果，
   无真网络），新增 `tool_called` / `not_tool_called` 检查——断言模型**真的调用了检索工具**
   （行为证据，而非「知不知道 pandoc 这个词」）。

用法：
  python run_evals.py <skill_dir>

环境变量：
  EVAL_BASE_URL   OpenAI 兼容端点（如 https://api.commandcode.ai/provider/v1）
  EVAL_API_KEY    API key
  EVAL_MODEL      模型 id（如 deepseek/deepseek-v4-pro）

退出码：0 = 所有用例 with-skill 通过且 lift > 0；1 = 有用例未通过或 lift <= 0。
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


# mock 检索工具：只记录调用、返回假检索产物（CI 无真网络、无真凭据）。
MOCK_TOOLS = [
    {
        "type": "function",
        "function": {
            "name": "web_search",
            "description": "检索开源项目/库/工具（GitHub/PyPI/npm/arXiv）。返回匹配项名称与来源 URL。",
            "parameters": {
                "type": "object",
                "properties": {
                    "query": {"type": "string", "description": "检索关键词"}
                },
                "required": ["query"],
            },
        },
    }
]

# 假检索结果：让模型有「检索产物」可引用，测它是否真发起检索并消费结果。
MOCK_SEARCH_RESULT = (
    "Found: pandoc (https://pandoc.org, GPL-2.0, mature doc converter); "
    "markitdown (https://github.com/microsoft/markitdown, MIT, Microsoft)."
)

# 退出码：0=通过 / 1=真失败（lift 闸门）/ 2=跳过（缺 key 或余额不足，fork 友好）
SKIP = 2


def post_chat(base_url, api_key, model, messages, tools=None):
    payload = {"model": model, "messages": messages}
    if tools:
        payload["tools"] = tools
    req = urllib.request.Request(
        f"{base_url.rstrip('/')}/chat/completions",
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=180) as resp:
        data = json.loads(resp.read().decode("utf-8"))
    return data["choices"][0]["message"]


def run_conversation(base_url, api_key, model, messages, tools=None, max_turns=6):
    """多轮 function-calling 循环。返回 (tool_call_names, final_content)。"""
    tool_calls_seen = []
    msgs = list(messages)
    for _ in range(max_turns):
        msg = post_chat(base_url, api_key, model, msgs, tools=tools)
        tc = msg.get("tool_calls") or []
        if tc:
            msgs.append({"role": "assistant", "content": msg.get("content") or "", "tool_calls": tc})
            for call in tc:
                fn = call.get("function", {})
                name = fn.get("name", "")
                tool_calls_seen.append(name)
                msgs.append({
                    "role": "tool",
                    "tool_call_id": call.get("id", ""),
                    "content": MOCK_SEARCH_RESULT if name == "web_search" else "",
                })
            continue
        return tool_calls_seen, (msg.get("content") or "")
    return tool_calls_seen, ""


def run_checks(text, checks, tool_calls=None):
    """返回 (all_passed, per_check_results)。tool_called/not_tool_called 看工具调用，其余看 text。"""
    results = []
    calls = tool_calls or []
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
        elif t == "tool_called":
            passed = c.get("name", "") in calls
        elif t == "not_tool_called":
            passed = c.get("name", "") not in calls
        results.append({"type": t, "passed": passed})
    return all(r["passed"] for r in results), results


def main():
    if len(sys.argv) < 2:
        print(json.dumps({"error": "usage: run_evals.py <skill_dir>"}), file=sys.stderr)
        return 1

    skill_dir = Path(sys.argv[1])
    base_url = os.environ.get("EVAL_BASE_URL", "")
    api_key = os.environ.get("EVAL_API_KEY", "")
    model = os.environ.get("EVAL_MODEL", "")
    if not (base_url and api_key and model):
        print("SKIP: 缺少 EVAL_BASE_URL / EVAL_API_KEY / EVAL_MODEL（fork 未配 secret），跳过动态 evals", file=sys.stderr)
        return SKIP

    skill_md = (skill_dir / "SKILL.md").read_text(encoding="utf-8")
    evals = yaml.safe_load((skill_dir / "evals.yaml").read_text(encoding="utf-8"))
    cases = evals.get("cases", [])

    # 任一用例用到 tool_called/not_tool_called 就启用 mock tools（A/B 双臂同工具，公平）。
    use_tools = any(
        any(c.get("type") in ("tool_called", "not_tool_called") for c in case.get("checks", []))
        for case in cases
    )

    results = []
    try:
        for case in cases:
            task = case.get("task", "")
            checks = case.get("checks", [])
            tools = MOCK_TOOLS if use_tools else None

            with_calls, with_text = run_conversation(base_url, api_key, model, [
                {"role": "system", "content": f"你是一个编码 agent，必须遵守以下 skill 正文：\n\n{skill_md}"},
                {"role": "user", "content": task},
            ], tools=tools)
            without_calls, without_text = run_conversation(base_url, api_key, model, [
                {"role": "user", "content": task},
            ], tools=tools)

            with_pass, _ = run_checks(with_text, checks, with_calls)
            without_pass, _ = run_checks(without_text, checks, without_calls)
            results.append({
                "id": case.get("id"),
                "with_skill_pass": with_pass,
                "without_skill_pass": without_pass,
                "with_tool_calls": with_calls,
                "without_tool_calls": without_calls,
            })
    except urllib.error.HTTPError as e:
        if e.code in (401, 403, 402):
            print("SKIP: 鉴权失败/余额不足（HTTP %s），跳过动态 evals" % e.code, file=sys.stderr)
            return SKIP
        raise

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
