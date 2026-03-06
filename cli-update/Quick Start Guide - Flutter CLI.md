# Flutter Shadcn CLI - Conflict Resolution Implementation Guide

## Quick Start (Pick Your Path)

### Path A: Start Simple (Recommended for MVP)
**Timeline: 2-3 weeks**

```
Week 1: Version Tracking
├── Add installed.json manifest
├── Implement checksum generation
└── Track file metadata

Week 2: Basic Update Flow
├── Implement checksum comparison
├── Auto-apply non-conflicting changes
└── Show conflicts to user

Week 3: Resolution UI
├── Interactive conflict menu
├── Add ours/theirs strategies
└── Create backup system
```

### Path B: Full Three-Way Merge (Complete Solution)
**Timeline: 4-5 weeks**

All of Path A +
- Week 4: Three-way merge algorithm
- Week 5: Advanced resolution strategies

---

## Step 1: Create Directory Structure

```bash
lib/
├── commands/
│   ├── update_command.dart
│   ├── status_command.dart
│   └── rollback_command.dart
├── models/
│   ├── manifest.dart
│   ├── conflict_resolution.dart
│   └── merge_state.dart
├── services/
│   ├── manifest/
│   │   └── manifest_manager.dart
│   ├── merge/
│   │   ├── conflict_detector.dart
│   │   ├── three_way_merger.dart
│   │   └── conflict_resolver.dart
│   └── backup/
│       └── backup_service.dart
└── utils/
    ├── checksum.dart
    └── diff_viewer.dart
```

---

## Step 2: Create Manifest Model (Week 1)

```dart
// lib/models/manifest.dart

import 'package:json_serializable/json_serializable.dart';

part 'manifest.g.dart';

@JsonSerializable()
class Manifest {
  final String version;
  final String registryVersion;
  final DateTime lastUpdatedAt;
  final Map<String, InstalledComponent> components;
  
  Manifest({
    required this.version,
    required this.registryVersion,
    required this.lastUpdatedAt,
    required this.components,
  });
  
  factory Manifest.fromJson(Map<String, dynamic> json) => 
      _$ManifestFromJson(json);
  
  Map<String, dynamic> toJson() => _$ManifestToJson(this);
}

@JsonSerializable()
class InstalledComponent {
  final String name;
  final String version;
  final String registryVersion;
  final DateTime installedAt;
  final ComponentStatus status;
  final Map<String, ComponentFile> files;
  final List<String> dependencies;
  
  InstalledComponent({
    required this.name,
    required this.version,
    required this.registryVersion,
    required this.installedAt,
    required this.status,
    required this.files,
    required this.dependencies,
  });
  
  factory InstalledComponent.fromJson(Map<String, dynamic> json) =>
      _$InstalledComponentFromJson(json);
  
  Map<String, dynamic> toJson() => _$InstalledComponentToJson(this);
}

@JsonSerializable()
class ComponentFile {
  final String path;
  final String source;
  final String checksum;
  final String baseChecksum; // Checksum when installed
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
  
  factory ComponentFile.fromJson(Map<String, dynamic> json) =>
      _$ComponentFileFromJson(json);
  
  Map<String, dynamic> toJson() => _$ComponentFileToJson(this);
  
  /// Check if file has been modified by user
  bool isUserModified(String newChecksum) {
    return baseChecksum != newChecksum;
  }
}

enum ComponentStatus {
  clean,
  modified,
  conflict,
  pendingUpdate,
  error,
}
```

---

## Step 3: Implement Checksum Utilities (Week 1)

