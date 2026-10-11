# Dotfiles publishing

Before every commit or push, review `.gitignore`, the tracked paths, and the staged diff. App state, browser profiles, credentials, private calendar addresses, and backups belong outside Git. Never force-add ignored files.

Install Gitleaks and enable the repository hooks with `git config core.hooksPath .githooks`. Run `.githooks/check-dotfiles commit` before committing. The push hook checks the complete history being published, including new and restored branches. A missing scanner or failed check must stop the push. Do not bypass the hooks or add broad secret-scan exceptions.

After a history scrub, replace the old Git metadata with a fresh clone. Preserve local files and machine settings. Never merge an old backup branch into the rewritten history.
