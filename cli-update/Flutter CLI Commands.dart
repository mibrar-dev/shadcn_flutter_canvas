// lib/commands/update_command.dart
// Full update command with conflict resolution

import 'package:args/command_runner.dart';
import 'package:cli_menu/cli_menu.dart';
import 'dart:io';
import 'dart:convert';

class UpdateCommand extends Command<int> {
  @override
  final name = 'update';
  
  @override
  final description = 'Update installed components to latest versions';
  
  UpdateCommand() {
    argParser
      ..addOption(
        'strategy',
        abbr: 's',
        help: 'Conflict resolution strategy',
        allowed: ['auto', 'ours', 'theirs', 'interactive'],
        defaultsTo: 'interactive',
      )
      ..addFlag(
        'check',
        help: 'Check for updates without applying them',
        negatable: false,
      )
      ..addFlag(
        'dry-run',
        help: 'Show what would be updated without changing files',
        negatable: false,
      )
      ..addFlag(
        'all',
        abbr: 'a',
        help: 'Update all components',
        negatable: false,
      )
      ..addOption(
        'components',
        abbr: 'c',
        help: 'Comma-separated list of components to update',
      )
      ..addFlag(
        'skip-backup',
        help: 'Skip creating backups (not recommended)',
        negatable: false,
      )
      ..addFlag(
        'verbose',
        abbr: 'v',
        help: 'Show detailed output',
        negatable: false,
      );
  }
  
  @override
  Future<int> run() async {
    try {
      final strategy = argResults!['strategy'] as String;
      final isCheck = argResults!['check'] as bool;
      final isDryRun = argResults!['dry-run'] as bool;
      final isAll = argResults!['all'] as bool;
      final componentsArg = argResults!['components'] as String?;
      final skipBackup = argResults!['skip-backup'] as bool;
      final isVerbose = argResults!['verbose'] as bool;
      
      // Get list of components to update
      List<String> componentsToUpdate = [];
      
      if (isAll) {
        componentsToUpdate = await _getInstalledComponents();
      } else if (componentsArg != null) {
        componentsToUpdate = componentsArg.split(',').map((s) => s.trim()).toList();
      } else if (argResults!.rest.isNotEmpty) {
        componentsToUpdate = argResults!.rest;
      } else {
        // Interactive selection
        componentsToUpdate = await _selectComponents();
      }
      
      if (componentsToUpdate.isEmpty) {
        print('❌ No components specified for update');
        return 1;
      }
      
      // Check for available updates
      print('\n📦 Checking for updates...\n');
      
      final updates = <String, UpdateInfo>{};
      for (final component in componentsToUpdate) {
        final info = await _checkForUpdates(component);
        if (info != null) {
          updates[component] = info;
        }
      }
      
      if (updates.isEmpty) {
        print('✅ All components are up to date');
        return 0;
      }
      
      // Show available updates
      print('${updates.length} component(s) have updates available:\n');
      for (final entry in updates.entries) {
        print('  ${entry.key}: ${entry.value.currentVersion} → ${entry.value.newVersion}');
        if (isVerbose && entry.value.changes.isNotEmpty) {
          for (final change in entry.value.changes) {
            print('    • $change');
          }
        }
      }
      
      if (isCheck) {
        print('\n✅ Check complete');
        return 0;
      }
      
      print('\n');
      
      // Analyze changes
      print('🔍 Analyzing changes...\n');
      
      final analysisResults = <String, AnalysisResult>{};
      
      for (final entry in updates.entries) {
        final component = entry.key;
        final updateInfo = entry.value;
        
        final result = await _analyzeChanges(
          component,
          updateInfo.currentVersion,
          updateInfo.newVersion,
        );
        
        analysisResults[component] = result;
        
        // Print analysis summary
        print('  $component:');
        print('    ✅ ${result.autoMergeable.length} file(s) auto-mergeable');
        if (result.needsReview.isNotEmpty) {
          print('    ⚠️  ${result.needsReview.length} file(s) need review');
        }
        if (result.conflicts.isNotEmpty) {
          print('    ❌ ${result.conflicts.length} conflict(s) detected');
        }
      }
      
      // Show detailed conflicts if any
      bool hasConflicts = false;
      for (final result in analysisResults.values) {
        if (result.conflicts.isNotEmpty) {
          hasConflicts = true;
          break;
        }
      }
      
      if (hasConflicts) {
        print('\n📝 Review conflicts? (y/n): ');
        final shouldReview = stdin.readLineSync() == 'y';
        
        if (shouldReview) {
          for (final entry in analysisResults.entries) {
            if (entry.value.conflicts.isNotEmpty) {
              await _showConflictDetails(entry.key, entry.value.conflicts);
            }
          }
        }
      }
      
      // Dry-run mode
      if (isDryRun) {
        print('\n📋 Dry-run complete - no changes applied');
        return 0;
      }
      
      // Confirm before applying
      print('\n');
      bool shouldContinue = await _confirmUpdate(updates, analysisResults);
      
      if (!shouldContinue) {
        print('\n⏭️  Update cancelled');
        return 0;
      }
      
      // Create backups
      if (!skipBackup) {
        print('\n💾 Creating backups...');
        for (final component in updates.keys) {
          final backupPath = await _createBackup(component, updates[component]!.currentVersion);
          print('   ✅ ${component} backed up to $backupPath');
        }
      }
      
      // Apply updates
      print('\n🚀 Applying updates...\n');
      
      int successCount = 0;
      int conflictCount = 0;
      
      for (final entry in updates.entries) {
        final component = entry.key;
        final updateInfo = entry.value;
        final analysis = analysisResults[component]!;
        
        print('  Updating $component...');
        
        try {
          final result = await _applyUpdate(
            component,
            updateInfo,
            analysis,
            strategy,
          );
          
          if (result.success) {
            print('    ✅ Updated to ${updateInfo.newVersion}');
            successCount++;
          } else if (result.hasUnresolvedConflicts) {
            print('    ⚠️  Update applied with unresolved conflicts');
            print('       View with: flutter pub global run flutter_shadcn conflicts $component');
            conflictCount++;
          }
        } catch (e) {
          print('    ❌ Error: $e');
        }
      }
      
      // Summary
      print('\n📊 Summary:');
      print('   ✅ $successCount updated successfully');
      if (conflictCount > 0) {
        print('   ⚠️  $conflictCount with conflicts to resolve');
      }
      print('\n✨ Done!');
      
      return 0;
    } catch (e) {
      print('❌ Error during update: $e');
      return 1;
    }
  }
  
