# Login-Page Skill/CLI Test — Issue Log

Date: 2026-09-04. Method: fresh `flutter create --empty` app in `/tmp/skill_login_test`,
three parallel agents (builder / CLI stress-tester / skill auditor) following ONLY the
skill at `~/.config/opencode/skills/flutter-shadcn-ui/`. Builder result:
login page works, `flutter analyze`: **No issues found**.

## CLI issues (flutter_shadcn 0.2.6)

| # | Severity | Issue | Evidence |
|---|----------|-------|----------|
| C1 | blocker | `validate` hangs on remote registry (>60–120s, must kill) | human + `--json` never return; HEAD-checks every file, no timeout |
| C2 | blocker | `dry-run @shadcn/<id>` → exit 30 `component_missing` for all, while `add`/`info` accept the prefix | `dry-run @shadcn/form @shadcn/button…` fails; bare names succeed |
| C3 | major | `! index.json schema validation failed (42 issues)` printed on **stdout**, breaking `--json` parsing for list/search/info | `json.load` fails unless `!` lines filtered |
| C4 | major | Remote 404s: `.../lib/components.schema.json`, `.../generated/amber-minimal/preset_themes.install.txt` → `doctor` exit 20 `schema_invalid`, `init` theme-skip warning, offline `validate` hard-fail | URL paths look wrong vs `registry/manifests/` layout |
| C5 | major | `info A B C --json` silently returns only first component, exit 0 | silent data loss for scripts |
| C6 | major | `info tab_list --json` advertises nonexistent barrel `navigation/tab_list/tab_list.dart` (disk has only `_impl/…`) | breaks literal imports |
| C7 | major | `add` removed `flutter_localizations` + `intl` although installed `ShadcnApp` imports them | builder had to re-add SDK dep manually |
| C8 | major | `info --json` `importPath` omits `components/` (`ui/shadcn/control/…` vs real `ui/shadcn/components/control/…`) | contradicts skill path rule (skill is right) |
| C9 | minor | `list @shadcn` returns 133 vs manifest/skill 134 | index out of sync by one |
| C10 | minor | `validate --json --offline` emits no JSON (stderr text only, exit 20) | inconsistent with `doctor --json` envelope |
| C11 | minor | `theme --list` has no `--json`; `assets --list` is a placeholder; `help <cmd>` unsupported; `--version` flag missing (`version` subcommand only) | scripting/UX gaps |
| C12 | minor | `list @ai` → exit 10 `registry_not_found` (correct) but undiscoverable; `search/info @ai/…` **crash** with interactive GitHub-issue prompt (blocks automation) | inconsistent error handling |

## Skill issues (flutter-shadcn-ui 2.1.0)

| # | Severity | Issue | Fix |
|---|----------|-------|-----|
| S1 | high | replacement-map hide-list omits `Form`, `FormField`, `Button` → literal `ambiguous_import` on every login page | extend hide-list |
| S2 | medium | hide-list omits `TextButton`, `IconButton`, `CircularProgressIndicator`, `LinearProgressIndicator`, `VerticalDivider` | extend hide-list |
| S3 | high | forms.md Specialized Inputs use `category/name` IDs (`form/autocomplete`) which the CLI rejects (`Component not found`) | rewrite as `@shadcn/<id>` + "never pass category/name" note |
| S4 | medium | SKILL.md says `ShadcnApp` ships with `init`; it is component `@shadcn/app` and MUST be `add`ed (only `ShadcnLayer`/`OverlayManagerLayer` are shared) | reword |

## Verified correct (no action)

- 134 + 36 catalog ids, category counts, install-path rule, login dep graph, all cli-workflows commands/flags parse.
- Login dep closure: requested 8 → 14 resolved + 23 shared, pubspec `{data_widget, email_validator, gap}`.

## Resolutions (2026-09-04, second pass)

Skill (v2.2.0): S1+S2 hide-list extended (`Form, FormField, Button, TextButton,
`IconButton`, progress indicators, `VerticalDivider`); S3 forms.md rewritten to
`@shadcn/<id>` + never-pass-`category/name` note; S4 `ShadcnApp` corrected to
must-`add @shadcn/app` (only layers ship with `init`).

CLI (uncommitted, in `shadcn_flutter_cli/`): C2 dry-run normalizes `@ns/id`
(verified: `dry-run @shadcn/button --json` → ok, missing []); C5 multi-`info`
→ exit 2 JSON `usage_error` envelope (verified); C8 `importPath` now includes
`components/`; C6 `tab_list` resolves to real `_impl/core/tab_list.dart`;
C11 `--version` flag added (verified); C3 `!` warnings → stderr, stdout JSON
parses (verified); C12 search/info on unknown namespace → exit 10
`registry_not_found` envelope, no crash/prompt (verified); C10 offline
validate emits JSON envelope; C4 remote `manifests/` + `registry/` fallbacks
+ 15–20s timeouts (doctor finds schema, theme artifact fetches OK);
C1 validate gets bounded concurrency (12) + per-file timeouts + stderr
progress; C7 `add` never removes `flutter_localizations`/`intl`.
`dart analyze`: clean. Full suite: **341/341 pass** (incl. new
`info_dry_run_normalization_test`, 8 tests). Login app `flutter analyze`:
clean. NOTE: fixes verified via repo binary (`bin/flutter_shadcn.dart`);
global `flutter_shadcn` on PATH is still published 0.2.6 — re-activate to ship.

Regression caught during verification: schema-validator remote-prefer broke
`e2e_multi_registry_fixture_test` (fixture HTTP server serves only the
advertised root schema path). Fixed as try-primary-then-fallback; e2e green.

## New findings (remote registry DATA, not CLI code — needs republish)

- R1: remote `index.json` lists 133 components; local manifest has 134.
  Missing remotely: `file_diff_viewer`. Republish the registry.
- R2: live `dry-run --all` hits phantom `markdown_live_preview.dart` dep on
  remote data (local manifest clean, all 31 markdown files exist). Same cause
  as R1 — stale remote manifest.
- R3: `@ai` namespace absent from remote `registries.json` (skill documents
  `@ai → lib/ui/ai`, 36 components). Publish `ai_chat` registry or scope the
  skill's `@ai` claims until it exists.

