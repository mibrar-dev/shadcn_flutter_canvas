# Repository Guidelines

## Project Structure & Module Organization
- `registry/` is the heart of the copy/paste library: each component lives under `registry/components/<name>` with its Dart files, `_impl/` helpers, `README.md`, and `meta.json`. Shared helpers, tokens, and themes stay in `registry/shared`. `components.json` plus `components.schema.json` drive the CLI install experience.
- `playground/playground_app/lib/ui/shadcn/` mirrors the registry for local verification, while `playground/playground_app/lib/main.dart` launches the gallery that wraps every component with the required overlay/drawer managers.
- `shadcn_flutter_cli/` is where the future CLI lives, and `comparison_app/`/`example/` keep alternate views in sync.
- `shadcn_flutter_kit/` is the public kit repo that hosts the registry + docs app and includes:
	- `docs/` Flutter web docs app (GitHub Pages)
	- `flutter_shadcn_kit/` validator app (registry analysis)
	- `registry/` optional hosted copy (if you choose to flatten the path)

## Build, Test, and Development Commands
- `flutter pub get` (root): refresh dependencies after touching `pubspec.yaml`.
- `flutter analyze`: run from the repo root and from `playground/playground_app` to catch analyzer errors; this repo still has known issues, so new ones should be documented.
- `flutter test`: targets the `test/` suite; add coverage for refactored utilities or controllers where practical.
- `flutter run -d chrome` (inside `playground/playground_app`): launches the gallery after syncing `registry/` into `playground/playground_app/lib/ui/shadcn/` with `rsync -a registry/ playground/playground_app/lib/ui/shadcn/`.

## Coding Style & Naming Conventions
- Follow Flutter conventions: use `snake_case` for files, keep each Dart file under ~300 LOC, prefer small helpers in `_impl/`, and annotate complex sections sparingly.
- Keep theming local: use `Theme.of(context)` plus `ThemeExtension`s inside `registry/shared` rather than forcing app wrappers.
- Lint automatically; format with `flutter format` when touching Dart files and prefer `apply_patch` for edits.

## Testing Guidelines
- Add targeted unit tests (controller helpers, interpolation utilities) alongside components; golden tests are optional.
- Run `flutter analyze` after major refactors; document any new analyzer failures in the PR summary.

## Commit & Pull Request Guidelines
- Use `refactor(registry): <component>` for component moves and note migration updates if the API surface changes.
- Mention `components.json` updates when adding/removing files or shared dependencies.
- Summarize newly failing analyses, testing commands, and any manual gallery steps in the PR description.
- Create a git commit whenever a significant feature is added/removed or a large refactor lands, so changes stay traceable.
- Commit after each docs batch or other sizable change set so nothing breaks between steps.

## Security & Configuration Tips
- Keep shared surface area minimal – use `components.json` entries to describe which shared tokens, utils, and primitives each component needs before the CLI copies them.
- `playground/playground_app` should stay sync’d with `registry/` so the gallery mirrors the registry’s current state; treat `components.schema.json` as the guardrail for CLI inputs.

## Agent Notifications
- When work completes or a blocking question arises, notify the user via MCP (`mcp__notify-mcp__show`) with a short status message.
- Do not worry about MCP notify errors like "tool call failed for `notify-mcp/show` ... Unexpected response type"; the notification is still delivered.

## Commits
- When a change is large (new components, file moves, or removals), make a commit so changes don’t get lost or break later.
- Treat each sizable addition/removal as its own commit to reduce breakage between steps.


## Browser Automation

Use `agent-browser` for web automation. Run `agent-browser --help` for all commands.

Core workflow:
1. `agent-browser open <url>` - Navigate to page
2. `agent-browser snapshot -i` - Get interactive elements with refs (@e1, @e2)
3. `agent-browser click @e1` / `fill @e2 "text"` - Interact using refs
4. Re-snapshot after page changes

## graphify

This project has a graphify knowledge graph at graphify-out/.

Rules:
- Before answering architecture or codebase questions, read graphify-out/GRAPH_REPORT.md for god nodes and community structure
- If graphify-out/wiki/index.md exists, navigate it instead of reading raw files
- For cross-module "how does X relate to Y" questions, prefer `graphify query "<question>"`, `graphify path "<A>" "<B>"`, or `graphify explain "<concept>"` over grep — these traverse the graph's EXTRACTED + INFERRED edges instead of scanning files
- After modifying code files in this session, run `graphify update .` to keep the graph current (AST-only, no API cost)
