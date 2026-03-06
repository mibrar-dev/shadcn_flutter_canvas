# CLI Builder Agent Prompt Pack (v1, backward-compatible)

This is a **prompt** you give to a CLI implementation agent to update `flutter_shadcn` safely, without breaking the already-working CLI.

It references the spec files you already generated.

---

## 0) What to attach to the agent (files)

Attach these files to the agent message:

### Core specs (v3) folder(/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/cli-update-v0.2.0)
1. `registries.schema.v3.md`
2. `resolver_spec.v3.md`
3. `cli_command_spec.v3.md`
4. `multi_registry_architecture.v3.md`

### Also attach (because your directory schema includes init actions + indexes)
5. `flutter_shadcn_multi_registry_v3.md` (umbrella spec; inline init + base/destBase mapping)
6. `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/registry-directory/registries/registries.schema.json` (the exact schema used in your directory repo)
7. `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/registry-directory/registries/registries.json` (example entry; your official registry)
8. `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/registry-directory/registries/index.files.schema.v1.json` (for validating copyDir index files, if used)

> If the agent cannot accept attachments, paste the content of (6) and (7) directly into the prompt.

---

## 1) Absolute requirement: do not break existing CLI

The updated CLI MUST:
- keep the existing commands working for **single-registry** projects
- migrate `.shadcn/config.json` and `.shadcn/state.json` automatically if in old format
- preserve existing behavior for `add` installs (shadcn registry) while enabling multi-registry

“Backward compatible” means:
- Old config without `registries` map still works.
- Old `init` behavior still succeeds (but should route through the new engine).
- Existing `.shadcn/state.json.managedDependencies` semantics stay intact.

---

## 2) The prompt to paste to the CLI builder agent

### Prompt

You are a senior CLI engineer. Update `flutter_shadcn` to support multi-registry + inline init, based strictly on the attached v3 specifications.

**Primary sources of truth (must follow) folder(/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/cli-update-v0.2.0):**
- `registries.schema.v3.md` (directory model)
- `resolver_spec.v3.md` (URL/path security rules)
- `cli_command_spec.v3.md` (commands + algorithms)
- `multi_registry_architecture.v3.md` (isolation + addressing)
- `flutter_shadcn_multi_registry_v3.md` (inline init + base/destBase)

**Directory format (must implement):**
- Fetch `registries.json` and validate it with the provided `registries.schema.json` (Draft 2020-12).
- A registry entry MAY contain inline `init` (version=1) with actions.

**Inline init behavior (critical):**
- `flutter_shadcn init <namespace>` must execute `registry.init.actions` directly from `registries.json`.
- Do NOT require `meta.json` for bootstrap.
- If registry has no init, the command should succeed with a friendly message.

**Absolute requirement: do not break existing CLI**

The updated CLI MUST:
- keep the existing commands working for **single-registry** projects
- migrate `.shadcn/config.json` and `.shadcn/state.json` automatically if in old format
- preserve existing behavior for `add` installs (shadcn registry) while enabling multi-registry

“Backward compatible” means:
- Old config without `registries` map still works.
- Old `init` behavior still succeeds (but should route through the new engine).
- Existing `.shadcn/state.json.managedDependencies` semantics stay intact.


**Action engine requirements:**
- Implement these init action types exactly:
  - ensureDirs
  - copyFiles (supports optional `base` + `destBase`)
  - copyDir (supports files[] OR index; supports optional `base` + `destBase`)
  - mergePubspec (deps/devDeps/flutter assets/fonts)
  - message
- Execute actions in order.
- All destination paths are project-root relative. (Project root = folder containing pubspec.yaml)
- Apply strict filesystem traversal protection on every write.

**Mapping rules (base/destBase):**
- If `base` and `destBase` are provided:
  - every file path must start with `base + "/"`.
  - compute stripped = filePath without `base + "/"`.
  - destination = `destBase + "/" + stripped`.
- If mapping is not provided:
  - destination = file path as-is (relative to project root).
- For `copyDir`:
  - The `from` and `to` define which part of the tree is copied and where it lands,
  - then mapping may further relocate via destBase.
- Validate with resolver_spec + filesystem safety rules.

**Resolver rules:**
- Use resolver_spec.v3.md for baseUrl + relativePath joining.
- Reject any relativePath containing '..', '\\', '?', '#', or empty segments.
- Normalize baseUrl to exactly one trailing slash.
- Never use URL-join semantics that discard base path.

**Backwards compatibility (must):**
1) Old `.shadcn/config.json` format:
   - If config has top-level `installPath/sharedPath/registryUrl` and no `registries` object:
   - Migrate to new format with `registries[defaultNamespace]`.
   - Preserve existing flags: includeReadme/includeMeta/includePreview/checkUpdates/etc.
2) Old `.shadcn/state.json` format:
   - If state is flat, migrate into `state.registries[namespace]`.
   - Preserve managedDependencies.
3) Existing single-registry commands must behave the same after migration.

**Add resolution rules:**
- `flutter_shadcn add namespace:componentId` always installs from that registry.
- Unqualified `flutter_shadcn add componentId`:
  - search enabled registries; if ambiguous, fail and require qualified form.

**Caching (recommended):**
- Cache fetched registries.json and per-registry components.json under `.shadcn/cache/` with ETag support.
- Do not require cache to exist (fetch on demand).

**Deliverables:**
- PR-ready implementation
- Unit tests:
  - URL resolver normalization + rejection cases
  - filesystem boundary enforcement
  - base/destBase mapping correctness
  - copyDir index parsing and XOR behavior
  - config/state migration (old -> new)
  - init execution happy path for your official registry example
- Example fixtures for:
  - old config/state
  - new config/state
  - registry entry with inline init mapping
- No hard-coded shadcn folder assumptions beyond what the registry entry provides.

**Implementation order (do in this exact order):**
1) Implement resolver + filesystem safety utilities and tests.
2) Implement config/state loaders with migration and tests.
3) Implement registries directory fetch + schema validate + caching.
4) Implement init action engine (ensureDirs/copyFiles/copyDir/mergePubspec/message) + tests.
5) Wire `init` and `add` commands to new engine + tests.
6) Run end-to-end fixture tests.

Return:
- Summary of changes, files touched, and how to run tests.

---

## 3) When to use which spec file (for the agent)

- `registries.schema.v3.md`: how registries.json is shaped, what keys mean, why `.shadcn` is local.
- `resolver_spec.v3.md`: MUST implement; security critical; used for all URL fetches.
- `cli_command_spec.v3.md`: command behavior, config/state model, install algorithms.
- `multi_registry_architecture.v3.md`: ensures root isolation and non-breaking addressing rules.
- `flutter_shadcn_multi_registry_v3.md`: inline init + mapping algorithms, plus backward compatibility notes.

---

## 4) Non-negotiable acceptance criteria

The work is accepted only if:
- A project using the old CLI config/state can run `flutter_shadcn add shadcn:button` and it still works.
- `flutter_shadcn init shadcn` runs inline init actions and installs fonts + shared files as specified.
- Path traversal attempts are rejected.
- Ambiguous installs require namespace qualification.
