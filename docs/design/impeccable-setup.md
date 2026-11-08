# Impeccable for LearnAlert

Installed on 2026-11-08 for this repository only. The website has a separate project installation and context. No global skill, automatic hook, live-browser workflow, or product UI change is part of this setup.

## Provenance

- Upstream: https://github.com/pbakaus/impeccable
- Source commit: `924bbd194d02e5e15a227e75b5901fb0d7a4ecad`
- Skill: `4.8.1`, copied from `.agents/skills/impeccable` using the official Codex skill-installer helper.
- Engine: `0.1.19`; macOS ARM64 SHA256 `c35d0b0b250afceb5ab6ee7edfe190a04d76d25c56bac01935a7a1b06d0df818`, verified against the upstream pinned checksum manifest.
- Engine binary is cached outside Git at `~/.impeccable/bin/0.1.19/impeccable`. The launcher verifies downloads against its manifest. No binary is committed.
- Upstream skill files are unmodified; an upstream Apache-2.0 LICENSE is included alongside them.

## Context and usage

`PRODUCT.md` records confirmed product behavior and constraints. `DESIGN.md` records the existing visual language, including owner preferences that take precedence over generic skill advice. `.impeccable/design.json` is a minimal native metadata sidecar, not an HTML recreation of the app. Telemetry is disabled in this project's `.impeccable/config.json`.

The skill will be discoverable on the next Codex turn when working in this checkout. Example prompts:

```text
$impeccable audit LearnAlert/App/ContentView.swift — report only
$impeccable critique LearnAlert/Features/Settings/SettingsSections.swift — preserve the current identity
$impeccable polish [specific component] — keep its behavior and current design
```

The command is an instruction to the coding agent, not an independent AI redesign process. Use the context command in `AGENTS.md` once per session. Update checks, staleness-cache writes, telemetry, and hook repair are disabled for the recorded validation commands. No project code is sent by the context loader.

Native audits use SwiftUI source and, when requested, real simulator screenshots. The web detector and browser live mode do not validate native cards or notification layouts. A source review cannot certify runtime performance, contrast, or accessibility.

## Updates and removal

Updates are deliberate: review a new upstream commit and its launcher, install into a temporary directory, compare it, and replace only this skill folder. Recheck the engine checksum and rerun context loading. Do not run an update that silently installs hooks or rewrites product context.

Removing `.agents/skills/impeccable` removes the project skill. The context documents remain useful. The engine cache is shared runtime storage; leave it if another project uses it. No shell profile or global Codex configuration was changed.

## Initial result

See `2026-11-08-initial-design-review.md`. This setup intentionally captures the incumbent design and recommendations; it does not implement the recommendations.
