#!/usr/bin/env python3
"""push_all.py - push a local repository to GitHub / Gitee / AtomGit in one run.

Why this exists next to ``push-secure.cmd``:
  ``git -c credential.helper='!f(){...}'`` makes git spawn a POSIX shell. In hardened /
  sandboxed Windows environments that spawn fails with
  ``sh.exe: fatal error - couldn't create signal pipe, Win32 error 5`` and the push dies
  with "could not read Username". This script authenticates with
  ``-c http.extraheader='Authorization: Basic <base64(user:token)>'`` instead: no helper
  process, no interactive prompt, and the token is read from the environment only.

Tokens (never printed, redacted in all output):
  GITHUB_TOKEN, GITEE_TOKEN, ATOMGIT_TOKEN

Usage:
  python push_all.py <repo_path> <repo_name> [options]
  python push_all.py G:\\work\\myproj myproj --targets github,gitee,atomgit --proxy http://127.0.0.1:7897

Options:
  --targets        comma list, default github,gitee,atomgit
  --branch         branch to push, default main
  --github-user    default $GITHUB_USER or hpsks416
  --gitee-user     default $GITEE_USERNAME or the GitHub user
  --atomgit-user   default $ATOMGIT_USER
  --atomgit-host   default $ATOMGIT_HOST or atomgit.com
  --proxy          HTTP(S) proxy for GitHub only, e.g. http://127.0.0.1:7897
"""
from __future__ import annotations

import argparse
import base64
import os
import subprocess
import sys

GH_TOKEN = os.environ.get("GITHUB_TOKEN", "")
GT_TOKEN = os.environ.get("GITEE_TOKEN", "")
AT_TOKEN = os.environ.get("ATOMGIT_TOKEN", "")


def redact(text: str) -> str:
    for tok in (GH_TOKEN, GT_TOKEN, AT_TOKEN):
        if tok:
            text = text.replace(tok, "***REDACTED***")
    return text


def push_one(*, repo: str, name: str, target: str, user: str, token: str,
             host: str, branch: str, proxy: str | None) -> bool:
    if not token:
        print(f"[{target}] SKIP: token missing")
        return False
    url = f"https://{host}/{user}/{name}.git"
    auth = base64.b64encode(f"{user}:{token}".encode()).decode()
    cmd = [
        "git",
        "-c", "http.sslBackend=openssl",
        "-c", f"http.extraheader=Authorization: Basic {auth}",
        "-c", "credential.helper=",
    ]
    if proxy:
        cmd += ["-c", f"http.proxy={proxy}", "-c", f"https.proxy={proxy}"]
    cmd += ["push", url, f"{branch}:{branch}"]
    env = dict(os.environ, GIT_TERMINAL_PROMPT="0", GIT_ASKPASS="")
    try:
        r = subprocess.run(cmd, cwd=repo, capture_output=True, text=True,
                           timeout=1200, env=env)
    except subprocess.TimeoutExpired:
        print(f"[{target}] TIMEOUT after 1200s")
        return False
    out = redact((r.stdout or "") + (r.stderr or "")).strip()
    print(f"[{target}] {'OK' if r.returncode == 0 else 'FAIL'} (exit {r.returncode})")
    if out:
        print(out[-1500:])
    return r.returncode == 0


def main() -> int:
    p = argparse.ArgumentParser(description="Push a repo to GitHub / Gitee / AtomGit.")
    p.add_argument("repo_path")
    p.add_argument("repo_name")
    p.add_argument("--targets", default="github,gitee,atomgit")
    p.add_argument("--branch", default="main")
    p.add_argument("--github-user", default=os.environ.get("GITHUB_USER", "hpsks416"))
    p.add_argument("--gitee-user", default=os.environ.get("GITEE_USERNAME", ""))
    p.add_argument("--atomgit-user", default=os.environ.get("ATOMGIT_USER", ""))
    p.add_argument("--atomgit-host", default=os.environ.get("ATOMGIT_HOST", "atomgit.com"))
    p.add_argument("--proxy", default=os.environ.get("GIT_HTTP_PROXY", ""))
    a = p.parse_args()

    if not os.path.isdir(os.path.join(a.repo_path, ".git")):
        print(f"ERROR: {a.repo_path} is not a git repository")
        return 2

    gitee_user = a.gitee_user or a.github_user
    proxy = a.proxy or None
    results: dict[str, bool] = {}
    for target in [t.strip().lower() for t in a.targets.split(",") if t.strip()]:
        if target == "github":
            ok = push_one(repo=a.repo_path, name=a.repo_name, target="github",
                          user=a.github_user, token=GH_TOKEN, host="github.com",
                          branch=a.branch, proxy=proxy)
        elif target == "gitee":
            ok = push_one(repo=a.repo_path, name=a.repo_name, target="gitee",
                          user=gitee_user, token=GT_TOKEN, host="gitee.com",
                          branch=a.branch, proxy=None)
        elif target == "atomgit":
            if not a.atomgit_user:
                print("[atomgit] SKIP: no --atomgit-user / $ATOMGIT_USER")
                ok = False
            else:
                ok = push_one(repo=a.repo_path, name=a.repo_name, target="atomgit",
                              user=a.atomgit_user, token=AT_TOKEN, host=a.atomgit_host,
                              branch=a.branch, proxy=None)
        else:
            print(f"[{target}] SKIP: unknown target")
            ok = False
        results[target] = ok

    print("SUMMARY:", ", ".join(f"{k}={'OK' if v else 'FAIL'}" for k, v in results.items()))
    return 0 if results and all(results.values()) else 1


if __name__ == "__main__":
    sys.exit(main())
