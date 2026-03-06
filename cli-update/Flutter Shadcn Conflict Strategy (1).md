# Flutter Shadcn CLI - Conflict Resolution Strategy

## 1. Architecture Overview

### 1.1 Version Tracking System

**Manifest File Structure** (`.shadcn/installed.json`):
```json
{
  "version": "1.0.0",
  "registryVersion": "1.2.0",
  "lastUpdatedAt": "2026-01-30T10:00:00Z",
  "components": {
    "button": {
      "version": "1.0.0",
      "registryVersion": "a1b2c3d4e5f6",
      "installedAt": "2026-01-20T15:30:00Z",
      "status": "clean",
      "files": {
        "lib/ui/components/button/button.dart": {
          "source": "registry/button/button.dart",
          "checksum": "sha256:abc123...",
          "baseChecksum": "sha256:abc123...",
          "size": 2048,
          "lastModified": "2026-01-25T10:00:00Z",
          "userModified": true
        },
        "lib/ui/components/button/button_theme.dart": {
          "source": "registry/button/button_theme.dart",
          "checksum": "sha256:def456...",
          "baseChecksum": "sha256:def456...",
          "size": 1024,
          "userModified": false
        }
      },
      "dependencies": ["core/theme", "core/utils"],
      "metadata": {
        "author": "shadcn",
        "license": "MIT",
        "tags": ["input", "form"]
      }
    }
  },
  "conflictHistory": [],
  "backups": {
    "button": {
      "1.0.0": ".shadcn/backups/button/1.0.0"
    }
  }
}
```

### 1.2 Checksum Generation Strategy

```dart
// lib/utils/checksum.dart

import 'dart:convert';
import 'package:crypto/crypto.dart';

class ChecksumManager {
  /// Generate SHA256 checksum for file content
  static String generateChecksum(String content) {
    return sha256.convert(utf8.encode(content)).toString();
  }
  
  /// Generate checksum for file with metadata ignored
  /// (ignores comments, whitespace variations)
  static String generateNormalizedChecksum(String content) {
    final normalized = _normalizeContent(content);
    return sha256.convert(utf8.encode(normalized)).toString();
  }
  
  /// Normalize content by removing inconsequential differences
  static String _normalizeContent(String content) {
    // Remove comments, trim whitespace, normalize imports
    return content
        .split('\n')
        .where((line) {
          final trimmed = line.trim();
          return !trimmed.startsWith('//') && 
                 !trimmed.startsWith('/*') &&
                 trimmed.isNotEmpty;
        })
        .map((line) => line.trim())
        .join('\n');
  }
  
  /// Compare checksums with tolerance for formatting
  static bool checksumEqual(String checksum1, String checksum2) {
    return checksum1 == checksum2;
  }
}
```

---

## 2. Three-Way Merge System

### 2.1 Merge State Detection

```dart
// lib/services/merge/conflict_detector.dart

enum MergeState {
  // No changes
  clean,
  
  // Only upstream changed
  fastForward,
  
  // Only user changed
  keepLocal,
  
  // Both changed but compatible
  autoMergeable,
  
  // Both changed incompatibly
  conflict,
  
  // User deleted, upstream changed
  deleteConflict,
  
  // Upstream deleted, user changed
  deletedByUpstream,
}

class ConflictDetector {
  /// Detect merge state between three versions
  static MergeState detectMergeState({
    required String? base,        // Original version
    required String current,       // User's version
    required String? upstream,     // New version from registry
  }) {
    // Handle deletions
    if (upstream == null && current != base) {
      return MergeState.deletedByUpstream;
    }
    if (current == base && upstream == null) {
      return MergeState.clean; // Already deleted
    }
    if (base == null) {
      return MergeState.clean; // New file
    }
    
    // Check if only one side changed
    if (current == base && upstream != base) {
      return MergeState.fastForward;
    }
    if (upstream == base && current != base) {
      return MergeState.keepLocal;
    }
    
    // Both sides unchanged
    if (current == base && upstream == base) {
      return MergeState.clean;
    }
    
    // Both changed - try to auto-merge
    if (current != base && upstream != base && current != upstream) {
      final canAutoMerge = _canAutoMerge(base, current, upstream);
      return canAutoMerge ? MergeState.autoMergeable : MergeState.conflict;
    }
    
    if (current == upstream) {
      return MergeState.clean;
    }
    
    return MergeState.conflict;
  }
  
  /// Check if changes can be automatically merged (line-based)
  static bool _canAutoMerge(String base, String current, String upstream) {
    final baseLines = base.split('\n');
    final currentLines = current.split('\n');
    final upstreamLines = upstream.split('\n');
    
    // Simple heuristic: if changes don't overlap in line ranges, auto-merge
    final baseChangedLines = _getChangedLineNumbers(baseLines, currentLines);
    final upstreamChangedLines = _getChangedLineNumbers(baseLines, upstreamLines);
    
    // Check if line ranges overlap
    for (final line in baseChangedLines) {
      if (upstreamChangedLines.contains(line)) {
        return false; // Overlapping changes
      }
    }
    
    return true; // Non-overlapping, can auto-merge
  }
  
  static Set<int> _getChangedLineNumbers(List<String> base, List<String> modified) {
    final changed = <int>{};
    for (int i = 0; i < base.length && i < modified.length; i++) {
      if (base[i] != modified[i]) {
        changed.add(i);
      }
    }
    return changed;
  }
}
```

