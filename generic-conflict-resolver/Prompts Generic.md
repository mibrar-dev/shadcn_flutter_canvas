# Complete Generic Prompts for Conflict Resolver Package

**IMPORTANT: These prompts build a GENERIC package usable by anyone, not just ShadcnCLI**

---

## PHASE 1: GENERIC MODELS & UTILITIES (Week 1)

### PROMPT 1: Generic File Version & Merge State Models

**Save as: `lib/src/models/file_version.dart` and `lib/src/models/merge_state.dart`**

```
Create two generic Dart model files for any conflict resolver:

FILE 1: FileVersion class
- Represents a version of any file/content
- Fields:
  * content: String? (null if deleted)
  * checksum: String? (SHA256)
  * modifiedAt: DateTime?
- Methods:
  * get exists -> bool
  * factory FileVersion.fromContent(String)
  * factory FileVersion.deleted()
- NO ShadcnCLI specific code
- Works with code files, configs, docs, anything

FILE 2: MergeState enum
Six states:
  - clean (no changes)
  - fastForward (only upstream changed)
  - keepLocal (only user changed)
  - autoMergeable (both changed non-overlapping)
  - conflict (both changed overlapping)
  - deleted (file deleted)

- Completely generic
- Works for any content type
- Include helper: getMergeStateEmoji(MergeState) -> String

IMPORTANT:
- NO file paths
- NO component names
- NO registry references
- NO ShadcnCLI concepts
- Completely generic and reusable
```

**Expected output:** 150-200 lines

---

### PROMPT 2: Generic Checksum Manager

**Save as: `lib/src/utils/checksum_manager.dart`**

```
Create ChecksumManager utility for generic use.

REQUIREMENTS:
1. static String generate(String content)
   - SHA256 checksum of any text content
   - Works for code, config, docs, anything

2. static bool equal(String checksum1, String checksum2)
   - Simple comparison

3. static bool detectModification(String base, String current)
   - Returns true if checksums differ
   - Works for any content type

4. static String detectUserModification(String baseChecksum, String currentChecksum)
   - Wrapper for readability

CONSTRAINTS:
- Synchronous (no async)
- Handle null/empty strings
- Works for ANY text content
- NO file system operations
- NO ShadcnCLI specific logic

IMPORTS:
- crypto: ^4.0.0 package
- dart:convert

Include: Complete implementation, docstrings, examples
```

**Expected output:** 50-80 lines

---

## PHASE 2: GENERIC CONFLICT DETECTION (Week 2)

### PROMPT 3: Generic Merge State Detection

**Save as: `lib/src/services/conflict_detector.dart`**

```
Create ConflictDetector for ANY text-based content.

CLASS: ConflictDetector

MAIN METHOD:
static MergeState analyze({
  required FileVersion base,
  required FileVersion current,
  required FileVersion upstream,
}) -> MergeState

ALGORITHM:
1. Handle deletions
2. Compare checksums
3. If all different, check for overlapping line changes
4. Return appropriate MergeState

IMPORTANT:
- Works for ANY text content (code, configs, docs)
- NO assumptions about file types
- NO component/registry/domain logic
- Completely generic

EDGE CASES:
- Empty files
- Null/deleted files
- Large files (>1MB)
- Binary files (treat as different if checksums differ)
- Whitespace-only changes

HELPER METHODS:
- static Set<int> _getChangedLines(...)
- static bool _hasOverlappingChanges(...)

Include: Complete implementation with examples
```

**Expected output:** 150-200 lines

---

### PROMPT 4: Generic Merge Result Model

**Save as: `lib/src/models/merge_result.dart`**

```
Create generic MergeResult class.

CLASS: MergeResult
Fields:
- content: String (merged result)
- hasConflicts: bool
- conflictMarkers: List<ConflictMarker>?
- mergeState: MergeState

CLASS: ConflictMarker
Fields:
- startLine: int
- baseLines: List<String>
- currentLines: List<String>
- upstreamLines: List<String>
- unified: String (formatted display)

Methods:
- String getConflictDisplay()
  Shows conflict in standard format

IMPORTANT:
- NO file paths (works with any content)
- NO domain-specific logic
- Standard conflict marker format (<<<<<<< CURRENT, etc.)
- Works for any content type

Include: Complete, well-documented classes
```