```dart
// lib/utils/checksum.dart

import 'dart:convert';
import 'package:crypto/crypto.dart';

class ChecksumManager {
  /// Generate SHA256 checksum for content
  static String generate(String content) {
    return sha256.convert(utf8.encode(content)).toString();
  }
  
  /// Compare two checksums
  static bool equal(String checksum1, String checksum2) {
    return checksum1 == checksum2;
  }
  
  /// Quick check: only first/last 100 chars
  /// Use for fast detection before deep comparison
  static bool quickEqual(String content1, String content2) {
    if (content1.length != content2.length) return false;
    
    final len = content1.length;
    if (len < 200) return content1 == content2;
    
    return content1.substring(0, 100) == content2.substring(0, 100) &&
           content1.substring(len - 100) == content2.substring(len - 100);
  }
  
  /// Normalize Dart code for comparison (ignore formatting)
  static String normalize(String content) {
    return content
        .split('\n')
        .map((line) => line.trim())
        .where((line) => 
          !line.startsWith('//') && 
          !line.isEmpty &&
          line != '/*' && 
          line != '*/')
        .join('\n');
  }
  
  /// Generate checksum of normalized content
  static String generateNormalized(String content) {
    return generate(normalize(content));
  }
}
```

---

## Step 4: Create Manifest Service (Week 1)

```dart
// lib/services/manifest/manifest_manager.dart

import 'dart:io';
import 'dart:convert';
import 'package:flutter_shadcn/models/manifest.dart';

class ManifestManager {
  static const String _manifestPath = '.shadcn/installed.json';
  static const String _backupDir = '.shadcn/backups';
  static const String _conflictsPath = '.shadcn/conflicts.json';
  
  /// Load manifest from disk
  static Future<Manifest> loadManifest() async {
    final file = File(_manifestPath);
    
    if (!await file.exists()) {
      return Manifest(
        version: '1.0.0',
        registryVersion: '',
        lastUpdatedAt: DateTime.now(),
        components: {},
      );
    }
    
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    return Manifest.fromJson(json);
  }
  
  /// Save manifest to disk
  static Future<void> saveManifest(Manifest manifest) async {
    final file = File(_manifestPath);
    await file.create(recursive: true);
    await file.writeAsString(jsonEncode(manifest));
  }
  
  /// Register newly installed component
  static Future<void> registerComponent({
    required String name,
    required String version,
    required String registryVersion,
    required Map<String, String> files, // path -> content
  }) async {
    final manifest = await loadManifest();
    
    final componentFiles = <String, ComponentFile>{};
    
    for (final entry in files.entries) {
      final checksum = ChecksumManager.generate(entry.value);
      componentFiles[entry.key] = ComponentFile(
        path: entry.key,
        source: 'registry/$name/${entry.key}',
        checksum: checksum,
        baseChecksum: checksum, // No user modification yet
        size: entry.value.length,
        userModified: false,
        lastModified: DateTime.now(),
      );
    }
    
    manifest.components[name] = InstalledComponent(
      name: name,
      version: version,
      registryVersion: registryVersion,
      installedAt: DateTime.now(),
      status: ComponentStatus.clean,
      files: componentFiles,
      dependencies: [],
    );
    
    await saveManifest(manifest);
  }
  
  /// Update component after successful merge
  static Future<void> updateComponent({
    required String name,
    required String newVersion,
    required String newRegistryVersion,
    required Map<String, String> files, // Updated content
    required Map<String, bool> userModifications, // Track which files user modified
  }) async {
    final manifest = await loadManifest();
    final component = manifest.components[name];
    
    if (component == null) {
      throw Exception('Component $name not found in manifest');
    }
    
    // Update file data
    final updatedFiles = <String, ComponentFile>{};
    
    for (final entry in files.entries) {
      final newChecksum = ChecksumManager.generate(entry.value);
      final oldFile = component.files[entry.key];
      
      updatedFiles[entry.key] = ComponentFile(
        path: entry.key,
        source: oldFile?.source ?? 'registry/$name/${entry.key}',
        checksum: newChecksum,
        baseChecksum: newChecksum, // Reset base to current
        size: entry.value.length,
        userModified: userModifications[entry.key] ?? false,
        lastModified: DateTime.now(),
      );
    }
    
    component.files.clear();
    component.files.addAll(updatedFiles);
    component.status = _hasConflicts(component) 
      ? ComponentStatus.conflict 
      : ComponentStatus.clean;
    component.version = newVersion;
    component.registryVersion = newRegistryVersion;
    
    await saveManifest(manifest);
  }
  
  /// Mark file as user-modified
  static Future<void> markFileAsModified(
    String componentName,
    String filePath,
  ) async {
    final manifest = await loadManifest();
    final component = manifest.components[componentName];
    
    if (component != null) {
      final file = component.files[filePath];
      if (file != null) {
        component.files[filePath] = ComponentFile(
          path: file.path,
          source: file.source,
          checksum: file.checksum,
          baseChecksum: file.baseChecksum,
          size: file.size,
          userModified: true,
          lastModified: DateTime.now(),
        );
        
        component.status = ComponentStatus.modified;
        await saveManifest(manifest);
      }
    }
  }
  
  /// Create backup before update
  static Future<String> createBackup({
    required String componentName,
    required String version,
    required Map<String, String> files,
  }) async {
    final backupPath = '$_backupDir/$componentName/$version';
    final dir = Directory(backupPath);
    
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    
    // Save manifest snapshot
    await File('$backupPath/manifest.json').writeAsString(
      jsonEncode({
        'component': componentName,
        'version': version,
        'backedUpAt': DateTime.now().toIso8601String(),
      }),
    );
    
    // Save all files
    for (final entry in files.entries) {
      final file = File('$backupPath/${entry.key}');
      await file.create(recursive: true);
      await file.writeAsString(entry.value);
    }
    
    return backupPath;
  }
  
  /// Restore from backup
  static Future<void> restoreFromBackup({
    required String componentName,
    required String version,
  }) async {
    final backupPath = '$_backupDir/$componentName/$version';
    final backupDir = Directory(backupPath);
    
    if (!await backupDir.exists()) {
      throw Exception('Backup not found: $backupPath');
    }
    
    // Restore files (exclude manifest.json)
    await for (final entity in backupDir.list(recursive: true)) {
      if (entity is File && !entity.path.endsWith('manifest.json')) {
        // Restore file to original location
        final relativePath = entity.path.replaceFirst('$backupPath/', '');
        final targetFile = File(relativePath);
        await targetFile.create(recursive: true);
        await targetFile.writeAsBytes(await entity.readAsBytes());
      }
    }
  }
  
  static bool _hasConflicts(InstalledComponent component) {
    // Check if any files have pending conflicts
    // This would be set during conflict detection
    return false; // Implement based on your conflict tracking
  }
}
```

