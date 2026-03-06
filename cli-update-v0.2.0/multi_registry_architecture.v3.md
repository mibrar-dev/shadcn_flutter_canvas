# Multi-Registry Architecture (v3)

Generated: 2026-02-13T06:14:27Z

## Install Root Isolation

Each registry installs under its own:

lib/ui/`<namespace>`{=html}

Never write outside projectRoot.

------------------------------------------------------------------------

## Inline Init Design

Registries define bootstrap directly inside registries.json.

No hardcoded shadcn logic allowed in CLI.

------------------------------------------------------------------------

## Mixed Registry Support

Registry types supported:

-   Full shared + composite systems
-   Single-file minimal registries
-   Registries with or without init
-   Registries with or without mapping

------------------------------------------------------------------------

## Namespace Resolution

Preferred: namespace:component

Unqualified: Must resolve uniquely or error.

------------------------------------------------------------------------

## Future-Safe Design

-   Additional action types must increment init.version
-   SchemaVersion increments must be respected