**Expected output:** 120-150 lines

---

## PHASE 3: GENERIC MERGING (Week 3)

### PROMPT 5: Generic Merge Engine

**Save as: `lib/src/services/merge_engine.dart`**

```
Create MergeEngine for generic three-way merge.

ENUM: MergeStrategy
- auto (try auto-merge)
- ours (keep current)
- theirs (accept upstream)
- manual (return conflict markers)
- threeWay (full three-way merge)

CLASS: MergeEngine

MAIN METHOD:
static MergeResult merge({
  required String base,
  required String current,
  required String upstream,
  MergeStrategy strategy = MergeStrategy.auto,
})

ALGORITHM (Line-based):
1. Detect changed line ranges
2. If no overlapping ranges -> auto-merge
3. If overlapping -> handle based on strategy
4. Apply both sets of changes when possible

STRATEGIES:
- auto: Try merge, on conflict return conflict markers
- ours: Return current
- theirs: Return upstream
- manual: Return content with conflict markers
- threeWay: Full three-way merge attempt

IMPORTANT:
- Simple line-based merge (not semantic)
- Works for ANY text content
- NO file system operations
- NO domain-specific logic
- Falls back gracefully on complex conflicts

Include: Complete implementation with strategy support
```

**Expected output:** 200-280 lines

---

### PROMPT 6: Generic Resolution Strategies

**Save as: `lib/src/services/resolution_strategies.dart`**

```
Create generic resolution strategies.

ABSTRACT CLASS: ResolutionStrategy

abstract Future<String> resolve({
  required String base,
  required String current,
  required String upstream,
});

IMPLEMENTATIONS (5 total):

1. KeepCurrentStrategy
   - Always return current
   - Safest for user's work

2. AcceptUpstreamStrategy
   - Always return upstream
   - Get all new changes

3. AutoMergeStrategy
   - Try to auto-merge
   - Fallback to current on conflict
   - Safest+smart

4. ManualResolveStrategy
   - Return content with conflict markers
   - User edits manually
   - Full control

5. SkipResolveStrategy
   - Return current unchanged
   - Resolve later

IMPORTANT:
- NO file system operations
- NO user interaction (strategies are pure)
- Works for any content type
- Simple and testable

Include: All 5 implementations, docstrings
```

**Expected output:** 150-200 lines

---

## PHASE 4: CORE API & TESTING (Week 4)

### PROMPT 7: Main Export & API

**Save as: `lib/conflict_resolver.dart`**

```
Create main library export file.

This file exports ONLY the public API.

EXPORTS (in this order):
- FileVersion
- MergeState
- MergeResult
- ConflictMarker
- ConflictDetector
- MergeEngine
- MergeStrategy
- ResolutionStrategy (abstract)
- All strategy implementations
- ChecksumManager

DO NOT EXPORT:
- Internal helper functions
- Private implementation details
- Testing utilities

INCLUDE:
- Clear documentation
- Usage examples in comments
- Links to examples folder

Example comment:
```
/// Generic conflict resolver for any text-based content.
///
/// Works with:
/// - Source code (Dart, Python, etc.)
/// - Configuration files (JSON, YAML, etc.)
/// - Markdown documents
/// - Any text format
///
/// Example usage:
/// ```dart
/// import 'package:conflict_resolver/conflict_resolver.dart';
///
/// final state = ConflictDetector.analyze(
///   base: FileVersion.fromContent(originalContent),
///   current: FileVersion.fromContent(userModified),
///   upstream: FileVersion.fromContent(newVersion),
/// );
/// ```
```

Keep it clean and simple.
```

**Expected output:** 50-80 lines

---

### PROMPT 8: Comprehensive Unit Tests - Detection

**Save as: `test/services/conflict_detector_test.dart`**