### 2.2 Automatic Merge Implementation

```dart
// lib/services/merge/auto_merger.dart

class AutoMerger {
  /// Perform three-way merge
  static String? merge({
    required String base,
    required String current,
    required String upstream,
  }) {
    final baseLines = base.split('\n');
    final currentLines = current.split('\n');
    final upstreamLines = upstream.split('\n');
    
    final merged = <String>[];
    
    // Use a simple line-based merge strategy
    int i = 0, j = 0, k = 0;
    
    while (i < baseLines.length || j < currentLines.length || k < upstreamLines.length) {
      final baseLine = i < baseLines.length ? baseLines[i] : null;
      final currentLine = j < currentLines.length ? currentLines[j] : null;
      final upstreamLine = k < upstreamLines.length ? upstreamLines[k] : null;
      
      // All three are the same or one is null
      if (baseLine == currentLine == upstreamLine) {
        if (baseLine != null) {
          merged.add(baseLine);
        }
        i++;
        j++;
        k++;
        continue;
      }
      
      // Only upstream changed
      if (baseLine == currentLine && baseLine != upstreamLine) {
        if (upstreamLine != null) {
          merged.add(upstreamLine);
        }
        i++;
        j++;
        k++;
        continue;
      }
      
      // Only current changed
      if (baseLine == upstreamLine && baseLine != currentLine) {
        if (currentLine != null) {
          merged.add(currentLine);
        }
        i++;
        j++;
        k++;
        continue;
      }
      
      // Both changed - can't auto-merge at line level
      return null;
    }
    
    return merged.join('\n');
  }
}
```

---

## 3. Conflict Resolution Strategies

### 3.1 Strategy Types

```dart
// lib/models/conflict_strategy.dart

enum ConflictResolutionStrategy {
  /// Keep user's version
  ours,
  
  /// Accept upstream version
  theirs,
  
  /// Let user manually edit
  manual,
  
  /// Skip this file for now
  skip,
  
  /// Use auto-merge algorithm
  auto,
  
  /// Interactive resolution (show diff and let user choose)
  interactive,
}

class ConflictResolution {
  final String filePath;
  final String base;
  final String current;
  final String upstream;
  final ConflictResolutionStrategy strategy;
  final DateTime detectedAt;
  final String? userNotes;
  
  ConflictResolution({
    required this.filePath,
    required this.base,
    required this.current,
    required this.upstream,
    required this.strategy,
    required this.detectedAt,
    this.userNotes,
  });
  
  /// Apply the resolution and return merged content
  String resolve() {
    switch (strategy) {
      case ConflictResolutionStrategy.ours:
        return current;
      case ConflictResolutionStrategy.theirs:
        return upstream;
      case ConflictResolutionStrategy.auto:
        return AutoMerger.merge(
          base: base,
          current: current,
          upstream: upstream,
        ) ?? current; // Fallback to ours
      default:
        throw Exception('Cannot auto-resolve with $strategy');
    }
  }
  
  Map<String, dynamic> toJson() {
    return {
      'filePath': filePath,
      'strategy': strategy.toString().split('.').last,
      'detectedAt': detectedAt.toIso8601String(),
      'userNotes': userNotes,
    };
  }
}
```

### 3.2 Interactive Conflict Resolution

```dart
// lib/services/merge/conflict_resolver.dart

import 'package:cli_menu/cli_menu.dart';

class InteractiveConflictResolver {
  /// Show interactive conflict resolution UI
  static Future<ConflictResolutionStrategy> resolve({
    required String filePath,
    required String base,
    required String current,
    required String upstream,
  }) async {
    print('\n⚠️  CONFLICT DETECTED in: $filePath\n');
    
    // Show unified diff
    _showDiff(base, current, upstream);
    
    // Show menu
    const menu = SimpleMenu(
      title: '\nHow would you like to resolve this conflict?',
      children: [
        MenuItem(title: '📥 Accept UPSTREAM version', value: ConflictResolutionStrategy.theirs),
        MenuItem(title: '📤 Keep YOUR version', value: ConflictResolutionStrategy.ours),
        MenuItem(title: '✏️  Open in editor for manual merge', value: ConflictResolutionStrategy.manual),
        MenuItem(title: '⏭️  Skip for now (resolve later)', value: ConflictResolutionStrategy.skip),
      ],
    );
    
    return menu.prompt() as ConflictResolutionStrategy;
  }
  
  static void _showDiff(String base, String current, String upstream) {
    print('═══════════════════════════════════════\n');
    print('YOUR VERSION (Current):\n');
    _printWithLineNumbers(current, color: '\u001b[32m'); // Green
    
    print('\n───────────────────────────────────────\n');
    print('UPSTREAM VERSION (New):\n');
    _printWithLineNumbers(upstream, color: '\u001b[34m'); // Blue
    
    print('\n═══════════════════════════════════════\n');
  }
  
  static void _printWithLineNumbers(String content, {required String color}) {
    final lines = content.split('\n');
    for (int i = 0; i < lines.length; i++) {
      print('$color${(i + 1).toString().padLeft(3)} │$color ${lines[i]}');
    }
  }
}
```

