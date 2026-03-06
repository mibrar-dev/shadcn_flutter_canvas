# Pragmatic Conflict Resolution (No Visual Merge UI Needed)

## The Problem with Visual Merge UIs

Visual merge UIs look nice but are:
- ❌ Complex to build
- ❌ Easy to get wrong
- ❌ Hard to test
- ❌ Bug-prone
- ❌ Reinventing the wheel (VS Code already has this!)

**Solution: Use VS Code's built-in merge editor (it's excellent)**

---

## Our Approach: Text-Based Strategies + Editor Integration

Instead of building a visual merge UI, we:
1. Detect conflicts
2. Show simple text descriptions
3. Offer 4 choices
4. If user wants manual merge → open in VS Code
5. Done!

---

## The 4 Conflict Resolution Strategies

### Strategy 1: **ours** (Keep Your Version)

```
⚠️ CONFLICT: button/lib/button_theme.dart
   Both modified the theme structure

You modified:
  • Changed Color.primary to custom value
  • Added custom animation timing
  
Upstream changed:
  • Refactored theme to use ColorScheme
  • Added dark mode support
  • Renamed properties

Choose resolution:
  [1] Keep YOUR changes (safest for your work)
  [2] Accept UPSTREAM (get new features but lose your customization)
  [3] Open in VS Code (resolve manually)
  [4] Skip for now (resolve later with: flutter_shadcn conflicts)

> 1

✅ Kept your version
   You can see what you missed at: .shadcn/conflicts/button_theme.conflict
   To update later: flutter pub global run flutter_shadcn conflicts resolve
```

**Result:**
- User keeps their code
- Work is preserved
- Conflict recorded for later
- User can manually merge later if needed

**When to recommend:**
- User has custom modifications they want to keep
- Safest option (never loses user work)
- Default choice

---

### Strategy 2: **theirs** (Accept Upstream)

```
⚠️ CONFLICT: button/lib/button_theme.dart
   Both modified the theme structure

You modified:
  • Changed Color.primary to custom value
  • Added custom animation timing
  
Upstream changed:
  • Refactored theme to use ColorScheme
  • Added dark mode support
  • Renamed properties

Choose resolution:
  [1] Keep YOUR changes (safest for your work)
  [2] Accept UPSTREAM (get new features but lose your customization)  ← RECOMMENDED
  [3] Open in VS Code (resolve manually)
  [4] Skip for now (resolve later)

> 2

✅ Accepted upstream version
   Your customizations were saved to: .shadcn/backups/button/1.0.0/lib/button_theme.dart
   You can manually merge later if needed
   To see pending conflicts: flutter pub global run flutter_shadcn conflicts
```

**Result:**
- Gets new features from registry
- Loses previous customizations (but backed up!)
- Can manually restore changes later

**When to recommend:**
- Upstream made major improvements
- User's changes were small/experimental
- User wants new features

---

### Strategy 3: **manual** (Open in VS Code)

```
⚠️ CONFLICT: button/lib/button_theme.dart
   Both modified the theme structure

You modified:
  • Changed Color.primary to custom value
  • Added custom animation timing
  
Upstream changed:
  • Refactored theme to use ColorScheme
  • Added dark mode support
  • Renamed properties

Choose resolution:
  [1] Keep YOUR changes (safest for your work)
  [2] Accept UPSTREAM (get new features)
  [3] Open in VS Code (resolve manually)  ← YOU ARE HERE
  [4] Skip for now

> 3

📝 Creating conflict file...
🔗 Opening button/lib/button_theme.dart in VS Code...

FILE LOCATION: button/lib/button_theme.dart
It will have standard conflict markers:

<<<<<<< CURRENT
// Your version here
=======
// Upstream version here
>>>>>>> UPSTREAM
```

**VS Code will show:**
- Left side: Your version
- Right side: Upstream version
- Interactive merge editor to choose which parts to keep
- Ability to edit freely

**User then:**
1. Opens the file in VS Code (already opening!)
2. Uses VS Code's built-in merge editor
3. Chooses which parts to keep
4. Removes conflict markers
5. Saves
6. Runs: `flutter pub global run flutter_shadcn status` to confirm

**Result:**
- User has full control
- Professional merge editor (VS Code)
- Can keep parts of both versions
- No learning curve (already knows VS Code)

**When to recommend:**
- User needs to keep parts of BOTH versions
- Complex changes that need careful merging
- User is comfortable with merge conflicts

---

### Strategy 4: **skip** (Resolve Later)

```
⚠️ CONFLICT: button/lib/button_theme.dart
   Both modified the theme structure

You modified:
  • Changed Color.primary to custom value
  
Upstream changed:
  • Refactored theme to use ColorScheme

Choose resolution:
  [1] Keep YOUR changes
  [2] Accept UPSTREAM
  [3] Open in VS Code (resolve manually)
  [4] Skip for now (resolve later)  ← YOU ARE HERE

> 4

⏳ Skipped for now
   Conflict saved. View with:
   flutter pub global run flutter_shadcn conflicts list

Come back to it later:
   flutter pub global run flutter_shadcn conflicts resolve
```

