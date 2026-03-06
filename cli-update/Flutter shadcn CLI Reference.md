# Flutter Shadcn CLI - Conflict Resolution Visual Reference

## 1. Three-Way Merge Decision Tree

```
START: File Update Detected
│
├─→ Does file exist in all three versions?
│   │
│   ├─→ NO (file created/deleted)
│   │   ├─→ Only upstream deleted? → Auto-accept deletion ✅
│   │   ├─→ Only user created new file? → Keep local version ✅
│   │   └─→ Both created same file? → Compare content
│   │
│   └─→ YES → Continue to checksum comparison
│
├─→ Compare Checksums
│   │
│   ├─→ base == current == upstream?
│   │   └─→ NO CHANGES NEEDED ✅
│   │
│   ├─→ base == current ≠ upstream?
│   │   └─→ FAST-FORWARD: Accept upstream ⬆️
│   │
│   ├─→ base ≠ current == upstream?
│   │   └─→ KEEP LOCAL: User made same changes 🎯
│   │
│   ├─→ current == upstream ≠ base?
│   │   └─→ NO CHANGES: Converged on same version ✅
│   │
│   └─→ base ≠ current ≠ upstream?
│       │
│       └─→ Check for overlapping changes
│           │
│           ├─→ Changes on different lines?
│           │   └─→ AUTO-MERGEABLE ✨
│           │
│           └─→ Changes on same lines?
│               └─→ CONFLICT ⚠️ (need user decision)
│
└─→ Apply Resolution
    └─→ See Resolution Strategy Section Below
```

---

## 2. File Modification Timeline

```
Installation Time:
┌─────────────────────────────┐
│  Original File Content      │
│  base checksum: ABC123      │
│  current checksum: ABC123   │
└─────────────────────────────┘
         ⬇️
         (user edits file)
         ⬇️
User's Current State (Before Update):
┌─────────────────────────────┐
│  Modified File Content      │
│  base checksum: ABC123      │ ← Still original checksum
│  current checksum: XYZ789   │ ← Different due to user edits
│  userModified: true         │ ← Detected! ✅
└─────────────────────────────┘
         ⬇️
         (new version available in registry)
         ⬇️
Update Available:
┌─────────────────────────────┐
│  New File Content           │
│  upstream checksum: DEF456  │ ← Different from both
└─────────────────────────────┘
         ⬇️
Three-Way Merge Analysis:
┌─────────────────────────────┐
│  base:     ABC123 ✓         │
│  current:  XYZ789 ← User    │
│  upstream: DEF456 ← Registry│
│                             │
│  Result: CONFLICT ⚠️         │
│  Action: Ask user           │
└─────────────────────────────┘
```

---

## 3. Conflict Resolution Strategies Flow

```
CONFLICT DETECTED
│
├─→ User chooses resolution strategy:
│   │
│   ├─→ [1] KEEP YOUR VERSION (ours)
│   │   │
│   │   ├─→ Keep current content
│   │   ├─→ Update checksum to current
│   │   ├─→ Mark as userModified: true
│   │   └─→ Log decision ✅
│   │
│   ├─→ [2] ACCEPT UPSTREAM (theirs)
│   │   │
│   │   ├─→ Use upstream content
│   │   ├─→ Reset to original structure
│   │   ├─→ Mark as userModified: false
│   │   └─→ Log decision ✅
│   │
│   ├─→ [3] MANUAL EDIT
│   │   │
│   │   ├─→ Create conflict markers in file:
│   │   │   ├─→ <<<<<<< CURRENT
│   │   │   ├─→ (user's version)
│   │   │   ├─→ ||||||| BASE
│   │   │   ├─→ (original version)
│   │   │   ├─→ =======
│   │   │   ├─→ (upstream version)
│   │   │   └─→ >>>>>>> UPSTREAM
│   │   │
│   │   ├─→ Open in user's editor
│   │   ├─→ User resolves manually
│   │   ├─→ Remove conflict markers
│   │   ├─→ Update checksums
│   │   └─→ Log decision ✅
│   │
│   └─→ [4] SKIP FOR NOW
│       │
│       ├─→ Leave file unchanged
│       ├─→ Mark as pendingConflict
│       ├─→ Save to conflicts.json
│       └─→ Resume later with 'conflicts resolve' ⏳
│
└─→ Apply Resolution
    ├─→ Save resolved content
    ├─→ Update manifest
    ├─→ Record in conflict history
    └─→ Move to next file
```

