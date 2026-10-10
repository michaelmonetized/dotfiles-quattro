# Desktop workflows

- `machine-hostname` supplies the local hostname to `michael.menu`.
- `synchro-toggle` serializes requests, launches if absent, focuses an existing window, and closes the focused window through Hyprland. File chooser windows are excluded.
- Hyper+D and Hyper+/ use the versioned `text-ai dictate` workflow. F5 remains push-to-talk plain dictation.
- Hyper+W opens Omawrite, waits for focus, then starts voxtype. Press again to stop dictation. Hyper+E opens Omawrite. Hyper+B opens `~/Brain` in Synchro.
- Markdown MIME types use `omawrite.desktop`.

## Brain capture

The `michael.brain` bar panel saves text, URLs and copied files in timestamped collections under `~/Brain/raw`. Submit groups attachments and text together; Paste clipboard also accepts a file-manager URI list. Duplicate content is not re-added. The last five submissions show processing state.

`brain-watch.service` recursively scans `~/Brain/raw` every two seconds and queues new or changed files after ten seconds without metadata changes. Hidden files/directories, symlinks, and common temporary/download files are ignored. On its first start it baselines existing files without ingesting the archive. Its durable `watch.state` checkpoint catches saves made while stopped. Duplicate contents and files already submitted as part of a capture collection are not ingested again.

`brain-capture.service` runs Grok headlessly with the current contents of the vault `AGENTS.md` as `--system-prompt-override`. Each job must change wiki pages and `index.md`, and append to `log.md`, before it is marked processed. Raw sources are mounted read-only for the service. `brain-capture.timer` recovers queued work after restart; failed items require explicit retry. Queue metadata and per-item processing logs live in `~/.local/state/brain-capture`. Voice results use the same queue. Automatic ingestion records takeaways in the wiki instead of waiting for an interactive discussion.

Watcher status: `systemctl --user status brain-watch.service`

Watcher log: `journalctl --user -u brain-watch.service -f`

Pause watching: `systemctl --user stop brain-watch.service` (already queued jobs still run). Resume: `systemctl --user start brain-watch.service`. To disable automatic startup: `systemctl --user disable --now brain-watch.service`.

Retry a failed capture: `~/.config/desktop/bin/brain-capture retry CAPTURE-ID`

Inspect: `~/.config/desktop/bin/brain-capture history`

Process a newly saved existing source: `~/.config/desktop/bin/brain-capture enqueue "$HOME/Brain/raw/Source.md"`

The Grok workflow originally did not process the vault: it used one turn with tools and web search disabled, then saved and pushed a prompt/response file. The new worker supplies the missing ingest step. Raw sources remain user-owned; wiki edits are not automatically pushed.
