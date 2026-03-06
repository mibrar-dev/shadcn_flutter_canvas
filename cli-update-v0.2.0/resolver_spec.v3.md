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

If base/destBase present:

-   file must start with base + "/"
-   Remove prefix
-   Prepend destBase
-   Validate resulting path

------------------------------------------------------------------------

## Required Tests

-   Path traversal attempts
-   Double slash segments
-   Mapping prefix mismatch
