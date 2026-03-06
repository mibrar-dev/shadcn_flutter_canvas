// lib/services/merge/conflict_detector.dart
// Core conflict detection and merge state determination

import 'package:crypto/crypto.dart';
import 'dart:convert';

enum MergeState {
  clean,              // No changes needed
  fastForward,        // Only upstream changed
  keepLocal,          // Only user changed
  autoMergeable,      // Both changed, non-overlapping
  conflict,           // Both changed, overlapping
  deletedByUpstream,  // Upstream deleted, user didn't
  deletedByUser,      // User deleted, upstream didn't
}

class FileVersion {
  final String? content;
  final String? checksum;
  final DateTime? modifiedAt;
  
  FileVersion({
    this.content,
    this.checksum,
    this.modifiedAt,
  });
  
  factory FileVersion.fromContent(String content) {
    return FileVersion(
      content: content,
      checksum: sha256.convert(utf8.encode(content)).toString(),
      modifiedAt: DateTime.now(),
    );
  }
  
  bool get exists => content != null;
}

class ConflictDetector {
  /// Three-way merge analysis
  static MergeState detectMergeState({
    required FileVersion base,        // Original version when installed
    required FileVersion current,     // User's current version
    required FileVersion upstream,    // New version from registry
  }) {
    // Handle complete deletions
    if (!upstream.exists && current.exists && base.exists) {
      return MergeState.deletedByUpstream;
    }
    
    if (!current.exists && upstream.exists && base.exists) {
      return MergeState.deletedByUser;
    }
    
    // If current is same as base - check upstream
    if (current.checksum == base.checksum) {
      if (upstream.checksum == base.checksum) {
        return MergeState.clean;
      }
      return MergeState.fastForward; // Only upstream changed
    }
    
    // If upstream is same as base - check current
    if (upstream.checksum == base.checksum) {
      return MergeState.keepLocal; // Only current changed
    }
    
    // If all are different - try to merge
    if (current.checksum == upstream.checksum) {
      return MergeState.clean; // Changed to same thing
    }
    
    // Both changed differently - analyze for auto-merge possibility
    if (_canAutoMerge(base.content!, current.content!, upstream.content!)) {
      return MergeState.autoMergeable;
    }
    
    return MergeState.conflict;
  }
  
  /// Check if changes can be automatically merged
  static bool _canAutoMerge(String base, String current, String upstream) {
    final baseLines = base.split('\n');
    final currentLines = current.split('\n');
    final upstreamLines = upstream.split('\n');
    
    // Get line numbers that changed
    final currentChanges = _getChangedLines(baseLines, currentLines);
    final upstreamChanges = _getChangedLines(baseLines, upstreamLines);
    
    // If no overlapping changes, we can merge
    for (final lineNum in currentChanges.keys) {
      if (upstreamChanges.containsKey(lineNum)) {
        // Changed in both - check if changed to same thing
        if (currentChanges[lineNum] != upstreamChanges[lineNum]) {
          return false; // Different changes on same line
        }
      }
    }
    
    return true; // Non-overlapping or identical changes
  }
  
  /// Get map of changed line numbers to their content
  static Map<int, String> _getChangedLines(
    List<String> base,
    List<String> modified,
  ) {
    final changes = <int, String>{};
    
    final maxLen = base.length > modified.length ? base.length : modified.length;
    
    for (int i = 0; i < maxLen; i++) {
      final baseLine = i < base.length ? base[i] : '';
      final modifiedLine = i < modified.length ? modified[i] : '';
      
      if (baseLine != modifiedLine) {
        changes[i] = modifiedLine;
      }
    }
    
    return changes;
  }
}

// lib/services/merge/three_way_merger.dart
// Actual three-way merge algorithm

class ThreeWayMerger {
  /// Perform three-way merge using patience diff algorithm
  static MergeResult? merge({
    required String base,
    required String current,
    required String upstream,
  }) {
    final baseLines = base.split('\n');
    final currentLines = current.split('\n');
    final upstreamLines = upstream.split('\n');
    
    final merged = <String>[];
    final conflicts = <MergeConflict>[];
    
    // Simple line-based merge
    final basePatches = _computePatches(baseLines, currentLines);
    final upstreamPatches = _computePatches(baseLines, upstreamLines);
    
    // Apply non-conflicting patches
    int baseIdx = 0;
    for (final patch in basePatches) {
      // Check if upstream also modified this region
      bool upstreamConflicts = false;
      for (final upstreamPatch in upstreamPatches) {
        if (_patchesOverlap(patch, upstreamPatch)) {
          upstreamConflicts = true;
          break;
        }
      }
      
      if (!upstreamConflicts) {
        merged.addAll(patch.newLines);
      } else {
        // Create merge conflict marker
        final conflict = MergeConflict(
          startLine: baseIdx,
          currentLines: patch.newLines,
          upstreamLines: upstreamPatches
              .firstWhere((p) => _patchesOverlap(patch, p))
              .newLines,
          baseLines: patch.oldLines,
        );
        conflicts.add(conflict);
        merged.addAll(_createConflictMarkers(conflict));
      }
      baseIdx += patch.oldLines.length;
    }
    
    if (conflicts.isEmpty) {
      return MergeResult(
        content: merged.join('\n'),
        conflicts: [],
        hasConflicts: false,
      );
    }
    
    return MergeResult(
      content: merged.join('\n'),
      conflicts: conflicts,
      hasConflicts: true,
    );
  }
  