**Result:**
- Current version unchanged
- Conflict recorded with full details
- Can be resolved anytime later
- Update partially applies (other files updated, this one skipped)

**When to recommend:**
- User needs time to think
- Conflict is complex
- User is rushing and wants to fix later
- Multiple conflicts and user wants to handle one at a time

---

## Example Workflow: Update with Conflict

```
$ flutter pub global run flutter_shadcn update button

📦 Checking for updates...
   button: 1.0.0 → 1.2.0 available

🔍 Analyzing changes...
   
   ✅ lib/button.dart
      You: Added custom animation
      Upstream: Added dark mode
      Status: Auto-mergeable ✨
   
   ⚠️ lib/button_theme.dart
      You: Modified colors
      Upstream: Refactored theme structure
      Status: CONFLICT
   
   ✅ lib/button_variants.dart
      You: No changes
      Upstream: Updated variants
      Status: Fast-forward ⬆️

Summary:
  2 can be auto-merged ✨
  1 conflict needs your decision ⚠️

Proceed? (y/n): y

Processing auto-mergeable files...
  ✅ lib/button.dart (merged)
  ✅ lib/button_variants.dart (applied)

Now handling conflict...

═══════════════════════════════════════════════════════════════
⚠️ CONFLICT: lib/button_theme.dart

YOUR VERSION:
  • Color.primary = Color(0xFF6200EA)
  • Custom animation timing added

UPSTREAM VERSION:
  • ColorScheme.fromSeed() refactor
  • Dark mode support added
  • Theme structure changed

═══════════════════════════════════════════════════════════════

How to resolve?

  [1] Keep YOUR version (safe, loses new features)
  [2] Accept UPSTREAM (get new features, lose customization)
  [3] Merge in VS Code (keep parts of both)
  [4] Skip for now (decide later)

Choose [1-4]: 3

📝 Preparing conflict file...
🔗 Opening in VS Code...
```

**User sees in VS Code:**
```dart
<<<<<<< CURRENT
final buttonTheme = ThemeData(
  primary: Color(0xFF6200EA),
  secondary: Color(0xFF03DAC6),
  // Custom animation timing
  transitionDuration: Duration(milliseconds: 350),
);
=======
final buttonTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: Color(0xFF6200EA),
  ),
  useMaterial3: true,
  // Dark mode support
);
>>>>>>> UPSTREAM
```

