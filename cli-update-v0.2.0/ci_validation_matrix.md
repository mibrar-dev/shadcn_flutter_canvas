# Registry Directory CI Validation Matrix (v1)
Generated: 2026-02-13T06:25:10Z

This document defines the **CI rules** for the `flutter-shadcn/registry-directory` repo so that community PRs adding/editing registries do not break the ecosystem.

It is designed to be used with GitHub Actions, but the checks are CI-agnostic.

---

## 0) Scope

This CI applies to:

- `registries/registries.json`
- `registries/registries.schema.json` (the directory schema)
- Optional schemas and indexes referenced by registry entries:
  - `paths.componentsSchemaJson`
  - `paths.indexSchemaJson`
  - `paths.indexJson`
  - `paths.componentsJson`
  - `paths.folderStructureJson`
  - (Optional) `paths.metaJson` if you still support it in the future

It does **not** validate the internal structure of third-party registries beyond what is possible via HTTP fetching and schema checks.

---

## 1) Required CI Checks (must pass)

### 1.1 JSON parse check
Files must be valid JSON:
- `registries/registries.json`
- `registries/registries.schema.json`

Fail if:
- invalid JSON
- trailing commas
- duplicate keys (recommended to detect)

---

### 1.2 Schema validation: registries.json
Validate `registries/registries.json` against `registries/registries.schema.json`.

Fail if:
- schema invalid
- any registry entry violates constraints
- `registries` is empty (minItems=1)

---

### 1.3 Uniqueness constraints (cross-entry)
Fail if any two registry entries share:
- the same `id`
- the same `install.namespace`

Reason:
- `install.namespace` becomes the stable address prefix (`namespace:componentId`).
- collisions cause ambiguous installs.

---

### 1.4 URL constraints (static)
For each registry entry:
- `baseUrl` must be HTTPS and **must not** include query/fragment.
- `baseUrl` should not end with whitespace.
- `paths.*` must match relativePath rules (no leading '/', no '..', no spaces).

Fail if:
- `baseUrl` not https://
- any `paths.*` contains `..` segments or starts with `/`

---

### 1.5 Runtime fetch checks (smoke test)
For each registry entry, CI should attempt to fetch:

Required:
- `baseUrl + paths.componentsJson`

Optional but recommended:
- `baseUrl + paths.componentsSchemaJson` (if present)
- `baseUrl + paths.indexJson` (if present)
- `baseUrl + paths.indexSchemaJson` (if present)
- `baseUrl + paths.folderStructureJson` (if present)

If registry includes inline `init.actions` with `copyDir.index`, CI should fetch those index files too.

Fail if:
- any required fetch returns non-200
- fetched JSON is not parseable where JSON expected

Notes:
- Use the same resolver rules as the CLI (normalize baseUrl, strip leading '/').
- Add a short timeout (e.g., 10 seconds) per URL.
- Respect GitHub rate limits.

---

### 1.6 Schema validate fetched JSON (when schema is provided)
If a registry provides:
- `paths.componentsSchemaJson`, validate fetched `componentsJson` against it.
- `paths.indexSchemaJson`, validate fetched `indexJson` against it.

Fail if schema validation fails.

This allows registry authors to evolve their own component/index format while still being machine-validated.

---

### 1.7 Init action sanity checks (static)
If `registry.init` exists:

- `init.version` must be supported by directory schema (currently const=1).
- `init.actions` must be non-empty.
- For `copyFiles` and `copyDir`:
  - If `base` exists, `destBase` must exist (and vice versa). (Schema enforces this if you implemented `allOf` coupling.)
- For `copyDir`:
  - Must pass XOR: exactly one of `files` or `index`.

Fail if any rule violated.

---

## 2) Compatibility guardrails (recommended)

### 2.1 minCliVersion policy
CI should enforce that `minCliVersion` is not lowered below what your current CLI supports.

Example policy:
- `minCliVersion` must be >= `0.1.8` (or whatever your oldest supported version is)
- if you introduce a new schemaVersion or init.version, bump minCliVersion accordingly

Fail if:
- a PR introduces a registry that requires features not present in the declared minCliVersion

(You can implement this as a manual review checklist at first, then automate later.)

---

### 2.2 Raw GitHub hosting warning (non-failing)
If `baseUrl` matches `raw.githubusercontent.com`, CI can warn:
- This host is fine but has rate limits and can be slower than a CDN.
- Recommend GitHub Pages or a CDN for large registries.

Do not fail; just warn.

---

### 2.3 File size limits (optional)
Warn or fail if:
- components.json exceeds a chosen threshold (e.g. 5MB)
- index.json exceeds a chosen threshold (e.g. 10MB)

Reason:
- prevents slow installs and excessive bandwidth usage.

---

## 3) Test Matrix (concrete table)

| Check | Target | Required | Fails PR if broken |
|---|---|---:|---:|
| JSON parses | registries.json/schema.json | ✅ | ✅ |
| Schema validates | registries.json vs schema | ✅ | ✅ |
| registries non-empty | registries[] | ✅ | ✅ |
| Unique id | registry.id | ✅ | ✅ |
| Unique namespace | install.namespace | ✅ | ✅ |
| HTTPS baseUrl | baseUrl | ✅ | ✅ |
| RelativePath valid | paths.* | ✅ | ✅ |
| Fetch components.json | baseUrl+componentsJson | ✅ | ✅ |
| Validate components.json (if schema) | componentsSchemaJson | ➖ | ✅ |
| Fetch index.json (if present) | indexJson | ➖ | ✅ |
| Validate index.json (if schema) | indexSchemaJson | ➖ | ✅ |
| Init sanity | init/actions | ➖ | ✅ |
| CopyDir index fetch | copyDir.index | ➖ | ✅ |
| Warn on raw GH | baseUrl host | ➖ | ❌ |
| Size warnings | components/index sizes | ➖ | ❌ |

Legend:
- ✅ required
- ➖ conditional/optional
- ❌ non-failing warning

---

## 4) Suggested GitHub Actions structure (high level)

Jobs:
1. `lint-json`
2. `validate-directory-schema`
3. `unique-constraints`
4. `smoke-fetch-registry-files`
5. `validate-fetched-schemas` (conditional)
6. `init-actions-sanity`

Implementation tips:
- Use a small Node or Dart script to do URL fetch + schema validation.
- Reuse the CLI’s resolver implementation if possible (copy into CI script) to avoid drift.

---

## 5) Contributor PR checklist (human-friendly)

When adding a new registry entry:
- [ ] `id` is unique
- [ ] `install.namespace` is unique and short
- [ ] `baseUrl` is HTTPS and stable
- [ ] `componentsJson` exists and is reachable
- [ ] If you use `copyDir.index`, index files are reachable
- [ ] If you require bootstrap, include `init.actions`
- [ ] Set `minCliVersion` to the first CLI version that supports your needed features