  static List<Patch> _computePatches(List<String> base, List<String> modified) {
    final patches = <Patch>[];
    var i = 0;
    var j = 0;
    
    while (i < base.length && j < modified.length) {
      if (base[i] == modified[j]) {
        i++;
        j++;
        continue;
      }
      
      // Found a difference - collect it
      final startBase = i;
      final startModified = j;
      final oldLines = <String>[];
      final newLines = <String>[];
      
      // Collect all different lines
      while (i < base.length && (j >= modified.length || base[i] != modified[j])) {
        oldLines.add(base[i]);
        i++;
      }
      
      while (j < modified.length && (i >= base.length || base[i] != modified[j])) {
        newLines.add(modified[j]);
        j++;
      }
      
      patches.add(Patch(
        startLine: startBase,
        oldLines: oldLines,
        newLines: newLines,
      ));
    }
    
    // Handle remaining lines
    if (i < base.length) {
      patches.add(Patch(
        startLine: i,
        oldLines: base.sublist(i),
        newLines: [],
      ));
    }
    
    if (j < modified.length) {
      patches.add(Patch(
        startLine: i,
        oldLines: [],
        newLines: modified.sublist(j),
      ));
    }
    
    return patches;
  }
  
  static bool _patchesOverlap(Patch p1, Patch p2) {
    return (p1.startLine < p2.startLine + p2.oldLines.length) &&
        (p2.startLine < p1.startLine + p1.oldLines.length);
  }
  
  static List<String> _createConflictMarkers(MergeConflict conflict) {
    return [
      '<<<<<<< CURRENT',
      ...conflict.currentLines,
      '||||||| BASE',
      ...conflict.baseLines,
      '=======',
      ...conflict.upstreamLines,
      '>>>>>>> UPSTREAM',
    ];
  }
}

class Patch {
  final int startLine;
  final List<String> oldLines;
  final List<String> newLines;
  
  Patch({
    required this.startLine,
    required this.oldLines,
    required this.newLines,
  });
}

class MergeConflict {
  final int startLine;
  final List<String> baseLines;
  final List<String> currentLines;
  final List<String> upstreamLines;
  
  MergeConflict({
    required this.startLine,
    required this.baseLines,
    required this.currentLines,
    required this.upstreamLines,
  });
  
  String get unified {
    return '''
CONFLICT at line $startLine:
══════════════════════════════════════
BASE VERSION:
${baseLines.join('\n')}
──────────────────────────────────────
YOUR VERSION:
${currentLines.join('\n')}
──────────────────────────────────────
UPSTREAM VERSION:
${upstreamLines.join('\n')}
══════════════════════════════════════
    ''';
  }
}

class MergeResult {
  final String content;
  final List<MergeConflict> conflicts;
  final bool hasConflicts;
  
  MergeResult({
    required this.content,
    required this.conflicts,
    required this.hasConflicts,
  });
}

// lib/services/merge/conflict_strategy.dart
// Strategy pattern for conflict resolution

enum ResolutionStrategy {
  ours,      // Keep user's version
  theirs,    // Accept upstream
  auto,      // Auto-merge if possible
  manual,    // Let user edit
  skip,      // Skip for now
}

abstract class StrategyResolver {
  Future<String> resolve({
    required String base,
    required String current,
    required String upstream,
    required MergeState state,
  });
}

class OursResolver implements StrategyResolver {
  @override
  Future<String> resolve({
    required String base,
    required String current,
    required String upstream,
    required MergeState state,
  }) async {
    return current; // Always keep user's version
  }
}

class TheirsResolver implements StrategyResolver {
  @override
  Future<String> resolve({
    required String base,
    required String current,
    required String upstream,
    required MergeState state,
  }) async {
    return upstream; // Always accept upstream
  }
}

class AutoResolver implements StrategyResolver {
  @override
  Future<String> resolve({
    required String base,
    required String current,
    required String upstream,
    required MergeState state,
  }) async {
    switch (state) {
      case MergeState.clean:
      case MergeState.fastForward:
        return upstream;
      case MergeState.keepLocal:
        return current;
      case MergeState.autoMergeable:
        return ThreeWayMerger.merge(
          base: base,
          current: current,
          upstream: upstream,
        )?.content ?? current;
      default:
        throw Exception('Cannot auto-resolve state: $state');
    }
  }
}

class ManualResolver implements StrategyResolver {
  @override
  Future<String> resolve({
    required String base,
    required String current,
    required String upstream,
    required MergeState state,
  }) async {
    // This would open an editor or provide interactive UI
    throw UnimplementedError('Manual resolution requires user interaction');
  }
}