---

## 4. Merge State Visualization

```
MERGE STATES AND TRANSITIONS

Clean State:
┌─────────────────────────┐
│  base == current        │
│  base == upstream       │
│  → NO ACTION NEEDED ✅  │
└─────────────────────────┘

Fast Forward:
┌──────────────────────────────────┐
│  base == current                 │
│  base ≠ upstream                 │
│  → AUTO APPLY UPSTREAM CHANGE ⬆️  │
│                                  │
│  Timeline:                       │
│  base:     final x = 1;          │
│  current:  final x = 1;          │
│  upstream: final x = 2; + theme  │
│            + dark mode           │
│  Result:   final x = 2; + theme  │
│            + dark mode  ✅       │
└──────────────────────────────────┘

Keep Local:
┌──────────────────────────────────┐
│  base ≠ current                  │
│  base == upstream                │
│  → KEEP USER'S VERSION ✏️        │
│                                  │
│  Timeline:                       │
│  base:     class Button {}       │
│  current:  class Button {}       │
│            with animation       │
│  upstream: class Button {}       │
│  Result:   Keep animation ✅     │
└──────────────────────────────────┘

Auto-Mergeable:
┌──────────────────────────────────┐
│  base ≠ current ≠ upstream       │
│  BUT changes don't overlap       │
│  → AUTO-MERGE ✨                │
│                                  │
│  Timeline:                       │
│  base:     line1                 │
│            line2                 │
│            line3                 │
│                                  │
│  current:  line1                 │
│            line2 (MODIFIED) ← U  │
│            line3                 │
│                                  │
│  upstream: line1                 │
│            line2                 │
│            line3 (NEW) ← R       │
│                                  │
│  Merged:   line1                 │
│            line2 (MODIFIED) ← U  │
│            line3 (NEW) ← R  ✅   │
└──────────────────────────────────┘

Conflict:
┌──────────────────────────────────┐
│  base ≠ current ≠ upstream       │
│  AND changes overlap             │
│  → CONFLICT ⚠️ (user decides)    │
│                                  │
│  Timeline:                       │
│  base:     class Button {        │
│              Color: #FF0000      │
│            }                     │
│                                  │
│  current:  class Button {        │
│              Color: #FF0000 → U  │
│              + animation         │
│            }                     │
│                                  │
│  upstream: class Button {        │
│              Color: Theme.seed→R │
│              + dark mode         │
│            }                     │
│                                  │
│  → CANNOT AUTO-MERGE ⚠️          │
│  → ASK USER ❓                   │
└──────────────────────────────────┘
```

---

## 5. Manifest File Structure Examples

### After Installation

```json
{
  "version": "1.0.0",
  "registryVersion": "registry-v2.1.0",
  "lastUpdatedAt": "2026-01-30T10:00:00Z",
  "components": {
    "button": {
      "name": "button",
      "version": "1.0.0",
      "registryVersion": "abc123def456",
      "installedAt": "2026-01-30T10:00:00Z",
      "status": "clean",
      "files": {
        "lib/ui/components/button/button.dart": {
          "path": "lib/ui/components/button/button.dart",
          "source": "registry/button/button.dart",
          "checksum": "sha256:abc123...",
          "baseChecksum": "sha256:abc123...",
          "size": 2048,
          "userModified": false,
          "lastModified": "2026-01-30T10:00:00Z"
        }
      },
      "dependencies": []
    }
  }
}
```

### After User Modification

```json
{
  "components": {
    "button": {
      ...
      "status": "modified",  // ← Changed!
      "files": {
        "lib/ui/components/button/button.dart": {
          ...
          "checksum": "sha256:xyz789...",  // ← Different!
          "baseChecksum": "sha256:abc123...",  // ← Original stays same
          "userModified": true,  // ← Detected!
          "lastModified": "2026-01-30T15:30:00Z"  // ← Updated
        }
      }
    }
  }
}
```

### After Conflict Resolution

```json
{
  "components": {
    "button": {
      ...
      "status": "clean",  // ← Back to clean
      "files": {
        "lib/ui/components/button/button.dart": {
          ...
          "checksum": "sha256:merged999...",  // ← Merged content
          "baseChecksum": "sha256:merged999...",  // ← Reset for next update
          "userModified": true,  // ← Still marked true if user kept changes
          "lastModified": "2026-01-30T16:00:00Z"
        }
      }
    }
  }
}
```

