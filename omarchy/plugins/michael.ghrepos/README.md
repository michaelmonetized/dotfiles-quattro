# Repositories bar panel

Click the GitHub icon on the right of the Omarchy bar. Search by repo or owner; click column headings to sort. Rows use 58px height and 12px cell padding. Owner is an avatar only; deployment and CI cells are colored symbols only. Hover for full names/status. Repo names link to GitHub, avatars to owner profiles, and dates to exact commits. PR/comment/issue counts keep their GitHub list links. Escape closes; Down selects rows; Enter opens the selected repository. Attention filters to repos with open PRs/issues or failed production/Actions runs.

Data comes from `ghrepos` with read-only enrichment using the existing authenticated `gh` and `vc` CLIs. No credentials are copied into this plugin. Cache: `~/.cache/ghrepos-panel/repos.json`; refreshes on opening when older than five minutes, every five minutes while open, or manually. Six concurrent workers and an interprocess lock prevent duplicate refreshes. Cached data survives network/CLI failure.

- Commit: default branch HEAD's committed date and exact commit URL (not pushedAt).
- Comments: conversation comments plus inline review comments across every open PR. PRs are paginated. Review submission bodies are not counted as comments.
- Production: latest production-target deployment attempt per linked project, including failed/building attempts; with several projects the worst status is shown and the tooltip lists all. Successful deployments link to the production domain; failed/building deployments link to the exact deployment’s `/_logs` build-log route. Owner/ID validation rejects name-only cross-owner matches from ghrepos.
- Anvil U+F089B: latest GitHub Actions workflow run, including Blacksmith-hosted workflows. It is not restricted to Blacksmith runners. Green means success, yellow means active/queued, red means failure, gray means unavailable, cancelled, skipped, or no runs. Successful CI icons have no link or clickable hover. Failed Blacksmith jobs link directly to `https://app.blacksmith.sh/<owner>/runs/<run>/jobs/<job>`. The first failed Blacksmith job is selected from paginated jobs. Non-Blacksmith and pre-job startup failures have no Blacksmith log to link, and the tooltip says so. Running CI links to the GitHub run.
- API errors appear in the repository tooltip. Missing counts use a dash, never a fake zero.

IPC: `omarchy-shell ghrepos toggle`, `omarchy-shell ghrepos-data status`, `omarchy-shell ghrepos-data refresh`.

Install path: `~/.config/omarchy/plugins/michael.ghrepos/`. Disable with `omarchy plugin disable michael.ghrepos`. Original shell configuration backup: `~/.config/omarchy/shell.json.before-ghrepos-20260927`.

API references: https://docs.github.com/en/rest/actions/workflow-runs and https://github.com/vercel/sdk/blob/main/docs/sdks/deployments/README.md
