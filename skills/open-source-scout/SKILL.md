---
name: open-source-scout
description: Search GitHub and other open-source platforms for existing projects that match a stated need, then distill alternatives into a comparison covering license, maintenance, and fit. Use for "find an open-source project / 有没有类似的开源项目 / open-source alternative" requests; not for general web search or non-software research.
---

# Open Source Scout

Find existing open-source projects that solve a stated problem, then distill the strongest options and their trade-offs.

## Workflow

1. Pin down the target before searching: problem, language/ecosystem, platform, and hard constraints (license, self-hosted, commercial use, self-training, offline).
2. Search the right platforms, not just GitHub:
   - GitHub first: run `scripts/search_github.py` (stdlib only; set `GITHUB_TOKEN` env var to raise rate limits).
   - Gitee for Chinese-maintained projects; GitLab and Codeberg for non-GitHub; PyPI/npm/crates.io for libraries; Hugging Face for models and spaces.
   - See `references/platform-recipes.md` for ready-to-use queries and API endpoints.
3. Verify every candidate from its primary source (repository, official docs, package registry), never from SEO aggregators or mirrors.
4. Collect the signals that matter: license, stars/adoption, last commit or pushed date, archived status, open issues, recent releases, language/framework.
5. Evaluate against the rubric:
   - Active: recently pushed and responsive; archived or years-stale is a red flag.
   - License-compatible with the user's intended use (commercial vs personal).
   - Well-adopted enough to have docs, examples, and a community.
   - Actually fits the stated need, not just keyword overlap.
6. Distill to a short answer: lead with the best fit, list 2-4 real alternatives, and explicitly flag abandoned, license-incompatible, or free-but-closed options. Do not invent stars, dates, or licenses; label unknowns.

## Constraints

- Network is often restricted; request network permission before making external calls.
- Distinguish "open source" from "free but closed source" (for example Vocaloid, UTAU, and Synthesizer V are not open source).
- Prefer official repositories and package registries over mirrors and SEO sites.
- GitHub's search API often returns `license: null`; confirm license and activity from the repo endpoint or a package registry instead of leaving them unknown.
- Keep the final answer scannable: a comparison table plus a one-line recommendation is usually enough; expand only when the user asks for depth.

## References

- For non-GitHub platforms and API query recipes, read `references/platform-recipes.md`.
- For GitHub search, run `scripts/search_github.py --help` or pass a query directly.
