#!/usr/bin/env python3
"""eval_drift.py — 解析 meta-drift-log.md，产出铁律层四环的 evaluate 信号（违规率/偏离率）。

用法：
  python eval_drift.py [--log PATH]

默认日志路径：~/.dsh/meta-drift-log.md（可用 --log 覆盖）。

输出（JSON）：
  total          总违规数
  by_type        {类型: 次数}
  drift_types    [{type, count, max_n}]  第N次 >= 2 即偏离（同类反复犯 = 规则失效）
  unknown_types  [非法类型]（不在 8 类枚举里，先修日志/枚举，不直接归因）

只认头行锚点 `### [类型] ... 第N次`；read-only，stdlib。
"""
import argparse
import json
import os
import re
import sys

ENUM = [
    "该弹未弹",
    "未申请就执行",
    "歧义未确认",
    "未披露",
    "未检索就造轮子",
    "判重未读版本差异",
    "造了更弱轮子",
    "画像预测偏差未沉淀",
]

# 匹配 `### [类型] ... 第N次`，类型与 N 是机器解析锚点。
ENTRY_RE = re.compile(r"^###\s*\[([^\]]+)\][^\n]*第\s*(\d+)\s*次", re.M)


def parse(text):
    by_type = {}
    max_n = {}
    unknown = []
    for m in ENTRY_RE.finditer(text):
        t = m.group(1).strip()
        n = int(m.group(2))
        if t not in ENUM:
            unknown.append(t)
            continue
        by_type[t] = by_type.get(t, 0) + 1
        max_n[t] = max(max_n.get(t, 0), n)
    total = sum(by_type.values())
    drift = [
        {"type": t, "count": by_type[t], "max_n": max_n[t]}
        for t in by_type
        if max_n[t] >= 2
    ]
    return {
        "total": total,
        "by_type": by_type,
        "drift_types": drift,
        "unknown_types": sorted(set(unknown)),
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--log", default=None, help="日志路径（默认 ~/.dsh/meta-drift-log.md）")
    args = ap.parse_args()

    path = args.log or os.path.expanduser("~/.dsh/meta-drift-log.md")
    if not os.path.exists(path):
        print(json.dumps({"error": "log not found: " + path}, ensure_ascii=True), file=sys.stderr)
        sys.exit(1)

    with open(path, "r", encoding="utf-8") as f:
        text = f.read()

    result = parse(text)
    print(json.dumps(result, ensure_ascii=True, indent=2))


if __name__ == "__main__":
    main()
