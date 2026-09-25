# Open-source platform search recipes

Use these endpoints when the user's need points beyond GitHub. All are read-only GET requests unless noted.

## GitHub
- Search API: `https://api.github.com/search/repositories?q=<query>&sort=stars&order=desc&per_page=10`
- Useful qualifiers: `topic:<topic>`, `language:<lang>`, `license:<spdx>`, `pushed:>YYYY-MM-DD`, `archived:false`.
- Script wrapper: `scripts/search_github.py "<query>"`.
- Set `GITHUB_TOKEN` to avoid the unauthenticated 60 requests/hour limit.

## Gitee (Chinese-maintained projects)
- Search API: `https://gitee.com/api/v5/search/repositories?q=<query>&per_page=20&sort=stars_count&order=desc`
- Fields of interest: `full_name`, `html_url`, `stargazers_count`, `license`, `pushed_at`, `description`.

## GitLab
- Projects API: `https://gitlab.com/api/v4/projects?search=<query>&order_by=star_count&sort=desc&per_page=20`
- Look at `path_with_namespace`, `web_url`, `star_count`, `last_activity_at`, `archived`, `license` (may be in a nested object).

## Codeberg
- Repo search: `https://codeberg.org/api/v1/repos/search?q=<query>&limit=20`
- Gitea-style response; use `full_name`, `html_url`, `stars_count`, `updated_at`, `archived`.

## PyPI (Python packages)
- Package metadata: `https://pypi.org/pypi/<name>/json`
- Fields of interest: `info.summary`, `info.home_page`, `info.license` (may be empty), `info.classifiers` (contains `License ::` entries), `info.requires_python`, `releases` keys.
- Discovery: GitHub search with `language:Python` is usually more effective than PyPI's HTML search.

## npm (JavaScript packages)
- Search API: `https://registry.npmjs.org/-/v1/search?text=<query>&size=20`
- Look at `objects[].package`: `name`, `version`, `description`, `links`, `maintainers`, `date`.

## crates.io (Rust packages)
- Search API: `https://crates.io/api/v1/crates?q=<query>&per_page=20`
- Look at `crates[].name`, `description`, `repository`, `updated_at`, `max_version`.

## Hugging Face (models, datasets, spaces)
- Models: `https://huggingface.co/api/models?search=<query>&limit=20`
- Datasets: `https://huggingface.co/api/datasets?search=<query>&limit=20`
- Spaces: `https://huggingface.co/api/spaces?search=<query>&limit=20`
- Look at `id`, `downloads`, `likes`, `lastModified`, `tags` (license may be in `cardData.license`).

## Evaluation rubric
For each candidate, record and compare:
- License and whether it allows the user's intended use (commercial vs personal).
- Last commit / pushed date and whether the repo is archived or unmaintained.
- Adoption signals: stars, forks, downloads, contributors, open issues.
- Fit: does it actually solve the stated problem, or just share keywords?
- Health risks: no README, no releases, single maintainer, security-sensitive scope.

## Distillation format
- Lead with the best fit and one reason why.
- Then a comparison table: name, license, activity, adoption, fit notes.
- Flag deprecated, abandoned, or "free but closed-source" entries explicitly.
- When a signal is unknown, write `?` instead of inventing a value.

## Verification cautions
- GitHub search results often omit the license (`license: null`). Re-query `https://api.github.com/repos/<owner>/<repo>` or the matching package registry before stating a license.
- Match candidates by their repository URL / `home_page`, not by package name alone. The same name on PyPI and npm can be an unrelated, older project.
- Unauthenticated GitHub limits: search is about 10 requests/minute, core is about 60/hour. Set `GITHUB_TOKEN` when verifying many repos.
- If GitHub rate limits block verification, use registry metadata instead: PyPI `releases` upload time and classifiers, npm `time[version]` and `license`, crates.io `updated_at`.
