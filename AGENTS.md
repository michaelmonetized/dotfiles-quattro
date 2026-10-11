# Dotfiles publishing

Before every commit or push, review `.gitignore`, the tracked paths, and the staged diff. App state, browser profiles, credentials, private calendar addresses, and backups belong outside Git. Never force-add ignored files.

Install Gitleaks and run `.githooks/install`. Run `.githooks/check-dotfiles commit` before committing. The installed hooks and policy live in Git metadata and remain active when switching branches, including older branches without these files. The push hook checks the complete history being published, including new and restored branches. A missing scanner or failed check must stop the push. Do not bypass the hooks or add broad secret-scan exceptions. Re-run the installer after an approved policy update.

After a history scrub, replace the old Git metadata with a fresh clone. Preserve local files and machine settings. Never merge an old backup branch into the rewritten history.