```
Create comprehensive unit tests for ConflictDetector.

USE: flutter_test package

TEST GROUPS (25+ test cases):

1. Clean State Tests:
   test('clean when nothing changed')
   test('clean when all three identical')
   test('clean when deleted by both')

2. Fast Forward Tests:
   test('fastForward when only upstream changed')
   test('fastForward with multiple line changes')

3. Keep Local Tests:
   test('keepLocal when only user changed')
   test('keepLocal with significant changes')

4. Auto Mergeable Tests:
   test('autoMergeable with non-overlapping changes')
   test('user modified line 5, upstream modified line 10')
   test('both added different content')

5. Conflict Tests:
   test('conflict when both modified same line')
   test('conflict with overlapping ranges')

6. Edge Cases:
   test('empty files')
   test('file deleted by upstream, user modified')
   test('file deleted by user, upstream modified')
   test('large files (>1MB)')
   test('binary files treated as different')
   test('unicode content')
   test('whitespace-only changes')
   test('different line endings')

Each test should:
- Have clear description
- Include setup/arrange/act/assert
- Be independent
- Test one specific case

Include: All test cases with good assertions
```

**Expected output:** 350-450 lines

---

### PROMPT 9: Unit Tests - Merge Engine

**Save as: `test/services/merge_engine_test.dart`**

```
Create tests for MergeEngine and resolution strategies.

TEST GROUPS (20+ test cases):

1. Auto Strategy Tests:
   test('auto merges non-overlapping changes')
   test('auto returns conflict markers on overlap')
   test('auto handles empty files')

2. Keep Current Tests:
   test('ours always returns current')
   test('ours ignores upstream changes')

3. Accept Upstream Tests:
   test('theirs always returns upstream')
   test('theirs ignores user changes')

4. Manual Strategy Tests:
   test('manual returns content with markers')
   test('markers have correct format')
   test('markers are standard <<<<<<< format')

5. Skip Strategy Tests:
   test('skip returns current unchanged')

6. Integration Tests:
   test('merge simple non-overlapping case')
   test('merge complex multi-line scenario')
   test('merge detects conflicts correctly')
   test('merge handles all edge cases')

Include: 20+ test cases with good coverage
```

**Expected output:** 250-350 lines

---

### PROMPT 10: Integration Tests

**Save as: `test/integration/conflict_resolver_integration_test.dart`**

```
Create integration tests for complete resolution workflows.

TEST SCENARIOS (5 real-world cases):

1. Scenario: Code Merge (Dart files)
   Setup:
   - Original function
   - User adds logging to function
   - Upstream adds error handling to same function
   Test:
   - Detect conflict
   - Try auto-merge
   - Show conflict markers if can't merge

2. Scenario: Config Merge (JSON)
   Setup:
   - Original config
   - User changes timeout value
   - Upstream adds new features
   Test:
   - Merge succeeds (non-overlapping)
   - Both changes present in result

3. Scenario: Document Merge (Markdown)
   Setup:
   - Original doc section
   - User edits one paragraph
   - Upstream adds new section
   Test:
   - Auto-merge succeeds
   - Both changes preserved

4. Scenario: Complete Conflict
   Setup:
   - Same content modified by both sides
   - Incompatible changes
   Test:
   - Detect conflict correctly
   - All strategies work (ours/theirs/manual)
   - Markers formatted correctly

5. Scenario: File Deletion
   Setup:
   - File deleted by one side
   - Modified by other side
   Test:
   - Detect appropriately
   - Handle gracefully

Include: 5 full scenario tests with setup/verification
```

**Expected output:** 400-500 lines

---

## PHASE 5: DOCUMENTATION & EXAMPLES (Week 5)

### PROMPT 11: Usage Examples

**Save as: `example/basic_usage.dart`**

```
Create basic usage examples for conflict_resolver.

EXAMPLES (with comments):

1. Basic Conflict Detection
   - Load three versions
   - Detect merge state
   - Show result

2. Simple Merge
   - Merge non-conflicting changes
   - Show merged result

3. Conflict Handling
   - Detect conflict
   - Show conflict markers
   - Apply strategy

4. Working with FileVersion
   - Create from content
   - Create deleted version
   - Compare checksums

5. All Strategies
   - Show each strategy in action
   - Compare results
   - When to use each

Each example should:
- Be complete and runnable
- Have clear comments
- Show expected output
- Be practical

Include: 5 complete, working examples
```

**Expected output:** 250-350 lines

---