**VS Code shows merge editor:**
- Left: Current (user's version)
- Right: Upstream (registry version)
- User can click "Accept Current", "Accept Incoming", or "Accept Both"
- User can manually edit to combine them

**User finishes merge and saves.**

```
✅ Resolved button_theme.dart

💾 Creating backup...
   ✓ Backed up to .shadcn/backups/button/1.0.0

🚀 Applying updates...
   ✅ Merged 2 files (auto)
   ✅ Resolved 1 conflict (manual)
   ✅ Updated button to 1.2.0

✨ Update complete!
```

---

## What We DON'T Build

### ❌ Custom Visual Merge UI
We don't build:
- Side-by-side diff viewer
- Line-by-line selector
- Custom conflict marker editor
- Visual merge preview

### Why?
- VS Code already has excellent merge editor
- Would be 2000+ lines to replicate poorly
- VS Code's is tested, reliable, professional
- Users already know how to use it

### What We Build Instead
- Simple text descriptions of changes
- Menu to choose strategy
- Integration to open file in VS Code
- Clear instructions

---

## Fallback Strategies

### If User Doesn't Have VS Code

**Option 1: Use Default Editor**
```bash
Opening button/lib/button_theme.dart in default editor...
Edit file, remove conflict markers, save.
```

**Option 2: Manual Text Edit**
```
File with conflict markers saved at:
  /Users/you/project/button/lib/button_theme.dart

Edit manually:
1. Open in your text editor
2. Look for <<<<<<< and >>>>>>> markers
3. Delete the markers and choose version
4. Save
5. Run: flutter pub global run flutter_shadcn status
```

**Option 3: Simple Script**
```bash
#!/bin/bash
# If VS Code not installed, open in nano
nano button/lib/button_theme.dart
```

---

## Pending Conflicts Management

### View All Pending Conflicts
```bash
$ flutter pub global run flutter_shadcn conflicts list

⏳ Pending Conflicts (2)

#1 - button/lib/button_theme.dart
   Conflict: v1.0.0 → v1.2.0
   Detected: 2 days ago
   
#2 - card/lib/card_style.dart
   Conflict: v0.9.0 → v1.0.0
   Detected: 5 hours ago
```

### Resolve Specific Conflict
```bash
$ flutter pub global run flutter_shadcn conflicts resolve

Select conflict to resolve [1-2]: 1

⚠️ CONFLICT #1: button/lib/button_theme.dart

[Same choice menu as above]

> 3

Opening in VS Code...
```

### Delete Without Resolving
```bash
$ flutter pub global run flutter_shadcn conflicts delete 1

Deleted conflict #1
Remaining: 1 conflict
```

---

## Implementation Details in Code

### When Update Detects Conflict

```dart
// In update_command.dart
if (state == MergeState.conflict) {
  if (strategy == 'interactive') {
    // Ask user what to do
    final choice = await _showConflictOptions(
      filePath: 'button/lib/button_theme.dart',
      yourVersion: currentContent,
      upstreamVersion: upstreamContent,
    );
    
    switch (choice) {
      case 'ours':
        // Keep user's version
        finalContent = currentContent;
        break;
        
      case 'theirs':
        // Accept upstream
        finalContent = upstreamContent;
        break;
        
      case 'manual':
        // Save with conflict markers
        finalContent = _createConflictMarkers(
          current: currentContent,
          upstream: upstreamContent,
        );
        // Open in VS Code
        await _openInVsCode(filePath);
        // Wait for user to save
        await _waitForUserToSave(filePath);
        // Read back the edited file
        finalContent = await File(filePath).readAsString();
        break;
        
      case 'skip':
        // Don't resolve, record for later
        await conflictHistory.recordConflict(...);
        return SkipResolution();
    }
  }
}
```

### Creating Conflict Markers
```dart
String _createConflictMarkers({
  required String current,
  required String upstream,
}) {
  return '''
<<<<<<< CURRENT
$current
=======
$upstream
>>>>>>> UPSTREAM
''';
}
```

### Opening in VS Code
```dart
Future<void> _openInVsCode(String filePath) async {
  final process = await Process.start(
    'code',
    ['--goto', '$filePath:1'],
  );
  // Don't wait, let user edit at their own pace
}
```

---

## User Experience Flow

### Scenario 1: Simple Update (Best Case)
```
User: flutter pub global run flutter_shadcn update button
CLI:  Checks for updates
CLI:  Analyzes changes
CLI:  ✅ All auto-mergeable!
CLI:  Creates backup
CLI:  Applies updates
CLI:  ✨ Done!

Time: ~5 seconds
User action: None (completely automated)
```

### Scenario 2: Conflict (Typical Case)
```
User: flutter pub global run flutter_shadcn update button
CLI:  Checks for updates
CLI:  Analyzes changes
CLI:  Shows analysis (2 auto-mergeable, 1 conflict)
CLI:  Shows what each side changed
User: Chooses strategy [1-4]
CLI:  If [1] or [2]: Applies choice instantly
CLI:  If [3]: Opens VS Code for manual merge
User: Merges in VS Code (uses VS Code's merge editor)
User: Saves when done
CLI:  Detects save, completes update
CLI:  ✨ Done!

Time: 5 seconds + user merge time (usually 1-2 minutes)
User action: Simple menu choice + VS Code merge editing
```

### Scenario 3: Complex (Worst Case)
```
User: flutter pub global run flutter_shadcn update button
CLI:  Detects multiple conflicts
CLI:  Shows all conflicts
User: Chooses [4] Skip for now on all
CLI:  Updates what can be updated
CLI:  Records conflicts
CLI:  ✨ Done! (Partial update)

Later:
User: flutter pub global run flutter_shadcn conflicts list
CLI:  Shows 3 pending conflicts
User: Resolves one by one or all at once
User: Uses VS Code for each one
CLI:  ✨ Done!

Time: Spread over time
User action: Manageable, not overwhelming
```

---

## Error Recovery

### What if User Quits VS Code Without Saving?

```bash
$ flutter pub global run flutter_shadcn update button

[...conflict detected...]

> 3
Opening button/lib/button_theme.dart in VS Code...

[User opens VS Code, sees conflict markers, quits without saving]

⏰ Timeout or manual cancel:

✅ No problem!
The conflict file is saved.
Try again later:
  flutter pub global run flutter_shadcn conflicts resolve
```

### What if Update Fails Halfway?

```bash
$ flutter pub global run flutter_shadcn update button

[Creates backup of v1.0.0]
[Starts updating files]
[File write fails - disk full!]

❌ Error: Disk full

✅ Safe! Backup was created first.
Rollback to v1.0.0:
  flutter pub global run flutter_shadcn rollback button --version 1.0.0
```

---

## Summary

**Instead of building a visual merge UI, we:**

1. ✅ Detect conflicts clearly
2. ✅ Show simple text descriptions
3. ✅ Offer 4 pragmatic strategies
4. ✅ For complex merges → open in VS Code
5. ✅ VS Code handles the hard part (merge editing)
6. ✅ We stay simple and focused

**Result:**
- Less code to build (<5000 lines vs 10000+)
- Better user experience (VS Code is professional)
- Fewer bugs (using existing tools)
- Easier to maintain
- Clear, predictable behavior

**User gets:**
- Simple CLI for decisions
- Professional merge editor (VS Code)
- Full control when needed
- Peace of mind (always has backup)