---

## 4. CLI Command Design

### 4.1 Update Command with Dry-Run

```bash
# Check for updates without applying them
flutter pub global run flutter_shadcn update --check

# Update specific component
flutter pub global run flutter_shadcn update button

# Update multiple components
flutter pub global run flutter_shadcn update button card input

# Force update (always use upstream)
flutter pub global run flutter_shadcn update button --strategy theirs

# Update all components
flutter pub global run flutter_shadcn update --all

# Dry-run to see what would change
flutter pub global run flutter_shadcn update button --dry-run
```

### 4.2 Status Command

```bash
# Show all installed components and their status
flutter pub global run flutter_shadcn status

# Show details for specific component
flutter pub global run flutter_shadcn status button

# Show only components with conflicts
flutter pub global run flutter_shadcn status --conflicts-only

# Show components with user modifications
flutter pub global run flutter_shadcn status --modified-only
```

### 4.3 Rollback Command

```bash
# Rollback component to previous version
flutter pub global run flutter_shadcn rollback button

# Rollback to specific version
flutter pub global run flutter_shadcn rollback button --version 1.0.0

# Show rollback history
flutter pub global run flutter_shadcn rollback --history button

# Rollback all components
flutter pub global run flutter_shadcn rollback --all
```

---

## 5. Implementation Plan

### Phase 1: Foundation (Week 1)
- [ ] Create `installed.json` schema
- [ ] Implement checksum generation and validation
- [ ] Build basic version tracking in manifest
- [ ] Create file backup system

**Files to create:**
- `lib/models/manifest.dart`
- `lib/utils/checksum.dart`
- `lib/services/backup_service.dart`
- `lib/services/manifest_service.dart`

### Phase 2: Diff & Detection (Week 2)
- [ ] Implement three-way diff detection
- [ ] Build conflict detector with `MergeState` enum
- [ ] Create diff visualization
- [ ] Add test coverage for edge cases

**Files to create:**
- `lib/services/merge/conflict_detector.dart`
- `lib/services/merge/diff_viewer.dart`
- `test/services/merge/conflict_detector_test.dart`

### Phase 3: Merging (Week 3)
- [ ] Implement auto-merger algorithm
- [ ] Build interactive resolver UI
- [ ] Add conflict storage in manifest
- [ ] Create merge strategy system

**Files to create:**
- `lib/services/merge/auto_merger.dart`
- `lib/services/merge/conflict_resolver.dart`
- `lib/models/conflict_resolution.dart`

### Phase 4: CLI Commands (Week 4)
- [ ] Implement `update` command with all options
- [ ] Implement `status` command
- [ ] Implement `rollback` command
- [ ] Add integration tests

**Files to create:**
- `lib/commands/update_command.dart`
- `lib/commands/status_command.dart`
- `lib/commands/rollback_command.dart`

### Phase 5: Polish & Testing (Week 5)
- [ ] Performance optimization
- [ ] Better error messages
- [ ] Documentation
- [ ] E2E testing

---

## 6. Data Structures & Models

```dart
// lib/models/component_metadata.dart

class ComponentMetadata {
  final String name;
  final String version;
  final String registryVersion;
  final DateTime installedAt;
  final DateTime lastModified;
  final bool hasUserModifications;
  final List<ComponentFile> files;
  final List<String> dependencies;
  final ConflictStatus conflictStatus;
  
  ComponentMetadata({
    required this.name,
    required this.version,
    required this.registryVersion,
    required this.installedAt,
    required this.lastModified,
    required this.hasUserModifications,
    required this.files,
    required this.dependencies,
    required this.conflictStatus,
  });
}

class ComponentFile {
  final String path;
  final String source;
  final String checksum;
  final String baseChecksum;
  final int size;
  final bool userModified;
  final DateTime lastModified;
  
  ComponentFile({
    required this.path,
    required this.source,
    required this.checksum,
    required this.baseChecksum,
    required this.size,
    required this.userModified,
    required this.lastModified,
  });
}

enum ConflictStatus {
  clean,
  modified,
  conflict,
  pendingResolution,
}
```

