# CLI Commands + Install Algorithms (v3)

Generated: 2026-02-13T06:14:27Z

## Commands

### flutter_shadcn init

Creates: - .shadcn/config.json - .shadcn/state.json

### flutter_shadcn init `<namespace>`{=html}

1.  Load directory
2.  Validate registry
3.  Respect minCliVersion
4.  Execute inline init.actions
5.  Merge pubspec
6.  Update state.json

### flutter_shadcn add `<namespace>`{=html}:component

1.  Load components.json
2.  Install under install.root
3.  Expand sharedGroups if enabled
4.  Merge dependencies
5.  Update state.json

------------------------------------------------------------------------

## Inline Init Execution Engine

Execute actions in order:

-   ensureDirs
-   copyFiles (with optional mapping)
-   copyDir (files or index)
-   mergePubspec
-   message

------------------------------------------------------------------------

## Backward Compatibility Rules

-   Migrate old config format
-   Support registries without init
-   Support registries without mapping fields