### PROMPT 12: Generic Integration Examples

**Save as: `example/generic_integration_examples.dart`**

```
Create examples showing generic usage across domains.

EXAMPLES (for different use cases):

1. Source Code Merging
   - Merge Dart files
   - Merge Python files
   - Any code language
   - Show conflict detection and resolution

2. Configuration File Merging
   - Merge JSON configs
   - Merge YAML configs
   - Show auto-merge working
   - Show conflict markers

3. Document Collaboration
   - Two users edit Markdown
   - Auto-merge different sections
   - Show conflict if overlapping

4. Version Control Scenario
   - Three-way merge for branches
   - Common ancestor as base
   - Current branch vs target branch
   - Merge with strategy

5. Build System Integration
   - Merge build files
   - Keep local modifications
   - Get upstream improvements

Each example:
- Shows real-world scenario
- Uses same conflict_resolver API
- Different domains, same library
- Practical code

Include: 5 different domain examples
```

**Expected output:** 300-400 lines

---

### PROMPT 13: README

**Save as: `README.md`**

```
Create comprehensive README for conflict_resolver package.

SECTIONS:

1. Title & Description
   - What it is
   - Key features
   - Why it matters

2. Features
   - Three-way merge
   - Generic (works with any content)
   - Multiple resolution strategies
   - Well-tested
   - Zero external dependencies (just crypto)

3. Use Cases
   - Component management
   - Config merging
   - Document collaboration
   - Source code merging
   - Version control
   - Configuration management
   - Any three-way merge scenario

4. Installation
   ```yaml
   dependencies:
     conflict_resolver: ^1.0.0
   ```

5. Quick Start
   - Import
   - Basic example
   - Detect conflict
   - Resolve conflict

6. API Documentation
   - ConflictDetector
   - MergeEngine
   - Resolution strategies
   - FileVersion, MergeState, MergeResult

7. Examples
   - Basic usage
   - Advanced usage
   - Different domains
   - Link to examples/

8. Features Explained
   - Why line-based merge
   - How detection works
   - Resolution strategies explained
   - When to use each

9. Testing
   - How to run tests
   - Coverage info
   - How to add tests

10. Contributing
    - How to contribute
    - Code style
    - PR process

Include: Complete, professional README
```

**Expected output:** Comprehensive documentation

---

### PROMPT 14: CHANGELOG

**Save as: `CHANGELOG.md`**

```
Create CHANGELOG following Keep a Changelog format.

SECTIONS:

[1.0.0] - 2026-01-30

Added:
- Initial release
- ConflictDetector for three-way merge analysis
- MergeEngine with multiple strategies
- 5 resolution strategies (auto, ours, theirs, manual, skip)
- FileVersion and MergeState models
- ChecksumManager for content comparison
- Comprehensive test suite (40+ tests)
- Complete documentation and examples
- Support for any text-based content

Changed:
- N/A (initial release)

Fixed:
- N/A (initial release)

Removed:
- N/A (initial release)

Keep changelog clear and professional.
```

**Expected output:** Professional changelog

---

### PROMPT 15: Library Documentation

**Save as: `lib/src/conflict_resolver_library.dart`**

```
Create internal library documentation file.

This file documents how the library works internally
(for contributors and maintainers).

SECTIONS:

1. Architecture Overview
   - How components interact
   - Data flow
   - Design decisions

2. Key Concepts
   - FileVersion
   - MergeState
   - Three-way merge
   - Line-based merge

3. Algorithm Explanation
   - How conflict detection works
   - How line-based merge works
   - Edge cases handled

4. Design Decisions
   - Why line-based (not semantic)
   - Why these 5 strategies
   - Why ChecksumManager
   - Why FileVersion

5. Extending the Library
   - How to add new strategies
   - How to add new detectors
   - Guidelines for contributors

6. Testing Strategy
   - Unit tests
   - Integration tests
   - Edge cases

Include: Clear internal documentation
```

**Expected output:** 200-300 lines

---

## COMPLETE pubspec.yaml

**Save as: `pubspec.yaml`**