---

## Step 5: Implement Conflict Detector (Week 2)

```dart
// lib/services/merge/conflict_detector.dart

enum MergeState {
  clean,           // No changes
  fastForward,     // Only upstream changed
  keepLocal,       // Only user changed
  autoMergeable,   // Both changed, can merge
  conflict,        // Both changed, conflict
}

class ConflictDetector {
  /// Analyze file to determine merge state
  static MergeState analyze({
    required String? base,      // Original when installed
    required String current,    // User's current version
    required String? upstream,  // New version from registry
  }) {
    // Handle nulls (file deletion/creation)
    if (upstream == null && current != base) {
      return MergeState.clean; // Deleted by upstream, accept deletion
    }
    
    if (base == null || upstream == null) {
      return MergeState.clean; // New file or already deleted
    }
    
    // Simple checksum comparison
    final baseChecksum = ChecksumManager.generate(base);
    final currentChecksum = ChecksumManager.generate(current);
    final upstreamChecksum = ChecksumManager.generate(upstream);
    
    // No changes
    if (currentChecksum == baseChecksum && upstreamChecksum == baseChecksum) {
      return MergeState.clean;
    }
    
    // Only upstream changed
    if (currentChecksum == baseChecksum && upstreamChecksum != baseChecksum) {
      return MergeState.fastForward;
    }
    
    // Only user changed
    if (currentChecksum != baseChecksum && upstreamChecksum == baseChecksum) {
      return MergeState.keepLocal;
    }
    
    // Both changed to same thing
    if (currentChecksum == upstreamChecksum) {
      return MergeState.clean;
    }
    
    // Both changed - check if auto-mergeable
    if (_canAutoMerge(base, current, upstream)) {
      return MergeState.autoMergeable;
    }
    
    return MergeState.conflict;
  }
  
  /// Simple auto-merge check: non-overlapping line changes
  static bool _canAutoMerge(String base, String current, String upstream) {
    final baseLines = base.split('\n');
    final currentLines = current.split('\n');
    final upstreamLines = upstream.split('\n');
    
    // Get changed line ranges
    final currentChanges = _getChangedLineRanges(baseLines, currentLines);
    final upstreamChanges = _getChangedLineRanges(baseLines, upstreamLines);
    
    // Check for overlaps
    for (final currentRange in currentChanges) {
      for (final upstreamRange in upstreamChanges) {
        if (_rangesOverlap(currentRange, upstreamRange)) {
          return false; // Overlapping changes
        }
      }
    }
    
    return true; // No overlaps, can auto-merge
  }
  
  static List<Range> _getChangedLineRanges(
    List<String> base,
    List<String> modified,
  ) {
    final ranges = <Range>[];
    int startIdx = -1;
    
    for (int i = 0; i < base.length && i < modified.length; i++) {
      if (base[i] != modified[i]) {
        if (startIdx == -1) startIdx = i;
      } else {
        if (startIdx != -1) {
          ranges.add(Range(startIdx, i - 1));
          startIdx = -1;
        }
      }
    }
    
    if (startIdx != -1) {
      ranges.add(Range(startIdx, base.length - 1));
    }
    
    return ranges;
  }
  
  static bool _rangesOverlap(Range r1, Range r2) {
    return !(r1.end < r2.start || r2.end < r1.start);
  }
}

class Range {
  final int start;
  final int end;
  
  Range(this.start, this.end);
}
```