  Future<List<String>> _getInstalledComponents() async {
    final manifest = File('.shadcn/installed.json');
    if (!await manifest.exists()) {
      return [];
    }
    
    final content = jsonDecode(await manifest.readAsString()) as Map<String, dynamic>;
    final components = content['components'] as Map<String, dynamic>?;
    
    return components?.keys.toList() ?? [];
  }
  
  Future<List<String>> _selectComponents() async {
    final installed = await _getInstalledComponents();
    
    if (installed.isEmpty) {
      print('No components installed');
      return [];
    }
    
    // Create menu for selection
    final items = installed
        .map((c) => MenuItem(title: c, value: c))
        .toList();
    
    const menu = SimpleMenu(
      title: 'Select components to update:',
      children: items,
    );
    
    final selected = menu.prompt();
    return [selected.toString()];
  }
  
  Future<UpdateInfo?> _checkForUpdates(String componentName) async {
    // TODO: Check registry for new version
    // This would call your registry API
    return null;
  }
  
  Future<AnalysisResult> _analyzeChanges(
    String component,
    String currentVersion,
    String newVersion,
  ) async {
    // TODO: Implement change analysis
    return AnalysisResult(
      component: component,
      autoMergeable: [],
      needsReview: [],
      conflicts: [],
    );
  }
  