---

## 7. Example Workflow

```
$ flutter pub global run flutter_shadcn update button

📦 Checking for updates...
   Registry version: 1.2.0 (current: 1.0.0)

🔍 Analyzing changes...
   ✅ lib/ui/components/button/button.dart - Auto-mergeable
      • Upstream: Added dark mode support
      • You: Added custom animation
      
   ⚠️  lib/ui/components/button/button_theme.dart - CONFLICT
      • Upstream: Refactored theme structure
      • You: Modified color variables
      
   ⏭️  lib/ui/components/button/button_test.dart - Only upstream changed (auto-merge)

📝 Review changes? (y/n): y

═══════════════════════════════════════════════════════════════
CONFLICT: lib/ui/components/button/button_theme.dart
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
  📥 Accept UPSTREAM version
  📤 Keep YOUR version
  ✏️  Open in editor for manual merge
  ⏭️  Skip for now

> 📤 Keep YOUR version

✅ RESOLVED: Keeping your version (use 'rollback' later if needed)

📊 Summary:
   ✅ 2 files auto-merged
   ✅ 1 file kept (user choice)
   ⏳ 0 files pending

💾 Creating backup before update...
   Backup saved: .shadcn/backups/button/1.0.0

🚀 Applying updates...
✨ Successfully updated 'button' from 1.0.0 → 1.2.0

📋 Conflict record saved. View with: flutter pub global run flutter_shadcn conflicts button
```

---

## 8. Conflict History & Tracking

```dart
// lib/models/conflict_record.dart

class ConflictRecord {
  final String id;
  final String componentName;
  final String fromVersion;
  final String toVersion;
  final DateTime detectedAt;
  final DateTime? resolvedAt;
  final List<ConflictDetail> details;
  final ConflictStatus status;
  
  ConflictRecord({
    required this.id,
    required this.componentName,
    required this.fromVersion,
    required this.toVersion,
    required this.detectedAt,
    this.resolvedAt,
    required this.details,
    required this.status,
  });
}

class ConflictDetail {
  final String filePath;
  final String diff;
  final ConflictResolutionStrategy resolvedWith;
  final String? notes;
  
  ConflictDetail({
    required this.filePath,
    required this.diff,
    required this.resolvedWith,
    this.notes,
  });
}

// Stored in .shadcn/conflicts.json
```

---

## 9. Best Practices

### 9.1 For Component Authors
- Keep component files focused and modular
- Use clear, descriptive variable/class names
- Add comments for complex logic that users might modify
- Maintain stable import paths and public APIs
- Document breaking changes clearly

### 9.2 For Component Users
- Make minimal, targeted modifications
- Add comments explaining your customizations
- Keep a `.shadcn/modified.md` documenting changes
- Review updates in dry-run mode first
- Test thoroughly after merging

### 9.3 For CLI Implementation
- Always create backups before applying changes
- Store conflict history for debugging
- Provide clear, actionable diff output
- Make rollback trivial
- Validate checksums before and after operations

---

## 10. Handling Special Cases

### 10.1 File Deletion
- If user deleted a file but upstream changed it → Ask user
- If upstream deleted but user modified → Show warning, let user decide

### 10.2 File Addition
- If upstream added new files → Auto-add them
- If user added same file with different content → Flag as conflict

### 10.3 Directory Structure Changes
- Track directory paths in manifest
- Handle directory renames (compare file paths, not just names)
- Validate all dependencies still exist after update

### 10.4 Dependency Updates
- If component A depends on component B, and B is updated:
  - Offer to update B alongside A
  - Flag version incompatibility warnings
  - Suggest checking `pubspec.yaml` version constraints

---

## 11. Edge Cases to Handle

1. **Circular dependencies**: Detect and warn
2. **Same file in multiple locations**: Dedup based on checksum
3. **Binary files**: Compare by checksum only, don't try to merge
4. **Very large files**: Use efficient diff algorithms (consider `google_diff_match_patch`)
5. **Partial updates**: Allow updating subset of files from a component
6. **Version mismatch**: Registry component version doesn't match installed
7. **Corrupted manifest**: Recovery/rebuild from file checksums

---

## 12. Future Enhancements

- **Semantic versioning awareness**: Suggest strategies based on version bump (major/minor/patch)
- **ML-based merge**: Learn from user's conflict resolutions to suggest strategies
- **Patch generation**: Create `.patch` files for user modifications to reapply on updates
- **Component inheritance**: Allow "extend component" functionality
- **Collaboration**: Store conflict resolutions and share with team
- **Performance**: Cache diffs, parallel processing for large updates
- **IDE integration**: VS Code extension for visual conflict resolution