```
Create complete pubspec.yaml for generic package.

```yaml
name: conflict_resolver
description: >
  A generic, production-ready Dart package for three-way merge conflict 
  detection, analysis, and resolution. Works with any text-based content: 
  source code, configurations, documents, and more. Suitable for component 
  management, version control, configuration merging, document collaboration, 
  and any scenario requiring intelligent conflict resolution.

version: 1.0.0
homepage: https://github.com/yourusername/conflict_resolver
repository: https://github.com/yourusername/conflict_resolver
issue_tracker: https://github.com/yourusername/conflict_resolver/issues
documentation: https://pub.dev/packages/conflict_resolver

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  crypto: ^4.0.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  test: ^1.24.0
  lints: ^2.0.0
  build_runner: ^2.0.0

topics:
  - merge
  - conflict-resolution
  - three-way-merge
  - version-control
  - diff
  - conflict-detection
  - generic
  - reusable
```

Format with proper indentation and structure.
```

**Expected output:** Complete pubspec.yaml

---

## FINAL STRUCTURE

**Expected directory structure after all prompts:**

```
conflict_resolver/
├── lib/
│   ├── src/
│   │   ├── models/
│   │   │   ├── file_version.dart          (Prompt 1)
│   │   │   ├── merge_state.dart           (Prompt 1)
│   │   │   └── merge_result.dart          (Prompt 4)
│   │   ├── services/
│   │   │   ├── conflict_detector.dart     (Prompt 3)
│   │   │   ├── merge_engine.dart          (Prompt 5)
│   │   │   └── resolution_strategies.dart (Prompt 6)
│   │   └── utils/
│   │       └── checksum_manager.dart      (Prompt 2)
│   └── conflict_resolver.dart             (Prompt 7 - main export)
├── test/
│   ├── services/
│   │   ├── conflict_detector_test.dart    (Prompt 8)
│   │   └── merge_engine_test.dart         (Prompt 9)
│   └── integration/
│       └── conflict_resolver_integration_test.dart (Prompt 10)
├── example/
│   ├── basic_usage.dart                   (Prompt 11)
│   └── generic_integration_examples.dart  (Prompt 12)
├── lib/src/
│   └── conflict_resolver_library.dart     (Prompt 15 - internal docs)
├── README.md                              (Prompt 13)
├── CHANGELOG.md                           (Prompt 14)
└── pubspec.yaml                           (Complete pubspec)
```

---

## KEY DIFFERENCES FROM ORIGINAL PROMPTS

✅ **What's Different:**
- NO ShadcnCLI-specific code
- NO component/registry logic
- NO file system operations
- NO manifest management
- NO CLI commands
- Completely GENERIC and REUSABLE

✅ **What's the Same:**
- Conflict detection algorithm
- Three-way merge algorithm
- Resolution strategies
- Testing approach
- Quality standards
- Production-ready code

✅ **Benefits:**
- Works for ANY text content
- Publishable to pub.dev
- Reusable by anyone
- Clean architecture
- No domain assumptions

---

## USAGE IN YOUR SHADCN CLI

Once you have `conflict_resolver` package, use it:

```dart
import 'package:conflict_resolver/conflict_resolver.dart';

class UpdateCommand extends Command<int> {
  @override
  Future<int> run() async {
    final state = ConflictDetector.analyze(
      base: FileVersion.fromContent(baseComponent),
      current: FileVersion.fromContent(userComponent),
      upstream: FileVersion.fromContent(registryComponent),
    );
    
    // Your CLI handles user interaction
    final strategy = await getUserStrategy();
    
    final result = MergeEngine.merge(
      base: baseComponent,
      current: userComponent,
      upstream: registryComponent,
      strategy: strategy,
    );
    
    // Apply result...
  }
}
```

Perfect separation of concerns!

---

## ESTIMATED STATS

- **Total Prompts:** 15
- **Total Files:** 12
- **Lines of Code:** ~4,500
- **Unit Tests:** 45+
- **Integration Tests:** 5 scenarios
- **Documentation:** Complete
- **API Coverage:** 100%
- **Cost:** $5-8 (Sonnet 4.5)
- **Time:** 13-15 hours AI assistance
- **Quality:** Production-ready
- **Publishable:** YES (pub.dev)

This is a COMPLETE, generic, reusable conflict resolver package!