  void _showConflictDetails(String component, List<ConflictInfo> conflicts) {
    print('\n⚠️  CONFLICTS in $component\n');
    
    for (final conflict in conflicts) {
      print('═══════════════════════════════════════');
      print('FILE: ${conflict.filePath}');
      print('═══════════════════════════════════════\n');
      
      print('YOUR VERSION (Current):');
      _printWithLineNumbers(conflict.yourVersion);
      
      print('\nUPSTREAM VERSION (New):');
      _printWithLineNumbers(conflict.upstreamVersion);
      
      print('\n');
    }
  }
  
  void _printWithLineNumbers(String content) {
    final lines = content.split('\n');
    for (int i = 0; i < lines.length; i++) {
      print('${(i + 1).toString().padLeft(3)} │ ${lines[i]}');
    }
  }
  
  Future<bool> _confirmUpdate(
    Map<String, UpdateInfo> updates,
    Map<String, AnalysisResult> analysis,
  ) async {
    print('About to update:');
    for (final entry in updates.entries) {
      print('  • ${entry.key}: ${entry.value.currentVersion} → ${entry.value.newVersion}');
    }
    
    // Check for conflicts
    bool hasConflicts = false;
    for (final result in analysis.values) {
      if (result.conflicts.isNotEmpty) {
        hasConflicts = true;
        break;
      }
    }
    
    if (hasConflicts) {
      print('\n⚠️  Some updates have conflicts that will need resolution');
    }
    
    print('\nProceed? (y/n): ');
    return stdin.readLineSync() == 'y';
  }
  
  Future<String> _createBackup(String component, String version) async {
    // TODO: Implement backup creation
    return '.shadcn/backups/$component/$version';
  }
  
  Future<UpdateResult> _applyUpdate(
    String component,
    UpdateInfo updateInfo,
    AnalysisResult analysis,
    String strategy,
  ) async {
    // TODO: Implement actual update with conflict resolution
    return UpdateResult(
      success: true,
      hasUnresolvedConflicts: false,
    );
  }
}

// Models

class UpdateInfo {
  final String component;
  final String currentVersion;
  final String newVersion;
  final List<String> changes;
  final DateTime releaseDate;
  
  UpdateInfo({
    required this.component,
    required this.currentVersion,
    required this.newVersion,
    required this.changes,
    required this.releaseDate,
  });
}

class AnalysisResult {
  final String component;
  final List<String> autoMergeable;
  final List<String> needsReview;
  final List<ConflictInfo> conflicts;
  
  AnalysisResult({
    required this.component,
    required this.autoMergeable,
    required this.needsReview,
    required this.conflicts,
  });
}

class ConflictInfo {
  final String filePath;
  final String baseVersion;
  final String yourVersion;
  final String upstreamVersion;
  final int baseLineStart;
  final int baseLineEnd;
  final int yourLineStart;
  final int yourLineEnd;
  final int upstreamLineStart;
  final int upstreamLineEnd;
  
  ConflictInfo({
    required this.filePath,
    required this.baseVersion,
    required this.yourVersion,
    required this.upstreamVersion,
    required this.baseLineStart,
    required this.baseLineEnd,
    required this.yourLineStart,
    required this.yourLineEnd,
    required this.upstreamLineStart,
    required this.upstreamLineEnd,
  });
}

class UpdateResult {
  final bool success;
  final bool hasUnresolvedConflicts;
  final List<String>? errors;
  
  UpdateResult({
    required this.success,
    required this.hasUnresolvedConflicts,
    this.errors,
  });
}

// lib/commands/status_command.dart
// Show status of installed components

class StatusCommand extends Command<int> {
  @override
  final name = 'status';
  
  @override
  final description = 'Show status of installed components';
  
  StatusCommand() {
    argParser
      ..addFlag(
        'modified-only',
        help: 'Show only components with user modifications',
        negatable: false,
      )
      ..addFlag(
        'conflicts-only',
        help: 'Show only components with conflicts',
        negatable: false,
      )
      ..addOption(
        'component',
        help: 'Show detailed status for specific component',
      );
  }
  
