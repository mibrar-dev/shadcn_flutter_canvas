# flutter_shadcn Multi‑Registry + Inline Init Spec (v3)
Generated: 2026-02-13T06:12:47Z

This document updates the previous v2 spec to reflect:

- Inline `init` inside `registries.json` (no required meta.json fetch)
- Support for `base` + `destBase` mapping in `copyFiles` and `copyDir`
- Strict resolver + filesystem safety
- Backward compatibility with older single‑registry CLI config
- Backward compatibility with registries that do NOT use base/destBase

---

# 1. Architectural Model (Final)

## Hosted
- registries.json (directory)
- components.json per registry
- optional index files for copyDir
- registry source files

## Local (per project)
- .shadcn/config.json
- .shadcn/state.json
- .shadcn/cache/*

---

# 2. Inline Init Model (No meta.json Required)

Each registry entry MAY contain:

"init": {
  "version": 1,
  "actions": [ ... ]
}

If present, CLI must execute it during:

flutter_shadcn init <namespace>

If absent, CLI must skip bootstrap safely.

---

# 3. Path Semantics (CRITICAL)

Init actions are executed relative to:

projectRoot (directory containing pubspec.yaml)

NOT relative to install.root.

---

# 4. Mapping Rules (New)

copyFiles and copyDir support:

- base (source base path inside registry)
- destBase (destination base path inside consumer project)

Both must appear together or not at all.

## 4.1 copyFiles Execution Algorithm

For each file in files[]:

If base/destBase NOT provided:
    destination = projectRoot + "/" + file

If base/destBase provided:
    assert file startsWith base + "/"
    stripped = file.removePrefix(base + "/")
    destination = projectRoot + "/" + destBase + "/" + stripped

Apply filesystem safety checks before writing.

---

## 4.2 copyDir Execution Algorithm

Resolve file list via:
- explicit files[]
- OR download index file

For each file:

If base/destBase provided:
    assert file startsWith base + "/" + from + "/"
    stripped = file.removePrefix(base + "/")
Else:
    assert file startsWith from + "/"
    stripped = file

Remove `from/` from stripped
destinationRel = to + "/" + remaining

If destBase exists:
    destinationRel = destBase + "/" + destinationRel

Write to projectRoot + "/" + destinationRel

---

# 5. Backward Compatibility Requirements

## 5.1 Old Single‑Registry Config

If `.shadcn/config.json` does NOT contain:

registries: {}

Migrate automatically:

- Create registries object
- Move installPath/sharedPath into registries[defaultNamespace]
- Preserve flags

Save upgraded format back to disk.

---

## 5.2 Registries Without base/destBase

Must still work.

If base/destBase not provided:
- treat file paths as project-relative destinations
- do NOT attempt remapping

---

## 5.3 Registries Without init

flutter_shadcn init <namespace> should:

- Create config/state if missing
- Print message: "No bootstrap actions defined"
- Exit successfully

---

# 6. Resolver Rules (Mandatory)

For every remote file fetch:

1. Normalize baseUrl (exactly one trailing slash)
2. Normalize relativePath (no leading slash)
3. Reject if:
   - contains ".."
   - contains backslash
   - contains ? or #
   - contains empty segment
4. absoluteUrl = baseUrl + relativePath

---

# 7. Filesystem Safety (Mandatory)

Before writing:

destAbs = normalize(projectRoot + "/" + destinationRel)
rootAbs = normalize(projectRoot)

Assert destAbs startsWith rootAbs

Reject otherwise.

---

# 8. Install Algorithm (Final)

## flutter_shadcn init

1. Ensure .shadcn exists
2. Create config.json if missing
3. Create state.json if missing
4. Exit

## flutter_shadcn init <namespace>

1. Ensure .shadcn exists
2. Fetch registries.json
3. Validate schema
4. Locate registry by install.namespace
5. Respect minCliVersion
6. Execute registry.init.actions
7. Merge pubspec
8. Update state.json
9. Print message lines

## flutter_shadcn add <namespace>:<component>

1. Load components.json
2. Install component files under install.root
3. Expand shared groups if enabled
4. Merge pubspec dependencies
5. Update state.json

---

# 9. CLI Builder Agent Prompt

Implement multi‑registry support for flutter_shadcn using the provided schema and directory format.

Requirements:

- Inline init execution (no meta.json fetch)
- Execute registry.init.actions from registries.json
- Support base + destBase mapping
- Enforce strict resolver rules
- Enforce strict filesystem traversal protection
- Maintain backward compatibility with old config format
- Respect minCliVersion
- Namespace resolution rules enforced

Deliverables:
- Clean modular code
- Unit tests for resolver, mapping, migration, init, install
- No hardcoded shadcn logic

Implementation order:
1. Resolver + safety
2. Config migration
3. Directory fetch + validation
4. Init engine
5. Component install
6. Tests