---

## 6. Backup Directory Structure

```
.shadcn/
├── installed.json          ← Current manifest
├── conflicts.json          ← Conflict history
├── backups/
│   ├── button/
│   │   ├── 1.0.0/
│   │   │   ├── manifest.json
│   │   │   └── lib/ui/components/button/
│   │   │       ├── button.dart
│   │   │       └── button_theme.dart
│   │   └── 1.1.0/
│   │       ├── manifest.json
│   │       └── lib/ui/components/button/
│   │           ├── button.dart
│   │           └── button_theme.dart
│   └── card/
│       ├── 1.0.0/
│       │   ├── manifest.json
│       │   └── ...
│       └── 1.2.0/
│           ├── manifest.json
│           └── ...
```

---

## 7. CLI Command Output Examples

### Successful Update (No Conflicts)

```
$ flutter pub global run flutter_shadcn update button

📦 Checking for updates...
   Registry version: 1.2.0 (current: 1.0.0)

🔍 Analyzing changes...
   ✅ lib/ui/components/button/button.dart
      • Upstream: Added dark mode support (non-overlapping)
      • You: Custom animation (non-overlapping)
      • Result: Auto-mergeable ✨
   
   ✅ lib/ui/components/button/button_theme.dart
      • Upstream: No changes
      • Result: Keep your version ✏️

💾 Creating backup...
   ✅ Backup saved to .shadcn/backups/button/1.0.0

🚀 Applying updates...
   ✅ Merged 1 file
   ✅ Kept 1 file
   ✅ Updated to 1.2.0

✨ Success! Your modifications were preserved.
   View with: flutter pub global run flutter_shadcn status button
```

### Update with Conflicts

```
$ flutter pub global run flutter_shadcn update button

📦 Checking for updates...
   Registry version: 1.2.0 (current: 1.0.0)

🔍 Analyzing changes...
   ✅ lib/ui/components/button/button.dart
      • Upstream: Added dark mode
      • You: Custom animation
      • Result: Auto-mergeable ✨
   
   ⚠️ lib/ui/components/button/button_theme.dart
      • Upstream: Refactored theme structure
      • You: Modified colors
      • Result: CONFLICT ❌

═══════════════════════════════════════════════════════════════
⚠️ CONFLICT: lib/ui/components/button/button_theme.dart
═══════════════════════════════════════════════════════════════

YOUR VERSION (Current):
  1 │ final buttonTheme = ThemeData(
  2 │   primary: Color(0xFF6200EA),
  3 │   secondary: Color(0xFF03DAC6),
  4 │ );

UPSTREAM VERSION (New):
  1 │ final buttonTheme = ThemeData(
  2 │   primary: ColorScheme.fromSeed(
  3 │     seedColor: Color(0xFF6200EA),
  4 │   ),
  5 │ );

How would you like to resolve this conflict?
  1. Keep YOUR version
  2. Accept UPSTREAM version
  3. Open in editor for manual merge
  4. Skip for now

> 1

✅ RESOLVED: Keeping your version
   You can update to upstream later with: flutter pub global run flutter_shadcn conflicts button

💾 Creating backup...
   ✅ Backup saved to .shadcn/backups/button/1.0.0

🚀 Applying updates...
   ✅ Auto-merged 1 file
   ✅ Resolved 1 conflict (kept yours)

⏳ Still pending:
   • Use 'flutter pub global run flutter_shadcn conflicts button' to review later

✨ Done! (with unresolved conflict management)
```

### Status Command Output

```
$ flutter pub global run flutter_shadcn status

📦 Installed Components

✅ button (v1.2.0)
   ✏️ User modifications detected
   
✅ card (v1.0.0)
   ✓ No modifications
   
⚠️ input (v1.1.0)
   ✏️ User modifications detected
   
❌ dropdown (v0.9.0)
   ⏳ Has unresolved conflicts

---
Summary:
  4 components installed
  2 with user modifications
  1 with conflicts
```

---

## 8. Performance Considerations

### File Size Thresholds

```
Small Files (< 1 KB):
├─→ Full content comparison OK
├─→ Line-based diff fine
└─→ Memory not a concern

Medium Files (1-100 KB):
├─→ Use checksums first
├─→ Only diff if checksums differ
└─→ Cache checksums in manifest

Large Files (> 100 KB):
├─→ Always use checksums
├─→ Don't load full content unless necessary
├─→ Use chunked processing
└─→ Stream-based diff for very large files
```