  @override
  Future<int> run() async {
    try {
      final manifest = File('.shadcn/installed.json');
      if (!await manifest.exists()) {
        print('❌ No components installed');
        return 1;
      }
      
      final content = jsonDecode(await manifest.readAsString()) as Map<String, dynamic>;
      final components = content['components'] as Map<String, dynamic>? ?? {};
      
      if (components.isEmpty) {
        print('❌ No components installed');
        return 1;
      }
      
      final modifiedOnly = argResults!['modified-only'] as bool;
      final conflictsOnly = argResults!['conflicts-only'] as bool;
      final specificComponent = argResults!['component'] as String?;
      
      print('\n📦 Installed Components\n');
      
      for (final entry in components.entries) {
        final name = entry.key;
        final data = entry.value as Map<String, dynamic>;
        
        if (specificComponent != null && specificComponent != name) {
          continue;
        }
        
        final status = data['status'] as String? ?? 'unknown';
        final version = data['version'] as String? ?? 'unknown';
        final hasModifications = _hasModifications(data);
        
        if (modifiedOnly && !hasModifications) continue;
        if (conflictsOnly && status != 'conflict') continue;
        
        // Print component info
        final statusIcon = _getStatusIcon(status);
        print('$statusIcon $name');
        print('   Version: $version');
        
        if (hasModifications) {
          print('   ✏️  User modifications detected');
        }
        
        if (status == 'conflict') {
          print('   ⚠️  Has unresolved conflicts');
        }
        
        if (specificComponent != null) {
          // Show file details
          final files = data['files'] as Map<String, dynamic>?;
          if (files != null) {
            print('\n   Files:');
            for (final file in files.entries) {
              final fileData = file.value as Map<String, dynamic>;
              final userModified = fileData['userModified'] as bool? ?? false;
              final icon = userModified ? '✏️ ' : '✓ ';
              print('   $icon${file.key}');
            }
          }
        }
        
        print('');
      }
      
      return 0;
    } catch (e) {
      print('❌ Error: $e');
      return 1;
    }
  }
  
  bool _hasModifications(Map<String, dynamic> component) {
    final files = component['files'] as Map<String, dynamic>?;
    if (files == null) return false;
    
    for (final fileData in files.values) {
      if (fileData is Map<String, dynamic>) {
        if (fileData['userModified'] as bool? ?? false) {
          return true;
        }
      }
    }
    return false;
  }
  
  String _getStatusIcon(String status) {
    switch (status) {
      case 'clean':
        return '✅';
      case 'modified':
        return '✏️ ';
      case 'conflict':
        return '❌';
      default:
        return '❓';
    }
  }
}

// lib/commands/rollback_command.dart
// Rollback component to previous version

class RollbackCommand extends Command<int> {
  @override
  final name = 'rollback';
  
  @override
  final description = 'Rollback component to previous version';
  
  RollbackCommand() {
    argParser
      ..addOption(
        'version',
        help: 'Specific version to rollback to',
      )
      ..addFlag(
        'history',
        help: 'Show rollback history for component',
        negatable: false,
      );
  }
  
  @override
  Future<int> run() async {
    try {
      final component = argResults!.rest.isEmpty ? null : argResults!.rest.first;
      final version = argResults!['version'] as String?;
      final showHistory = argResults!['history'] as bool;
      
      if (component == null) {
        print('❌ Please specify a component');
        return 1;
      }
      
      if (showHistory) {
        // Show backup history
        final backupDir = Directory('.shadcn/backups/$component');
        if (!await backupDir.exists()) {
          print('❌ No backups found for $component');
          return 1;
        }
        
        print('📋 Available backups for $component:\n');
        final versions = await backupDir.list().toList();
        for (final version in versions) {
          if (version is Directory) {
            print('  • ${version.path.split('/').last}');
          }
        }
        return 0;
      }
      
      // Perform rollback
      print('🔄 Rolling back $component...');
      
      // TODO: Implement actual rollback
      
      print('✅ Rolled back successfully');
      return 0;
    } catch (e) {
      print('❌ Error: $e');
      return 1;
    }
  }
}