---

## Step 6: Create Conflict Resolution UI (Week 2-3)

```dart
// lib/services/merge/conflict_resolver.dart

import 'dart:io';

enum ResolutionStrategy {
  ours,       // Keep user's version
  theirs,     // Accept upstream
  manual,     // User edits file
  skip,       // Resolve later
}

class InteractiveConflictResolver {
  /// Show conflict and get user's choice
  static Future<ResolutionStrategy> resolveInteractive({
    required String filePath,
    required String base,
    required String current,
    required String upstream,
  }) async {
    _printConflictHeader(filePath);
    _printVersions(base, current, upstream);
    
    return _showMenu();
  }
  
  static void _printConflictHeader(String filePath) {
    print('\n');
    print('═' * 60);
    print('⚠️  CONFLICT DETECTED: $filePath');
    print('═' * 60);
    print('\n');
  }
  
  static void _printVersions(String base, String current, String upstream) {
    print('YOUR VERSION (current):');
    print('─' * 60);
    _printWithLineNumbers(current, color: '\u001b[32m'); // Green
    
    print('\n\nUPSTREAM VERSION (new):');
    print('─' * 60);
    _printWithLineNumbers(upstream, color: '\u001b[34m'); // Blue
    
    print('\n');
  }
  
  static void _printWithLineNumbers(String content, {required String color}) {
    final lines = content.split('\n');
    final maxLines = lines.length > 20 ? 20 : lines.length;
    
    for (int i = 0; i < maxLines; i++) {
      final line = lines[i];
      final lineNum = (i + 1).toString().padLeft(3);
      print('$color$lineNum │ $line');
    }
    
    if (lines.length > 20) {
      print('... (${lines.length - 20} more lines)');
    }
  }
  
  static Future<ResolutionStrategy> _showMenu() async {
    print('\nHow would you like to resolve this conflict?\n');
    
    const strategies = [
      ('Keep YOUR version', ResolutionStrategy.ours),
      ('Accept UPSTREAM version', ResolutionStrategy.theirs),
      ('Open in editor for manual merge', ResolutionStrategy.manual),
      ('Skip for now', ResolutionStrategy.skip),
    ];
    
    for (int i = 0; i < strategies.length; i++) {
      print('  ${i + 1}. ${strategies[i].$1}');
    }
    
    print('\nEnter choice (1-${strategies.length}): ');
    
    final choice = stdin.readLineSync();
    if (choice == null) return ResolutionStrategy.skip;
    
    try {
      final idx = int.parse(choice) - 1;
      if (idx >= 0 && idx < strategies.length) {
        return strategies[idx].$2;
      }
    } catch (_) {}
    
    return ResolutionStrategy.skip;
  }
}
```

---

## Step 7: Wire Up Update Command (Week 3-4)