### Optimization Strategy

```
Update Process Timeline:
│
├─→ Load Manifest (< 100ms)
│
├─→ Check Local Checksums (< 500ms)
│   └─→ Already in manifest, instant!
│
├─→ Fetch Registry Info (1-2s)
│   └─→ Network call, can't optimize much
│
├─→ Compare Checksums (< 10ms)
│   └─→ String comparison only
│
├─→ Analyze Diffs (10-500ms)
│   └─→ Only for changed files
│   └─→ Skip if checksums match
│
├─→ Get User Input (~ user time)
│   └─→ Display UI, wait for selection
│
├─→ Create Backup (1-5s)
│   └─→ File I/O, can't optimize much
│
└─→ Apply Changes (100-500ms)
    └─→ Write files, update manifest
    └─→ Parallel file writes if possible

TOTAL: ~5-10 seconds typical
TARGET: Keep under 30 seconds for responsive UX
```

---

## 9. Decision Tree for Different Scenarios

### Scenario: User Has Minor Modifications

```
User modified: ButtonStyle color
Registry changed: Added dark mode theme

Decision Flow:
├─→ Are changes on different lines? YES
├─→ Can we auto-merge? YES
├─→ Action: AUTO-MERGE ✨
│   Result: User keeps color customization + gets dark mode

User experience: Seamless, no action needed ✅
```

### Scenario: User Has Major Customizations

```
User modified: Complete ButtonStyle refactor
Registry changed: Major API restructure

Decision Flow:
├─→ Are changes on same lines? YES
├─→ Can we auto-merge? NO
├─→ Show CONFLICT ⚠️
├─→ Present options:
│   1. Keep your customizations (may break compatibility)
│   2. Accept new API (lose customizations)
│   3. Manually merge both approaches
│   4. Skip and decide later
├─→ User chooses: Manual merge
├─→ Open editor with conflict markers
└─→ User carefully merges both approaches

User experience: Requires manual effort, but preserves control ✏️
```

### Scenario: Upstream Deletes Component File

```
Registry removed: button_variants.dart
User hasn't modified: button_variants.dart

Decision Flow:
├─→ Upstream deleted file? YES
├─→ Did user modify it? NO
├─→ Action: AUTO-DELETE ✅
│   Result: File removed silently

User experience: Automatic cleanup ✅
```

---

## 10. Testing Matrices

### Checksum Comparison Matrix

```
Base    Current  Upstream  → Decision        → Action
─────────────────────────────────────────────────────
A       A        A         → CLEAN            ✅ None
A       A        B         → FAST-FORWARD     ⬆️ Apply B
A       B        A         → KEEP-LOCAL       🎯 Keep B
A       B        B         → CONVERGED        ✅ Use B
A       B        C         → Check overlaps   ❓ Auto/Conflict
```

### Three Versions Scenarios

```
Scenario 1: Simple upstream update, no user changes
┌────────┬────────┬────────┐
│ Base   │ User   │ Upstream
├────────┼────────┼────────┤
│ v1.0   │ v1.0   │ v1.5   │ → Apply upstream ⬆️
└────────┴────────┴────────┘

Scenario 2: User customized, upstream also changed
┌────────┬────────┬────────┐
│ Base   │ User   │ Upstream
├────────┼────────┼────────┤
│ v1.0   │ v1.0+  │ v1.5   │ → Different regions → Auto-merge ✨
│        │ custom │        │
└────────┴────────┴────────┘

Scenario 3: Conflicting changes on same code
┌────────┬────────┬────────┐
│ Base   │ User   │ Upstream
├────────┼────────┼────────┤
│ v1.0   │ v1.0+A │ v1.0+B │ → Same area → CONFLICT ⚠️
│        │        │        │   → Ask user
└────────┴────────┴────────┘

Scenario 4: Both changed to same thing
┌────────┬────────┬────────┐
│ Base   │ User   │ Upstream
├────────┼────────┼────────┤
│ v1.0   │ v1.5   │ v1.5   │ → Same result → CLEAN ✅
└────────┴────────┴────────┘
```

---

This visual reference guide should help your team understand the conflict resolution strategy at a glance!