// lib/services/manifest/manifest_manager.dart
// Manage the installed.json manifest

import 'dart:io';
import 'package:json_serializable/json_serializable.dart';

class ManifestManager {
  static const String manifestPath = '.shadcn/installed.json';
  static const String conflictsPath = '.shadcn/conflicts.json';
  static const String backupDir = '.shadcn/backups';
  
  /// Initialize manifest for new component
  static Future<void> initializeComponent({
    required String componentName,
    required String version,
    required String registryVersion,
    required Map<String, String> files, // path -> content
  }) async {
    final manifest = await _loadManifest();
    
    final checksums = <String, String>{};
    for (final entry in files.entries) {
      checksums[entry.key] = sha256.convert(utf8.encode(entry.value)).toString();
    }
    
    manifest['components'] ??= {};
    manifest['components'][componentName] = {
      'version': version,
      'registryVersion': registryVersion,
      'installedAt': DateTime.now().toIso8601String(),
      'status': 'clean',
      'files': {
        for (final path in files.keys)
          path: {
            'checksum': checksums[path],
            'baseChecksum': checksums[path],
            'size': files[path]!.length,
            'userModified': false,
            'lastModified': DateTime.now().toIso8601String(),
          }
      },
      'dependencies': [],
    };
    
    await _saveManifest(manifest);
  }
  
  /// Record a file conflict
  static Future<void> recordConflict({
    required String componentName,
    required String filePath,
    required MergeConflict conflict,
    required ResolutionStrategy resolution,
  }) async {
    final conflicts = await _loadConflicts();
    
    conflicts.add({
      'componentName': componentName,
      'filePath': filePath,
      'detectedAt': DateTime.now().toIso8601String(),
      'baseLines': conflict.baseLines,
      'currentLines': conflict.currentLines,
      'upstreamLines': conflict.upstreamLines,
      'resolution': resolution.toString().split('.').last,
    });
    
    await _saveConflicts(conflicts);
  }
  
  /// Create backup before update
  static Future<String> createBackup({
    required String componentName,
    required String version,
    required Map<String, String> files,
  }) async {
    final backupPath = '$backupDir/$componentName/$version';
    final dir = Directory(backupPath);
    
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    
    // Save each file
    for (final entry in files.entries) {
      final file = File('$backupPath/${entry.key}');
      await file.create(recursive: true);
      await file.writeAsString(entry.value);
    }
    
    return backupPath;
  }
  
  /// Update component after merge
  static Future<void> updateComponent({
    required String componentName,
    required String newVersion,
    required String newRegistryVersion,
    required Map<String, String> files, // Updated file contents
  }) async {
    final manifest = await _loadManifest();
    
    final component = manifest['components'][componentName] as Map<String, dynamic>?;
    if (component == null) {
      throw Exception('Component $componentName not found in manifest');
    }
    
    // Update file checksums
    final updatedFiles = <String, dynamic>{};
    for (final entry in files.entries) {
      final newChecksum = sha256.convert(utf8.encode(entry.value)).toString();
      updatedFiles[entry.key] = {
        'checksum': newChecksum,
        'baseChecksum': newChecksum, // Reset base since this is now the source
        'size': entry.value.length,
        'userModified': false,
        'lastModified': DateTime.now().toIso8601String(),
      };
    }
    
    component['version'] = newVersion;
    component['registryVersion'] = newRegistryVersion;
    component['files'] = updatedFiles;
    component['status'] = 'clean';
    
    await _saveManifest(manifest);
  }
  
  /// Mark file as user-modified
  static Future<void> markAsModified(String componentName, String filePath) async {
    final manifest = await _loadManifest();
    
    final component = manifest['components'][componentName] as Map<String, dynamic>?;
    if (component == null) return;
    
    final files = component['files'] as Map<String, dynamic>?;
    if (files == null) return;
    
    if (files.containsKey(filePath)) {
      (files[filePath] as Map<String, dynamic>)['userModified'] = true;
    }
    
    await _saveManifest(manifest);
  }
  
  static Future<Map<String, dynamic>> _loadManifest() async {
    final file = File(manifestPath);
    if (!await file.exists()) {
      return {
        'version': '1.0.0',
        'components': {},
      };
    }
    
    final content = await file.readAsString();
    return jsonDecode(content) as Map<String, dynamic>;
  }
  
  static Future<void> _saveManifest(Map<String, dynamic> manifest) async {
    final file = File(manifestPath);
    await file.create(recursive: true);
    await file.writeAsString(jsonEncode(manifest));
  }
  
  static Future<List<dynamic>> _loadConflicts() async {
    final file = File(conflictsPath);
    if (!await file.exists()) {
      return [];
    }
    
    final content = await file.readAsString();
    return jsonDecode(content) as List<dynamic>;
  }
  
  static Future<void> _saveConflicts(List<dynamic> conflicts) async {
    final file = File(conflictsPath);
    await file.create(recursive: true);
    await file.writeAsString(jsonEncode(conflicts));
  }
}