See the cli_commands.dart file for the full UpdateCommand implementation.

Key steps:
1. Check for updates
2. Analyze changes
3. Show conflicts
4. Get resolutions
5. Create backup
6. Apply updates
7. Update manifest

---

## Step 8: Testing Strategy

```dart
// test/services/merge/conflict_detector_test.dart

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ConflictDetector', () {
    test('detects clean when unchanged', () {
      const base = 'final x = 1;';
      const current = 'final x = 1;';
      const upstream = 'final x = 1;';
      
      final state = ConflictDetector.analyze(
        base: base,
        current: current,
        upstream: upstream,
      );
      
      expect(state, MergeState.clean);
    });
    
    test('detects fastForward when only upstream changed', () {
      const base = 'final x = 1;';
      const current = 'final x = 1;';
      const upstream = 'final x = 2;'; // Changed
      
      final state = ConflictDetector.analyze(
        base: base,
        current: current,
        upstream: upstream,
      );
      
      expect(state, MergeState.fastForward);
    });
    
    test('detects keepLocal when only user changed', () {
      const base = 'final x = 1;';
      const current = 'final x = 2;'; // User changed
      const upstream = 'final x = 1;';
      
      final state = ConflictDetector.analyze(
        base: base,
        current: current,
        upstream: upstream,
      );
      
      expect(state, MergeState.keepLocal);
    });
    
    test('detects conflict when both changed same line', () {
      const base = 'final x = 1;';
      const current = 'final x = 2;'; // User changed
      const upstream = 'final x = 3;'; // Upstream changed differently
      
      final state = ConflictDetector.analyze(
        base: base,
        current: current,
        upstream: upstream,
      );
      
      expect(state, MergeState.conflict);
    });
    
    test('detects autoMergeable when non-overlapping changes', () {
      const base = 'line1\nline2\nline3';
      const current = 'line1\nMODIFIED\nline3'; // Modified line 2
      const upstream = 'line1\nline2\nNEW'; // Modified line 3
      
      final state = ConflictDetector.analyze(
        base: base,
        current: current,
        upstream: upstream,
      );
      
      expect(state, MergeState.autoMergeable);
    });
  });
}
```

---

## Implementation Checklist

### Phase 1: Foundation ✓
- [ ] Create directory structure
- [ ] Implement Manifest model
- [ ] Implement ChecksumManager
- [ ] Implement ManifestManager
- [ ] Write basic tests

### Phase 2: Conflict Detection ✓
- [ ] Implement ConflictDetector
- [ ] Create test cases
- [ ] Add diff visualization

### Phase 3: Resolution ✓
- [ ] Implement InteractiveConflictResolver
- [ ] Add ResolutionStrategy enum
- [ ] Create backup system
- [ ] Test all strategies

### Phase 4: CLI Commands ✓
- [ ] Implement UpdateCommand
- [ ] Implement StatusCommand
- [ ] Implement RollbackCommand
- [ ] Integration testing

### Phase 5: Polish
- [ ] Better error messages
- [ ] Performance optimization
- [ ] Documentation
- [ ] E2E testing

---

## Common Pitfalls & Solutions

### Pitfall 1: Not Tracking baseChecksum
**Problem**: User modifications can't be detected after updates
**Solution**: Always store original checksum, compare with current

### Pitfall 2: String Comparisons for Large Files
**Problem**: Slow, memory-intensive
**Solution**: Use checksums first, only read full file if needed

### Pitfall 3: Not Creating Backups
**Problem**: Users lose data if merge goes wrong
**Solution**: ALWAYS backup before modifications

### Pitfall 4: Complex Merge Algorithms
**Problem**: Over-engineering for MVP
**Solution**: Start with line-based, upgrade to proper diff algorithm later

### Pitfall 5: Not Cleaning Up Temp Files
**Problem**: Disk fills up with old backups
**Solution**: Implement backup retention policy (keep last 3 versions)

---

## Next Steps

1. **Start with Phase 1** - Get basic tracking working
2. **Test thoroughly** - Edge cases matter
3. **Get feedback** - Let early users try it
4. **Iterate** - Add features based on feedback
5. **Document** - Write guides for users

Good luck! 🚀
