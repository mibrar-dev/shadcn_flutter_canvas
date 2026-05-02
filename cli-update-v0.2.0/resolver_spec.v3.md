# Resolver Spec + Security Rules (v3)

Generated: 2026-02-13T06:14:27Z

## URL Resolution Rules

1.  Normalize baseUrl → exactly one trailing slash
2.  Normalize relativePath → no leading slash
3.  Reject if:
    -   contains ".."
    -   contains backslash
    -   contains ? or \#
    -   contains empty segments
4.  absoluteUrl = baseUrl + relativePath

------------------------------------------------------------------------

## Filesystem Safety

Before writing:

-   destAbs = normalize(projectRoot + "/" + destination)
-   Ensure destAbs starts with projectRoot
-   Reject otherwise

------------------------------------------------------------------------

## base/destBase Mapping Safety

For `copyFiles` actions with `files[]`, entries are interpreted relative to the
action `base` when they do not already start with `base + "/"`. This keeps
registry manifests compact while still resolving source reads under the declared
base.

-   If `file` starts with `base + "/"`, use it as the source path and remove the
    prefix for destination mapping
-   If `file` does not start with `base + "/"`, prepend `base` for source reads
    and map the file relative to `destBase`
-   Validate the resulting destination path

For directory-mapped `copyFiles` actions using `from`/`to` with an explicit file
index, strict prefix matching remains required:

-   file must start with base + "/"
-   Remove prefix
-   Prepend destBase
-   Validate resulting path

------------------------------------------------------------------------

## Required Tests

-   Path traversal attempts
-   Double slash segments
-   Mapping prefix mismatch
