# Registries Schema + Implementation Guide (v3)

Generated: 2026-02-13T06:14:27Z

## Key Updates from v2

-   Inline `init` supported directly inside `registries.json`
-   `base` + `destBase` mapping supported in init actions
-   Strict backward compatibility rules
-   No required meta.json fetch

------------------------------------------------------------------------

## Registry Discovery Flow

1.  Fetch `registries.json`
2.  Validate against schema
3.  Filter by `minCliVersion`
4.  Cache result

------------------------------------------------------------------------

## Inline Init Model

If a registry entry includes:

``` json
"init": {
  "version": 1,
  "actions": []
}
```

The CLI MUST execute `init.actions` during:

flutter_shadcn init `<namespace>`{=html}

If missing → safe no-op.

------------------------------------------------------------------------

## Mapping Support (base + destBase)

If provided, both must exist together.

### copyFiles

If base/destBase exist:

-   Strip base prefix
-   Write into destBase

Otherwise:

-   Write file relative to project root

------------------------------------------------------------------------

## Backward Compatibility

### Old Config Migration

If `.shadcn/config.json` does not contain `registries` object:

-   Wrap old fields into `registries[defaultNamespace]`
-   Preserve flags
-   Save upgraded format

------------------------------------------------------------------------

## Required Runtime Enforcement

Schema cannot validate remote file existence.

CLI must:

-   Enforce resolver rules
-   Validate filesystem boundaries
-   Respect minCliVersion
