# Studio Architecture & Roadmap

## Current Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                                                                       │
│                    Flutter Shadcn Studio System                       │
│                                                                       │
├─────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  CLI Layer (shadcn_flutter_cli/)                                     │
│  ├─ shadcn.dart (entry point)                                       │
│  │  └─ Parses: studio install|sync|launch|doctor                   │
│  │                                                                   │
│  └─ studio_manager.dart (service)                                   │
│     ├─ install()   → Scaffolds .shadcn/studio/                     │
│     ├─ sync()      → Generates .shadcn/studio_registry/            │
│     ├─ launch()    → Runs flutter with auto-sync                   │
│     └─ doctor()    → Health checks (5 tests)                       │
│                                                                       │
├─────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  Registry Layer (registry/)                                          │
│  ├─ components/*/preview.dart (author-written)                      │
│  │  └─ Defines PreviewEntry with variants                          │
│  │                                                                   │
│  ├─ PREVIEW_GUIDE.md (how to write previews)                       │
│  │  └─ Documents API requirements                                  │
│  │                                                                   │
│  └─ shared/ (shared utilities & tokens)                             │
│                                                                       │
├─────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  Generated Layer (per project in .shadcn/)                           │
│  ├─ studio/ (Flutter app)                                           │
│  │  ├─ lib/                                                         │
│  │  │  ├─ main.dart (2861 lines - UI template)                    │
│  │  │  │  ├─ _ThemeStudioHome (main widget)                       │
│  │  │  │  ├─ _buildSidebar() → Theme controls                     │
│  │  │  │  ├─ _buildContent() → Light/Dark editor                  │
│  │  │  │  └─ [Ready for Phase 3 UI redesign]                      │
│  │  │  └─ preview_registry.dart (exports from registry pkg)        │
│  │  ├─ pubspec.yaml (depends on studio_registry)                   │
│  │  └─ .studio_version, .last_sync (metadata)                      │
│  │                                                                   │
│  ├─ studio_registry/ (Package - NOT shipped!)                       │
│  │  ├─ lib/                                                         │
│  │  │  ├─ preview_types.dart (PreviewEntry, PreviewVariant)       │
│  │  │  ├─ preview_registry_compat.dart                            │
│  │  │  │  ├─ ComponentPreview (adapter class)                     │
│  │  │  │  ├─ previewRegistry = _buildPreviewRegistry()            │
│  │  │  │  └─ wrapPreviewTheme() (applies theme to widgets)        │
│  │  │  └─ components/                                              │
│  │  │     └─ *_preview.dart (transformed from registry)            │
│  │  ├─ pubspec.yaml (depends on app package)                       │
│  │  └─ [ONE-WAY DEPENDENCY: registry→app, never app→registry]     │
│  │                                                                   │
│  └─ tokens.json (theme configuration)                               │
│     ├─ version: 1                                                    │
│     ├─ themeMode: "light" | "dark" | "system"                      │
│     ├─ radius: 8 (scale factor)                                     │
│     ├─ density: 0 (scale factor)                                    │
│     └─ colors: {primary, secondary, accent, ...}                    │
│                                                                       │
├─────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  Data Flow                                                            │
│  registry/components/button/preview.dart                             │
│         ↓                                                             │
│  [flutter_shadcn studio --sync]                                     │
│         ↓                                                             │
│  .shadcn/studio_registry/lib/components/button_preview.dart        │
│         ↓                                                             │
│  .shadcn/studio_registry/lib/preview_registry_compat.dart          │
│         ↓                                                             │
│  .shadcn/studio/lib/preview_registry.dart (export)                 │
│         ↓                                                             │
│  main.dart → import 'preview_registry.dart' → previewRegistry      │
│         ↓                                                             │
│  [Phase 3] UI renders previewRegistry                               │
│                                                                       │
└─────────────────────────────────────────────────────────────────────┘
```

## Implementation Phases

### ✅ Phase 1-2: Complete (Weeks 1-2)
**Infrastructure & CLI**
- ✅ Studio scaffolding (install, sync, launch, doctor)
- ✅ Preview registry generation
- ✅ Component discovery
- ✅ Package transformation
- ✅ Lazy-loaded preview system
- ✅ Zero namespace errors

**Result:** Working CLI that generates a functional Flutter studio app

### 🔄 Phase 3: UI Integration (Week 3)
**Component Preview UI**
- [ ] Refactor main.dart for component-centric layout
- [ ] Left panel: Component list with search
- [ ] Center panel: Component preview with variants
- [ ] Right panel: Theme controls
- [ ] Wire data flow: Selection → Preview → Theme

**Expected Result:**
- Studio UI shows button component in list
- Selecting button renders preview
- Variants are switchable
- Theme updates affect preview
- Can save/reset tokens

### 🔮 Phase 4: Scaling (Week 4)
**Multiple Component Previews**
- [ ] Create previews for 10 popular components
- [ ] Test component discovery with multiple previews
- [ ] Verify preview caching and performance
- [ ] Add search/filtering optimizations

**Expected Result:**
- Studio shows 10+ components
- Fast filtering and selection
- Smooth preview switching

### 🚀 Phase 5: Enhancement (Week 5)
**Advanced Features**
- [ ] Hot reload for preview development
- [ ] Component screenshots
- [ ] Code generation (tokens → theme files)
- [ ] Preview variants explorer
- [ ] Dark mode preview support
- [ ] Export functionality

---

## Key Metrics

### Code Organization
| Layer | Files | LOC | Purpose |
|-------|-------|-----|---------|
| CLI | studio_manager.dart | ~600 | Lifecycle management |
| Registry | button/preview.dart | ~160 | Example preview |
| Generated | main.dart | 2861 | Studio UI template |
| Generated | preview_registry_compat.dart | ~100 | Preview adapter |
| Generated | preview_types.dart | ~40 | Type definitions |

### Performance Targets
- Preview load time: <500ms
- Component list filter: <200ms
- Theme update: <100ms
- Variant switch: <50ms
- Save operation: <300ms

### User Experience Targets
- First run: 30 seconds (install + sync + launch)
- Daily use: <5 seconds (launch with auto-sync)
- Component preview: Instant visual feedback
- Theme edit: Real-time preview update

---

## Risk & Mitigation

| Risk | Impact | Mitigation |
|------|--------|-----------|
| Preview rendering errors | High | Error boundaries, fallback UI, detailed error messages |
| Large component count | Medium | Lazy loading, pagination, optimized filtering |
| Theme not applied to preview | High | Test wrapPreviewTheme() thoroughly |
| Studio rebuild bloats app | Medium | Studio code in separate package, not shipped |
| Sync out of date | Medium | Doctor detects, auto-sync on launch |

---

## Success Criteria

### Phase 3 Success
- ✅ Studio launches without errors
- ✅ Button component visible in component list
- ✅ Selecting button renders preview correctly
- ✅ Variant switching works
- ✅ Theme controls affect preview
- ✅ Responsive layout works (desktop + tablet)
- ✅ No console errors or warnings

### Phase 4 Success
- ✅ 10+ components have working previews
- ✅ Component search works with <200ms response
- ✅ Preview switching is smooth (<100ms)
- ✅ Performance is good on slower machines

### Phase 5 Success
- ✅ Preview development is fast (hot reload works)
- ✅ Users can generate theme files from tokens
- ✅ Preview screenshots work
- ✅ Export/sharing functionality works

---

## Future Roadmap (Beyond Phase 5)

### Q2 2026: Integration
- [ ] Hook studio into CLI component installer
- [ ] Auto-sync when components added/removed
- [ ] Studio mode in shadcn CLI
- [ ] Component validation before install

### Q3 2026: Marketplace
- [ ] Public preview gallery
- [ ] Share custom themes
- [ ] Community components
- [ ] Theme marketplace

### Q4 2026: Automation
- [ ] AI-generated previews from meta.json
- [ ] Automated visual regression testing
- [ ] Preview versioning and changelog
- [ ] Component usage analytics

---

## Related Documentation

- [PREVIEW_GUIDE.md](registry/PREVIEW_GUIDE.md) - How to write component previews
- [PHASE3_IMPLEMENTATION.md](PHASE3_IMPLEMENTATION.md) - Detailed Phase 3 steps
- [studio_progress.md](studio_progress.md) - Day-to-day progress tracking
- [Flutter Shadcn Studio Plan.md](Flutter%20Shadcn%20Studio%20Plan.md) - Original architecture document

---

## Quick Links

### Commands
```bash
# First time
flutter_shadcn studio --install
flutter_shadcn studio --sync
flutter_shadcn studio  # Launch (auto-syncs if needed)
flutter_shadcn studio --doctor

# Development
cd .shadcn/studio
flutter run -d chrome
flutter run -d chrome --profile  # Performance testing
```

### Key Files
- CLI: `/shadcn_flutter_cli/lib/src/studio_manager.dart`
- UI: `.shadcn/studio/lib/main.dart`
- Preview types: `.shadcn/studio_registry/lib/preview_types.dart`
- Button preview: `.shadcn/studio_registry/lib/components/button_preview.dart`

### Environments
```bash
export SHADCN_REGISTRY_ROOT=/path/to/shadcn_flutter/registry
export FLUTTER_HOME=$(which flutter)/../..
```

---

**Status: Ready for Phase 3 Implementation! 🚀**
