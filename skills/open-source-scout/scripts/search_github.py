#!/usr/bin/env python3
"""Search GitHub repositories and print a Markdown comparison table.

Uses only the standard library. Set GITHUB_TOKEN to raise rate limits:
    $env:GITHUB_TOKEN = "ghp_..."
"""

import argparse
import json
import os
import sys
import urllib.parse
import urllib.request

API = "https://api.github.com/search/repositories"


def search(query, sort, order, per_page, token):
    params = {
        "q": query,
        "sort": sort,
        "order": order,
        "per_page": per_page,
    }
    url = API + "?" + urllib.parse.urlencode(params)
    headers = {
        "Accept": "application/vnd.github+json",
        "User-Agent": "open-source-scout",
    }
    if token:
        headers["Authorization"] = "Bearer " + token
    req = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.load(resp)


def main():
    ap = argparse.ArgumentParser(
        description="Search GitHub repositories and print a Markdown table."
    )
    ap.add_argument("query", help="GitHub search query, e.g. 'music theory' or 'topic:vocal-synthesis'")
    ap.add_argument("--sort", default="stars", choices=["stars", "forks", "updated"])
    ap.add_argument("--order", default="desc", choices=["desc", "asc"])
    ap.add_argument("--per-page", type=int, default=10)
    ap.add_argument("--language", help="optional language filter, e.g. Python")
    ap.add_argument("--json", action="store_true", help="print raw JSON instead of Markdown")
    args = ap.parse_args()

    query = args.query
    if args.language:
        query += f" language:{args.language}"

    token = os.environ.get("GITHUB_TOKEN")
    try:
        data = search(query, args.sort, args.order, args.per_page, token)
    except Exception as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    if "items" not in data:
        print("GitHub API error:", json.dumps(data, ensure_ascii=False)[:1000], file=sys.stderr)
        if data.get("message", "").startswith("API rate limit"):
            print("Hint: set GITHUB_TOKEN to raise the rate limit.", file=sys.stderr)
        return 1

    items = data["items"]
    if args.json:
        print(json.dumps(items, indent=2, ensure_ascii=False))
        return 0

    print("| # | Repo | Stars | License | Pushed | Archived | Description |")
    print("|---:|---|---:|---|---:|---:|---|")
    for i, item in enumerate(items, 1):
        full_name = item.get("full_name", "?")
        url = item.get("html_url") or f"https://github.com/{full_name}"
        stars = item.get("stargazers_count", 0)
        license_id = (item.get("license") or {}).get("spdx_id") or "?"
        pushed = (item.get("pushed_at") or "")[:10]
        archived = "yes" if item.get("archived") else "no"
        desc = (item.get("description") or "").strip().replace("\n", " ")
        desc = desc[:120] + ("..." if len(desc) > 120 else "")
        print(f"| {i} | [{full_name}]({url}) | {stars} | {license_id} | {pushed} | {archived} | {desc} |")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
