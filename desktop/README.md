# Desktop workflows

- `machine-hostname` supplies the local hostname to `michael.menu`.
- `synchro-toggle` serializes requests, launches if absent, focuses an existing window, and closes the focused window through Hyprland. File chooser windows are excluded.
- Hyper+D and Hyper+/ use the versioned `text-ai dictate` workflow. F5 remains push-to-talk plain dictation.
- Hyper+W opens Omawrite, waits for focus, then starts voxtype. Press again to stop dictation. Hyper+E opens Omawrite. Hyper+B opens `~/Brain` in Synchro.
- Markdown MIME types use `omawrite.desktop`.

## Brain capture

The `michael.brain` bar panel saves text, URLs and copied files in timestamped collections under `~/Brain/raw`. Submit groups attachments and text together; Paste clipboard also accepts a file-manager URI list. Duplicate content is not re-added. The last five submissions show processing state.

`brain-capture.service` runs Grok with edit approval, reads the vault AGENTS.md, and requires wiki indexes and an appended activity log. The raw directory is mounted read-only for the service. No historical backlog is automatically queued. `brain-capture.timer` recovers queued work after restart. Queue metadata and processing logs live in `~/.local/state/brain-capture`; failed items remain available there. Voice results are registered in the same queue after saving/pushing.

Retry a failed capture: `~/.config/desktop/bin/brain-capture retry CAPTURE-ID`

Inspect: `~/.config/desktop/bin/brain-capture history`

Process a newly saved existing source: `~/.config/desktop/bin/brain-capture enqueue "$HOME/Brain/raw/Source.md"`

The Grok workflow originally did not process the vault: it used one turn with tools and web search disabled, then saved and pushed a prompt/response file. The new worker supplies the missing ingest step. Raw sources remain user-owned; wiki edits are not automatically pushed.
