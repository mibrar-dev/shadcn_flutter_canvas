# flutter_shadcn Command Test Report

- Project: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project`
- CLI source: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/shadcn_flutter_cli`
- Generated at: `2026-02-14T03:00:44Z`
- Raw logs: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_20260214_030044`

This report runs install + each top-level CLI command one by one. After each command, `dart analyze --format machine` is executed and categorized.

## 01. install_cli

- Command: `dart pub global activate --source path '/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/shadcn_flutter_cli'`
- Command exit code: `0`
- Command stdout: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_20260214_030044/1_install_cli.stdout.log`
- Command stderr: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_20260214_030044/1_install_cli.stderr.log`
- `dart analyze` exit code: `0`
- Analyzer totals: `ERROR=0`, `WARNING=0`, `INFO=0`

| Severity | Diagnostic Code | Count |
|---|---|---:|

**Top diagnostics (first 15):**

## 02. init

- Command: `/Users/ibrar/.pub-cache/bin/flutter_shadcn init --yes --install-icons --install-fonts`
- Command exit code: `0`
- Command stdout: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_20260214_030044/2_init.stdout.log`
- Command stderr: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_20260214_030044/2_init.stderr.log`
- `dart analyze` exit code: `3`
- Analyzer totals: `ERROR=46`, `WARNING=0`, `INFO=5`

| Severity | Diagnostic Code | Count |
|---|---|---:|
| ERROR | UNDEFINED_IDENTIFIER | 14 |
| ERROR | UNDEFINED_CLASS | 10 |
| ERROR | URI_DOES_NOT_EXIST | 8 |
| ERROR | CREATION_WITH_NON_TYPE | 6 |
| ERROR | NON_TYPE_AS_TYPE_ARGUMENT | 6 |
| ERROR | CONST_INITIALIZED_WITH_NON_CONSTANT_VALUE | 1 |
| ERROR | UNDEFINED_FUNCTION | 1 |
| INFO | DEPEND_ON_REFERENCED_PACKAGES | 4 |
| INFO | UNNECESSARY_IMPORT | 1 |

**Top diagnostics (first 15):**
- [ERROR] UNDEFINED_IDENTIFIER (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/_impl/core/__form_entry_cached_value.dart:37:20) Undefined name 'Data'.
- [ERROR] URI_DOES_NOT_EXIST (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/form_value_supplier.dart:3:8) Target of URI doesn't exist: 'package:data_widget/data_widget.dart'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/component_theme_data.dart:6:9) Undefined class 'Density'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/component_theme_data.dart:9:9) Undefined class 'SpacingScale'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/component_theme_data.dart:12:9) Undefined class 'ShadowScale'.
- [ERROR] CONST_INITIALIZED_WITH_NON_CONSTANT_VALUE (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme.dart:37:22) Const variables must be initialized with a constant value.
- [ERROR] UNDEFINED_IDENTIFIER (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme.dart:37:22) Undefined name 'ColorSchemes'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:6:9) Undefined class 'ColorScheme'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:9:9) Undefined class 'Typography'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:18:9) Undefined class 'Density'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:21:9) Undefined class 'SpacingScale'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:24:9) Undefined class 'TrackingScale'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:27:9) Undefined class 'ShadowScale'.
- [ERROR] UNDEFINED_IDENTIFIER (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:56:24) Undefined name 'ColorSchemes'.
- [ERROR] UNDEFINED_IDENTIFIER (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:59:20) Undefined name 'Density'.

## 03. theme

- Command: `/Users/ibrar/.pub-cache/bin/flutter_shadcn theme --list`
- Command exit code: `0`
- Command stdout: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_20260214_030044/3_theme.stdout.log`
- Command stderr: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_20260214_030044/3_theme.stderr.log`
- `dart analyze` exit code: `3`
- Analyzer totals: `ERROR=46`, `WARNING=0`, `INFO=5`

| Severity | Diagnostic Code | Count |
|---|---|---:|
| ERROR | UNDEFINED_IDENTIFIER | 14 |
| ERROR | UNDEFINED_CLASS | 10 |
| ERROR | URI_DOES_NOT_EXIST | 8 |
| ERROR | CREATION_WITH_NON_TYPE | 6 |
| ERROR | NON_TYPE_AS_TYPE_ARGUMENT | 6 |
| ERROR | CONST_INITIALIZED_WITH_NON_CONSTANT_VALUE | 1 |
| ERROR | UNDEFINED_FUNCTION | 1 |
| INFO | DEPEND_ON_REFERENCED_PACKAGES | 4 |
| INFO | UNNECESSARY_IMPORT | 1 |

**Top diagnostics (first 15):**
- [ERROR] UNDEFINED_IDENTIFIER (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/_impl/core/__form_entry_cached_value.dart:37:20) Undefined name 'Data'.
- [ERROR] URI_DOES_NOT_EXIST (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/form_value_supplier.dart:3:8) Target of URI doesn't exist: 'package:data_widget/data_widget.dart'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/component_theme_data.dart:6:9) Undefined class 'Density'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/component_theme_data.dart:9:9) Undefined class 'SpacingScale'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/component_theme_data.dart:12:9) Undefined class 'ShadowScale'.
- [ERROR] CONST_INITIALIZED_WITH_NON_CONSTANT_VALUE (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme.dart:37:22) Const variables must be initialized with a constant value.
- [ERROR] UNDEFINED_IDENTIFIER (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme.dart:37:22) Undefined name 'ColorSchemes'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:6:9) Undefined class 'ColorScheme'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:9:9) Undefined class 'Typography'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:18:9) Undefined class 'Density'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:21:9) Undefined class 'SpacingScale'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:24:9) Undefined class 'TrackingScale'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:27:9) Undefined class 'ShadowScale'.
- [ERROR] UNDEFINED_IDENTIFIER (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:56:24) Undefined name 'ColorSchemes'.
- [ERROR] UNDEFINED_IDENTIFIER (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:59:20) Undefined name 'Density'.

## 04. add

- Command: `/Users/ibrar/.pub-cache/bin/flutter_shadcn add @shadcn/button`
- Command exit code: `0`
- Command stdout: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_20260214_030044/4_add.stdout.log`
- Command stderr: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_20260214_030044/4_add.stderr.log`
- `dart analyze` exit code: `3`
- Analyzer totals: `ERROR=86`, `WARNING=69`, `INFO=3`

| Severity | Diagnostic Code | Count |
|---|---|---:|
| ERROR | UNDEFINED_IDENTIFIER | 33 |
| ERROR | URI_DOES_NOT_EXIST | 22 |
| ERROR | UNDEFINED_CLASS | 10 |
| ERROR | CREATION_WITH_NON_TYPE | 8 |
| ERROR | NON_TYPE_AS_TYPE_ARGUMENT | 6 |
| ERROR | UNDEFINED_METHOD | 5 |
| ERROR | CONST_INITIALIZED_WITH_NON_CONSTANT_VALUE | 1 |
| ERROR | UNDEFINED_FUNCTION | 1 |
| INFO | UNNECESSARY_IMPORT | 2 |
| INFO | USE_NULL_AWARE_ELEMENTS | 1 |
| WARNING | UNUSED_IMPORT | 69 |

**Top diagnostics (first 15):**
- [ERROR] URI_DOES_NOT_EXIST (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/components/control/button/_impl/core/button_group_widget.dart:1:8) Target of URI doesn't exist: 'package:data_widget/data_widget.dart'.
- [ERROR] UNDEFINED_IDENTIFIER (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/components/control/button/_impl/core/button_group_widget.dart:82:29) Undefined name 'Data'.
- [ERROR] UNDEFINED_IDENTIFIER (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/components/control/button/_impl/core/button_group_widget.dart:92:23) Undefined name 'Data'.
- [ERROR] URI_DOES_NOT_EXIST (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/components/control/button/_impl/core/button_widget.dart:1:8) Target of URI doesn't exist: 'package:data_widget/data_widget.dart'.
- [ERROR] URI_DOES_NOT_EXIST (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/components/control/button/_impl/core/button_widget.dart:3:8) Target of URI doesn't exist: 'package:gap/gap.dart'.
- [ERROR] URI_DOES_NOT_EXIST (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/components/control/button/_impl/core/button_widget.dart:7:8) Target of URI doesn't exist: '../../../../../shared/utils/geometry_extensions.dart'.
- [ERROR] URI_DOES_NOT_EXIST (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/components/control/button/_impl/state/button_state.dart:1:8) Target of URI doesn't exist: 'package:data_widget/data_widget.dart'.
- [ERROR] URI_DOES_NOT_EXIST (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/components/control/button/_impl/state/button_state.dart:3:8) Target of URI doesn't exist: 'package:gap/gap.dart'.
- [ERROR] URI_DOES_NOT_EXIST (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/components/control/button/_impl/state/button_state.dart:7:8) Target of URI doesn't exist: '../../../../../shared/utils/geometry_extensions.dart'.
- [ERROR] UNDEFINED_IDENTIFIER (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/components/control/button/_impl/state/button_state.dart:40:24) Undefined name 'Data'.
- [ERROR] UNDEFINED_METHOD (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/components/control/button/_impl/state/button_state.dart:171:49) The method 'DensityGap' isn't defined for the type 'ButtonState'.
- [ERROR] UNDEFINED_IDENTIFIER (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/components/control/button/_impl/state/button_state.dart:171:60) Undefined name 'gapSm'.
- [ERROR] UNDEFINED_METHOD (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/components/control/button/_impl/state/button_state.dart:183:50) The method 'DensityGap' isn't defined for the type 'ButtonState'.
- [ERROR] UNDEFINED_IDENTIFIER (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/components/control/button/_impl/state/button_state.dart:183:61) Undefined name 'gapSm'.
- [ERROR] URI_DOES_NOT_EXIST (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/components/control/button/_impl/styles/button_style_class.dart:3:8) Target of URI doesn't exist: '../../../../../shared/utils/geometry_extensions.dart'.

## 05. dry_run

- Command: `/Users/ibrar/.pub-cache/bin/flutter_shadcn dry-run @shadcn/button`
- Command exit code: `30`
- Command stdout: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_20260214_030044/5_dry_run.stdout.log`
- Command stderr: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_20260214_030044/5_dry_run.stderr.log`
- `dart analyze` exit code: `3`
- Analyzer totals: `ERROR=58`, `WARNING=73`, `INFO=3`

| Severity | Diagnostic Code | Count |
|---|---|---:|
| ERROR | UNDEFINED_IDENTIFIER | 21 |
| ERROR | URI_DOES_NOT_EXIST | 10 |
| ERROR | UNDEFINED_CLASS | 9 |
| ERROR | CREATION_WITH_NON_TYPE | 6 |
| ERROR | NON_TYPE_AS_TYPE_ARGUMENT | 6 |
| ERROR | UNDEFINED_METHOD | 5 |
| ERROR | CONST_INITIALIZED_WITH_NON_CONSTANT_VALUE | 1 |
| INFO | UNNECESSARY_IMPORT | 2 |
| INFO | USE_NULL_AWARE_ELEMENTS | 1 |
| WARNING | UNUSED_IMPORT | 73 |

**Top diagnostics (first 15):**
- [ERROR] URI_DOES_NOT_EXIST (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/components/control/button/_impl/core/button_widget.dart:7:8) Target of URI doesn't exist: '../../../../../shared/utils/geometry_extensions.dart'.
- [ERROR] URI_DOES_NOT_EXIST (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/components/control/button/_impl/state/button_state.dart:7:8) Target of URI doesn't exist: '../../../../../shared/utils/geometry_extensions.dart'.
- [ERROR] UNDEFINED_METHOD (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/components/control/button/_impl/state/button_state.dart:171:49) The method 'DensityGap' isn't defined for the type 'ButtonState'.
- [ERROR] UNDEFINED_IDENTIFIER (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/components/control/button/_impl/state/button_state.dart:171:60) Undefined name 'gapSm'.
- [ERROR] UNDEFINED_METHOD (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/components/control/button/_impl/state/button_state.dart:183:50) The method 'DensityGap' isn't defined for the type 'ButtonState'.
- [ERROR] UNDEFINED_IDENTIFIER (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/components/control/button/_impl/state/button_state.dart:183:61) Undefined name 'gapSm'.
- [ERROR] URI_DOES_NOT_EXIST (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/components/control/button/_impl/styles/button_style_class.dart:3:8) Target of URI doesn't exist: '../../../../../shared/utils/geometry_extensions.dart'.
- [ERROR] UNDEFINED_METHOD (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/components/control/button/_impl/styles/button_style_class.dart:298:41) The method 'optionallyResolve' isn't defined for the type 'EdgeInsetsGeometry'.
- [ERROR] URI_DOES_NOT_EXIST (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/components/control/button/_impl/utils/button_helpers.dart:6:8) Target of URI doesn't exist: '../../../../../shared/theme/generated_colors.dart'.
- [ERROR] UNDEFINED_IDENTIFIER (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/components/control/button/_impl/utils/button_helpers.dart:26:68) Undefined name 'padSm'.
- [ERROR] UNDEFINED_IDENTIFIER (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/components/control/button/_impl/utils/button_helpers.dart:27:66) Undefined name 'padXs'.
- [ERROR] UNDEFINED_IDENTIFIER (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/components/control/button/_impl/utils/button_helpers.dart:78:58) Undefined name 'padSm'.
- [ERROR] UNDEFINED_IDENTIFIER (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/components/control/button/_impl/utils/button_helpers.dart:128:56) Undefined name 'padXs'.
- [ERROR] UNDEFINED_IDENTIFIER (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/components/control/button/_impl/utils/button_helpers.dart:457:15) Undefined name 'Colors'.
- [ERROR] UNDEFINED_IDENTIFIER (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/components/control/button/_impl/utils/button_helpers.dart:470:11) Undefined name 'Colors'.

## 06. remove

- Command: `/Users/ibrar/.pub-cache/bin/flutter_shadcn remove @shadcn/button --force`
- Command exit code: `0`
- Command stdout: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_20260214_030044/6_remove.stdout.log`
- Command stderr: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_20260214_030044/6_remove.stderr.log`
- `dart analyze` exit code: `3`
- Analyzer totals: `ERROR=58`, `WARNING=0`, `INFO=7`

| Severity | Diagnostic Code | Count |
|---|---|---:|
| ERROR | UNDEFINED_IDENTIFIER | 19 |
| ERROR | URI_DOES_NOT_EXIST | 11 |
| ERROR | UNDEFINED_CLASS | 10 |
| ERROR | CREATION_WITH_NON_TYPE | 8 |
| ERROR | NON_TYPE_AS_TYPE_ARGUMENT | 6 |
| ERROR | UNDEFINED_METHOD | 2 |
| ERROR | CONST_INITIALIZED_WITH_NON_CONSTANT_VALUE | 1 |
| ERROR | UNDEFINED_FUNCTION | 1 |
| INFO | DEPEND_ON_REFERENCED_PACKAGES | 5 |
| INFO | UNNECESSARY_IMPORT | 1 |
| INFO | USE_NULL_AWARE_ELEMENTS | 1 |

**Top diagnostics (first 15):**
- [ERROR] UNDEFINED_IDENTIFIER (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/_impl/core/__builder_stated_widget.dart:17:36) Undefined name 'Data'.
- [ERROR] UNDEFINED_IDENTIFIER (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/_impl/core/__form_entry_cached_value.dart:37:20) Undefined name 'Data'.
- [ERROR] UNDEFINED_IDENTIFIER (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/_impl/core/__map_stated_widget.dart:23:36) Undefined name 'Data'.
- [ERROR] UNDEFINED_IDENTIFIER (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/_impl/core/__param_stated_widget.dart:67:36) Undefined name 'Data'.
- [ERROR] CREATION_WITH_NON_TYPE (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/_impl/core/widget_states_provider.dart:58:14) The name 'Data' isn't a class.
- [ERROR] UNDEFINED_IDENTIFIER (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/_impl/core/widget_states_provider.dart:65:38) Undefined name 'Data'.
- [ERROR] CREATION_WITH_NON_TYPE (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/_impl/core/widget_states_provider.dart:81:16) The name 'Data' isn't a class.
- [ERROR] UNDEFINED_IDENTIFIER (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/_impl/state/__clickable_state.dart:106:24) Undefined name 'Data'.
- [ERROR] UNDEFINED_METHOD (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/_impl/state/__clickable_state.dart:117:12) The method 'FocusOutline' isn't defined for the type '_ClickableState'.
- [ERROR] UNDEFINED_METHOD (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/_impl/state/__clickable_state.dart:253:26) The method 'AnimatedValueBuilder' isn't defined for the type '_ClickableState'.
- [ERROR] URI_DOES_NOT_EXIST (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/clickable.dart:1:8) Target of URI doesn't exist: 'package:data_widget/data_widget.dart'.
- [ERROR] URI_DOES_NOT_EXIST (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/clickable.dart:8:8) Target of URI doesn't exist: 'animated_value_builder.dart'.
- [ERROR] URI_DOES_NOT_EXIST (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/clickable.dart:9:8) Target of URI doesn't exist: 'focus_outline.dart'.
- [ERROR] URI_DOES_NOT_EXIST (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/form_value_supplier.dart:3:8) Target of URI doesn't exist: 'package:data_widget/data_widget.dart'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/component_theme_data.dart:6:9) Undefined class 'Density'.

## 07. sync

- Command: `/Users/ibrar/.pub-cache/bin/flutter_shadcn sync`
- Command exit code: `0`
- Command stdout: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_20260214_030044/7_sync.stdout.log`
- Command stderr: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_20260214_030044/7_sync.stderr.log`
- `dart analyze` exit code: `3`
- Analyzer totals: `ERROR=58`, `WARNING=0`, `INFO=2`

| Severity | Diagnostic Code | Count |
|---|---|---:|
| ERROR | UNDEFINED_IDENTIFIER | 19 |
| ERROR | URI_DOES_NOT_EXIST | 11 |
| ERROR | UNDEFINED_CLASS | 10 |
| ERROR | CREATION_WITH_NON_TYPE | 8 |
| ERROR | NON_TYPE_AS_TYPE_ARGUMENT | 6 |
| ERROR | UNDEFINED_METHOD | 2 |
| ERROR | CONST_INITIALIZED_WITH_NON_CONSTANT_VALUE | 1 |
| ERROR | UNDEFINED_FUNCTION | 1 |
| INFO | UNNECESSARY_IMPORT | 1 |
| INFO | USE_NULL_AWARE_ELEMENTS | 1 |

**Top diagnostics (first 15):**
- [ERROR] UNDEFINED_IDENTIFIER (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/_impl/core/__builder_stated_widget.dart:17:36) Undefined name 'Data'.
- [ERROR] UNDEFINED_IDENTIFIER (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/_impl/core/__form_entry_cached_value.dart:37:20) Undefined name 'Data'.
- [ERROR] UNDEFINED_IDENTIFIER (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/_impl/core/__map_stated_widget.dart:23:36) Undefined name 'Data'.
- [ERROR] UNDEFINED_IDENTIFIER (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/_impl/core/__param_stated_widget.dart:67:36) Undefined name 'Data'.
- [ERROR] CREATION_WITH_NON_TYPE (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/_impl/core/widget_states_provider.dart:58:14) The name 'Data' isn't a class.
- [ERROR] UNDEFINED_IDENTIFIER (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/_impl/core/widget_states_provider.dart:65:38) Undefined name 'Data'.
- [ERROR] CREATION_WITH_NON_TYPE (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/_impl/core/widget_states_provider.dart:81:16) The name 'Data' isn't a class.
- [ERROR] UNDEFINED_IDENTIFIER (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/_impl/state/__clickable_state.dart:106:24) Undefined name 'Data'.
- [ERROR] UNDEFINED_METHOD (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/_impl/state/__clickable_state.dart:117:12) The method 'FocusOutline' isn't defined for the type '_ClickableState'.
- [ERROR] UNDEFINED_METHOD (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/_impl/state/__clickable_state.dart:253:26) The method 'AnimatedValueBuilder' isn't defined for the type '_ClickableState'.
- [ERROR] URI_DOES_NOT_EXIST (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/clickable.dart:1:8) Target of URI doesn't exist: 'package:data_widget/data_widget.dart'.
- [ERROR] URI_DOES_NOT_EXIST (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/clickable.dart:8:8) Target of URI doesn't exist: 'animated_value_builder.dart'.
- [ERROR] URI_DOES_NOT_EXIST (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/clickable.dart:9:8) Target of URI doesn't exist: 'focus_outline.dart'.
- [ERROR] URI_DOES_NOT_EXIST (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/form_value_supplier.dart:3:8) Target of URI doesn't exist: 'package:data_widget/data_widget.dart'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/component_theme_data.dart:6:9) Undefined class 'Density'.

## 08. assets

- Command: `/Users/ibrar/.pub-cache/bin/flutter_shadcn assets --icons`
- Command exit code: `255`
- Command stdout: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_20260214_030044/8_assets.stdout.log`
- Command stderr: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_20260214_030044/8_assets.stderr.log`
- `dart analyze` exit code: `3`
- Analyzer totals: `ERROR=43`, `WARNING=1`, `INFO=2`

| Severity | Diagnostic Code | Count |
|---|---|---:|
| ERROR | UNDEFINED_IDENTIFIER | 13 |
| ERROR | UNDEFINED_CLASS | 9 |
| ERROR | CREATION_WITH_NON_TYPE | 6 |
| ERROR | NON_TYPE_AS_TYPE_ARGUMENT | 6 |
| ERROR | URI_DOES_NOT_EXIST | 6 |
| ERROR | UNDEFINED_METHOD | 2 |
| ERROR | CONST_INITIALIZED_WITH_NON_CONSTANT_VALUE | 1 |
| INFO | UNNECESSARY_IMPORT | 1 |
| INFO | USE_NULL_AWARE_ELEMENTS | 1 |
| WARNING | UNUSED_IMPORT | 1 |

**Top diagnostics (first 15):**
- [ERROR] UNDEFINED_METHOD (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/_impl/state/__clickable_state.dart:117:12) The method 'FocusOutline' isn't defined for the type '_ClickableState'.
- [ERROR] UNDEFINED_METHOD (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/_impl/state/__clickable_state.dart:253:26) The method 'AnimatedValueBuilder' isn't defined for the type '_ClickableState'.
- [ERROR] URI_DOES_NOT_EXIST (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/clickable.dart:8:8) Target of URI doesn't exist: 'animated_value_builder.dart'.
- [ERROR] URI_DOES_NOT_EXIST (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/clickable.dart:9:8) Target of URI doesn't exist: 'focus_outline.dart'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/component_theme_data.dart:6:9) Undefined class 'Density'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/component_theme_data.dart:9:9) Undefined class 'SpacingScale'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/component_theme_data.dart:12:9) Undefined class 'ShadowScale'.
- [ERROR] CONST_INITIALIZED_WITH_NON_CONSTANT_VALUE (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme.dart:37:22) Const variables must be initialized with a constant value.
- [ERROR] UNDEFINED_IDENTIFIER (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme.dart:37:22) Undefined name 'ColorSchemes'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:6:9) Undefined class 'ColorScheme'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:9:9) Undefined class 'Typography'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:18:9) Undefined class 'Density'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:21:9) Undefined class 'SpacingScale'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:24:9) Undefined class 'TrackingScale'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:27:9) Undefined class 'ShadowScale'.

## 09. platform

- Command: `/Users/ibrar/.pub-cache/bin/flutter_shadcn platform --list`
- Command exit code: `0`
- Command stdout: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_20260214_030044/9_platform.stdout.log`
- Command stderr: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_20260214_030044/9_platform.stderr.log`
- `dart analyze` exit code: `3`
- Analyzer totals: `ERROR=43`, `WARNING=1`, `INFO=2`

| Severity | Diagnostic Code | Count |
|---|---|---:|
| ERROR | UNDEFINED_IDENTIFIER | 13 |
| ERROR | UNDEFINED_CLASS | 9 |
| ERROR | CREATION_WITH_NON_TYPE | 6 |
| ERROR | NON_TYPE_AS_TYPE_ARGUMENT | 6 |
| ERROR | URI_DOES_NOT_EXIST | 6 |
| ERROR | UNDEFINED_METHOD | 2 |
| ERROR | CONST_INITIALIZED_WITH_NON_CONSTANT_VALUE | 1 |
| INFO | UNNECESSARY_IMPORT | 1 |
| INFO | USE_NULL_AWARE_ELEMENTS | 1 |
| WARNING | UNUSED_IMPORT | 1 |

**Top diagnostics (first 15):**
- [ERROR] UNDEFINED_METHOD (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/_impl/state/__clickable_state.dart:117:12) The method 'FocusOutline' isn't defined for the type '_ClickableState'.
- [ERROR] UNDEFINED_METHOD (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/_impl/state/__clickable_state.dart:253:26) The method 'AnimatedValueBuilder' isn't defined for the type '_ClickableState'.
- [ERROR] URI_DOES_NOT_EXIST (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/clickable.dart:8:8) Target of URI doesn't exist: 'animated_value_builder.dart'.
- [ERROR] URI_DOES_NOT_EXIST (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/clickable.dart:9:8) Target of URI doesn't exist: 'focus_outline.dart'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/component_theme_data.dart:6:9) Undefined class 'Density'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/component_theme_data.dart:9:9) Undefined class 'SpacingScale'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/component_theme_data.dart:12:9) Undefined class 'ShadowScale'.
- [ERROR] CONST_INITIALIZED_WITH_NON_CONSTANT_VALUE (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme.dart:37:22) Const variables must be initialized with a constant value.
- [ERROR] UNDEFINED_IDENTIFIER (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme.dart:37:22) Undefined name 'ColorSchemes'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:6:9) Undefined class 'ColorScheme'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:9:9) Undefined class 'Typography'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:18:9) Undefined class 'Density'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:21:9) Undefined class 'SpacingScale'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:24:9) Undefined class 'TrackingScale'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:27:9) Undefined class 'ShadowScale'.

## 10. registries

- Command: `/Users/ibrar/.pub-cache/bin/flutter_shadcn registries`
- Command exit code: `0`
- Command stdout: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_20260214_030044/10_registries.stdout.log`
- Command stderr: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_20260214_030044/10_registries.stderr.log`
- `dart analyze` exit code: `3`
- Analyzer totals: `ERROR=43`, `WARNING=1`, `INFO=2`

| Severity | Diagnostic Code | Count |
|---|---|---:|
| ERROR | UNDEFINED_IDENTIFIER | 13 |
| ERROR | UNDEFINED_CLASS | 9 |
| ERROR | CREATION_WITH_NON_TYPE | 6 |
| ERROR | NON_TYPE_AS_TYPE_ARGUMENT | 6 |
| ERROR | URI_DOES_NOT_EXIST | 6 |
| ERROR | UNDEFINED_METHOD | 2 |
| ERROR | CONST_INITIALIZED_WITH_NON_CONSTANT_VALUE | 1 |
| INFO | UNNECESSARY_IMPORT | 1 |
| INFO | USE_NULL_AWARE_ELEMENTS | 1 |
| WARNING | UNUSED_IMPORT | 1 |

**Top diagnostics (first 15):**
- [ERROR] UNDEFINED_METHOD (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/_impl/state/__clickable_state.dart:117:12) The method 'FocusOutline' isn't defined for the type '_ClickableState'.
- [ERROR] UNDEFINED_METHOD (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/_impl/state/__clickable_state.dart:253:26) The method 'AnimatedValueBuilder' isn't defined for the type '_ClickableState'.
- [ERROR] URI_DOES_NOT_EXIST (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/clickable.dart:8:8) Target of URI doesn't exist: 'animated_value_builder.dart'.
- [ERROR] URI_DOES_NOT_EXIST (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/clickable.dart:9:8) Target of URI doesn't exist: 'focus_outline.dart'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/component_theme_data.dart:6:9) Undefined class 'Density'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/component_theme_data.dart:9:9) Undefined class 'SpacingScale'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/component_theme_data.dart:12:9) Undefined class 'ShadowScale'.
- [ERROR] CONST_INITIALIZED_WITH_NON_CONSTANT_VALUE (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme.dart:37:22) Const variables must be initialized with a constant value.
- [ERROR] UNDEFINED_IDENTIFIER (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme.dart:37:22) Undefined name 'ColorSchemes'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:6:9) Undefined class 'ColorScheme'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:9:9) Undefined class 'Typography'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:18:9) Undefined class 'Density'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:21:9) Undefined class 'SpacingScale'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:24:9) Undefined class 'TrackingScale'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:27:9) Undefined class 'ShadowScale'.

## 11. default

- Command: `/Users/ibrar/.pub-cache/bin/flutter_shadcn default`
- Command exit code: `0`
- Command stdout: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_20260214_030044/11_default.stdout.log`
- Command stderr: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_20260214_030044/11_default.stderr.log`
- `dart analyze` exit code: `3`
- Analyzer totals: `ERROR=43`, `WARNING=1`, `INFO=2`

| Severity | Diagnostic Code | Count |
|---|---|---:|
| ERROR | UNDEFINED_IDENTIFIER | 13 |
| ERROR | UNDEFINED_CLASS | 9 |
| ERROR | CREATION_WITH_NON_TYPE | 6 |
| ERROR | NON_TYPE_AS_TYPE_ARGUMENT | 6 |
| ERROR | URI_DOES_NOT_EXIST | 6 |
| ERROR | UNDEFINED_METHOD | 2 |
| ERROR | CONST_INITIALIZED_WITH_NON_CONSTANT_VALUE | 1 |
| INFO | UNNECESSARY_IMPORT | 1 |
| INFO | USE_NULL_AWARE_ELEMENTS | 1 |
| WARNING | UNUSED_IMPORT | 1 |

**Top diagnostics (first 15):**
- [ERROR] UNDEFINED_METHOD (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/_impl/state/__clickable_state.dart:117:12) The method 'FocusOutline' isn't defined for the type '_ClickableState'.
- [ERROR] UNDEFINED_METHOD (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/_impl/state/__clickable_state.dart:253:26) The method 'AnimatedValueBuilder' isn't defined for the type '_ClickableState'.
- [ERROR] URI_DOES_NOT_EXIST (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/clickable.dart:8:8) Target of URI doesn't exist: 'animated_value_builder.dart'.
- [ERROR] URI_DOES_NOT_EXIST (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/clickable.dart:9:8) Target of URI doesn't exist: 'focus_outline.dart'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/component_theme_data.dart:6:9) Undefined class 'Density'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/component_theme_data.dart:9:9) Undefined class 'SpacingScale'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/component_theme_data.dart:12:9) Undefined class 'ShadowScale'.
- [ERROR] CONST_INITIALIZED_WITH_NON_CONSTANT_VALUE (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme.dart:37:22) Const variables must be initialized with a constant value.
- [ERROR] UNDEFINED_IDENTIFIER (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme.dart:37:22) Undefined name 'ColorSchemes'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:6:9) Undefined class 'ColorScheme'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:9:9) Undefined class 'Typography'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:18:9) Undefined class 'Density'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:21:9) Undefined class 'SpacingScale'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:24:9) Undefined class 'TrackingScale'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:27:9) Undefined class 'ShadowScale'.

## 12. list

- Command: `/Users/ibrar/.pub-cache/bin/flutter_shadcn list`
- Command exit code: `0`
- Command stdout: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_20260214_030044/12_list.stdout.log`
- Command stderr: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_20260214_030044/12_list.stderr.log`
- `dart analyze` exit code: `3`
- Analyzer totals: `ERROR=43`, `WARNING=1`, `INFO=2`

| Severity | Diagnostic Code | Count |
|---|---|---:|
| ERROR | UNDEFINED_IDENTIFIER | 13 |
| ERROR | UNDEFINED_CLASS | 9 |
| ERROR | CREATION_WITH_NON_TYPE | 6 |
| ERROR | NON_TYPE_AS_TYPE_ARGUMENT | 6 |
| ERROR | URI_DOES_NOT_EXIST | 6 |
| ERROR | UNDEFINED_METHOD | 2 |
| ERROR | CONST_INITIALIZED_WITH_NON_CONSTANT_VALUE | 1 |
| INFO | UNNECESSARY_IMPORT | 1 |
| INFO | USE_NULL_AWARE_ELEMENTS | 1 |
| WARNING | UNUSED_IMPORT | 1 |

**Top diagnostics (first 15):**
- [ERROR] UNDEFINED_METHOD (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/_impl/state/__clickable_state.dart:117:12) The method 'FocusOutline' isn't defined for the type '_ClickableState'.
- [ERROR] UNDEFINED_METHOD (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/_impl/state/__clickable_state.dart:253:26) The method 'AnimatedValueBuilder' isn't defined for the type '_ClickableState'.
- [ERROR] URI_DOES_NOT_EXIST (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/clickable.dart:8:8) Target of URI doesn't exist: 'animated_value_builder.dart'.
- [ERROR] URI_DOES_NOT_EXIST (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/clickable.dart:9:8) Target of URI doesn't exist: 'focus_outline.dart'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/component_theme_data.dart:6:9) Undefined class 'Density'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/component_theme_data.dart:9:9) Undefined class 'SpacingScale'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/component_theme_data.dart:12:9) Undefined class 'ShadowScale'.
- [ERROR] CONST_INITIALIZED_WITH_NON_CONSTANT_VALUE (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme.dart:37:22) Const variables must be initialized with a constant value.
- [ERROR] UNDEFINED_IDENTIFIER (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme.dart:37:22) Undefined name 'ColorSchemes'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:6:9) Undefined class 'ColorScheme'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:9:9) Undefined class 'Typography'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:18:9) Undefined class 'Density'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:21:9) Undefined class 'SpacingScale'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:24:9) Undefined class 'TrackingScale'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:27:9) Undefined class 'ShadowScale'.

## 13. search

- Command: `/Users/ibrar/.pub-cache/bin/flutter_shadcn search button`
- Command exit code: `0`
- Command stdout: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_20260214_030044/13_search.stdout.log`
- Command stderr: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_20260214_030044/13_search.stderr.log`
- `dart analyze` exit code: `3`
- Analyzer totals: `ERROR=43`, `WARNING=1`, `INFO=2`

| Severity | Diagnostic Code | Count |
|---|---|---:|
| ERROR | UNDEFINED_IDENTIFIER | 13 |
| ERROR | UNDEFINED_CLASS | 9 |
| ERROR | CREATION_WITH_NON_TYPE | 6 |
| ERROR | NON_TYPE_AS_TYPE_ARGUMENT | 6 |
| ERROR | URI_DOES_NOT_EXIST | 6 |
| ERROR | UNDEFINED_METHOD | 2 |
| ERROR | CONST_INITIALIZED_WITH_NON_CONSTANT_VALUE | 1 |
| INFO | UNNECESSARY_IMPORT | 1 |
| INFO | USE_NULL_AWARE_ELEMENTS | 1 |
| WARNING | UNUSED_IMPORT | 1 |

**Top diagnostics (first 15):**
- [ERROR] UNDEFINED_METHOD (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/_impl/state/__clickable_state.dart:117:12) The method 'FocusOutline' isn't defined for the type '_ClickableState'.
- [ERROR] UNDEFINED_METHOD (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/_impl/state/__clickable_state.dart:253:26) The method 'AnimatedValueBuilder' isn't defined for the type '_ClickableState'.
- [ERROR] URI_DOES_NOT_EXIST (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/clickable.dart:8:8) Target of URI doesn't exist: 'animated_value_builder.dart'.
- [ERROR] URI_DOES_NOT_EXIST (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/clickable.dart:9:8) Target of URI doesn't exist: 'focus_outline.dart'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/component_theme_data.dart:6:9) Undefined class 'Density'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/component_theme_data.dart:9:9) Undefined class 'SpacingScale'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/component_theme_data.dart:12:9) Undefined class 'ShadowScale'.
- [ERROR] CONST_INITIALIZED_WITH_NON_CONSTANT_VALUE (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme.dart:37:22) Const variables must be initialized with a constant value.
- [ERROR] UNDEFINED_IDENTIFIER (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme.dart:37:22) Undefined name 'ColorSchemes'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:6:9) Undefined class 'ColorScheme'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:9:9) Undefined class 'Typography'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:18:9) Undefined class 'Density'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:21:9) Undefined class 'SpacingScale'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:24:9) Undefined class 'TrackingScale'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:27:9) Undefined class 'ShadowScale'.

## 14. info

- Command: `/Users/ibrar/.pub-cache/bin/flutter_shadcn info @shadcn/button`
- Command exit code: `0`
- Command stdout: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_20260214_030044/14_info.stdout.log`
- Command stderr: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_20260214_030044/14_info.stderr.log`
- `dart analyze` exit code: `3`
- Analyzer totals: `ERROR=43`, `WARNING=1`, `INFO=2`

| Severity | Diagnostic Code | Count |
|---|---|---:|
| ERROR | UNDEFINED_IDENTIFIER | 13 |
| ERROR | UNDEFINED_CLASS | 9 |
| ERROR | CREATION_WITH_NON_TYPE | 6 |
| ERROR | NON_TYPE_AS_TYPE_ARGUMENT | 6 |
| ERROR | URI_DOES_NOT_EXIST | 6 |
| ERROR | UNDEFINED_METHOD | 2 |
| ERROR | CONST_INITIALIZED_WITH_NON_CONSTANT_VALUE | 1 |
| INFO | UNNECESSARY_IMPORT | 1 |
| INFO | USE_NULL_AWARE_ELEMENTS | 1 |
| WARNING | UNUSED_IMPORT | 1 |

**Top diagnostics (first 15):**
- [ERROR] UNDEFINED_METHOD (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/_impl/state/__clickable_state.dart:117:12) The method 'FocusOutline' isn't defined for the type '_ClickableState'.
- [ERROR] UNDEFINED_METHOD (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/_impl/state/__clickable_state.dart:253:26) The method 'AnimatedValueBuilder' isn't defined for the type '_ClickableState'.
- [ERROR] URI_DOES_NOT_EXIST (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/clickable.dart:8:8) Target of URI doesn't exist: 'animated_value_builder.dart'.
- [ERROR] URI_DOES_NOT_EXIST (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/clickable.dart:9:8) Target of URI doesn't exist: 'focus_outline.dart'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/component_theme_data.dart:6:9) Undefined class 'Density'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/component_theme_data.dart:9:9) Undefined class 'SpacingScale'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/component_theme_data.dart:12:9) Undefined class 'ShadowScale'.
- [ERROR] CONST_INITIALIZED_WITH_NON_CONSTANT_VALUE (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme.dart:37:22) Const variables must be initialized with a constant value.
- [ERROR] UNDEFINED_IDENTIFIER (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme.dart:37:22) Undefined name 'ColorSchemes'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:6:9) Undefined class 'ColorScheme'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:9:9) Undefined class 'Typography'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:18:9) Undefined class 'Density'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:21:9) Undefined class 'SpacingScale'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:24:9) Undefined class 'TrackingScale'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:27:9) Undefined class 'ShadowScale'.

## 15. validate

- Command: `/Users/ibrar/.pub-cache/bin/flutter_shadcn validate`
- Command exit code: `0`
- Command stdout: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_20260214_030044/15_validate.stdout.log`
- Command stderr: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_20260214_030044/15_validate.stderr.log`
- `dart analyze` exit code: `3`
- Analyzer totals: `ERROR=43`, `WARNING=1`, `INFO=2`

| Severity | Diagnostic Code | Count |
|---|---|---:|
| ERROR | UNDEFINED_IDENTIFIER | 13 |
| ERROR | UNDEFINED_CLASS | 9 |
| ERROR | CREATION_WITH_NON_TYPE | 6 |
| ERROR | NON_TYPE_AS_TYPE_ARGUMENT | 6 |
| ERROR | URI_DOES_NOT_EXIST | 6 |
| ERROR | UNDEFINED_METHOD | 2 |
| ERROR | CONST_INITIALIZED_WITH_NON_CONSTANT_VALUE | 1 |
| INFO | UNNECESSARY_IMPORT | 1 |
| INFO | USE_NULL_AWARE_ELEMENTS | 1 |
| WARNING | UNUSED_IMPORT | 1 |

**Top diagnostics (first 15):**
- [ERROR] UNDEFINED_METHOD (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/_impl/state/__clickable_state.dart:117:12) The method 'FocusOutline' isn't defined for the type '_ClickableState'.
- [ERROR] UNDEFINED_METHOD (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/_impl/state/__clickable_state.dart:253:26) The method 'AnimatedValueBuilder' isn't defined for the type '_ClickableState'.
- [ERROR] URI_DOES_NOT_EXIST (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/clickable.dart:8:8) Target of URI doesn't exist: 'animated_value_builder.dart'.
- [ERROR] URI_DOES_NOT_EXIST (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/clickable.dart:9:8) Target of URI doesn't exist: 'focus_outline.dart'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/component_theme_data.dart:6:9) Undefined class 'Density'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/component_theme_data.dart:9:9) Undefined class 'SpacingScale'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/component_theme_data.dart:12:9) Undefined class 'ShadowScale'.
- [ERROR] CONST_INITIALIZED_WITH_NON_CONSTANT_VALUE (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme.dart:37:22) Const variables must be initialized with a constant value.
- [ERROR] UNDEFINED_IDENTIFIER (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme.dart:37:22) Undefined name 'ColorSchemes'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:6:9) Undefined class 'ColorScheme'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:9:9) Undefined class 'Typography'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:18:9) Undefined class 'Density'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:21:9) Undefined class 'SpacingScale'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:24:9) Undefined class 'TrackingScale'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:27:9) Undefined class 'ShadowScale'.

## 16. audit

- Command: `/Users/ibrar/.pub-cache/bin/flutter_shadcn audit`
- Command exit code: `0`
- Command stdout: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_20260214_030044/16_audit.stdout.log`
- Command stderr: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_20260214_030044/16_audit.stderr.log`
- `dart analyze` exit code: `3`
- Analyzer totals: `ERROR=43`, `WARNING=1`, `INFO=2`

| Severity | Diagnostic Code | Count |
|---|---|---:|
| ERROR | UNDEFINED_IDENTIFIER | 13 |
| ERROR | UNDEFINED_CLASS | 9 |
| ERROR | CREATION_WITH_NON_TYPE | 6 |
| ERROR | NON_TYPE_AS_TYPE_ARGUMENT | 6 |
| ERROR | URI_DOES_NOT_EXIST | 6 |
| ERROR | UNDEFINED_METHOD | 2 |
| ERROR | CONST_INITIALIZED_WITH_NON_CONSTANT_VALUE | 1 |
| INFO | UNNECESSARY_IMPORT | 1 |
| INFO | USE_NULL_AWARE_ELEMENTS | 1 |
| WARNING | UNUSED_IMPORT | 1 |

**Top diagnostics (first 15):**
- [ERROR] UNDEFINED_METHOD (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/_impl/state/__clickable_state.dart:117:12) The method 'FocusOutline' isn't defined for the type '_ClickableState'.
- [ERROR] UNDEFINED_METHOD (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/_impl/state/__clickable_state.dart:253:26) The method 'AnimatedValueBuilder' isn't defined for the type '_ClickableState'.
- [ERROR] URI_DOES_NOT_EXIST (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/clickable.dart:8:8) Target of URI doesn't exist: 'animated_value_builder.dart'.
- [ERROR] URI_DOES_NOT_EXIST (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/clickable.dart:9:8) Target of URI doesn't exist: 'focus_outline.dart'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/component_theme_data.dart:6:9) Undefined class 'Density'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/component_theme_data.dart:9:9) Undefined class 'SpacingScale'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/component_theme_data.dart:12:9) Undefined class 'ShadowScale'.
- [ERROR] CONST_INITIALIZED_WITH_NON_CONSTANT_VALUE (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme.dart:37:22) Const variables must be initialized with a constant value.
- [ERROR] UNDEFINED_IDENTIFIER (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme.dart:37:22) Undefined name 'ColorSchemes'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:6:9) Undefined class 'ColorScheme'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:9:9) Undefined class 'Typography'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:18:9) Undefined class 'Density'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:21:9) Undefined class 'SpacingScale'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:24:9) Undefined class 'TrackingScale'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:27:9) Undefined class 'ShadowScale'.

## 17. deps

- Command: `/Users/ibrar/.pub-cache/bin/flutter_shadcn deps`
- Command exit code: `50`
- Command stdout: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_20260214_030044/17_deps.stdout.log`
- Command stderr: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_20260214_030044/17_deps.stderr.log`
- `dart analyze` exit code: `3`
- Analyzer totals: `ERROR=43`, `WARNING=1`, `INFO=2`

| Severity | Diagnostic Code | Count |
|---|---|---:|
| ERROR | UNDEFINED_IDENTIFIER | 13 |
| ERROR | UNDEFINED_CLASS | 9 |
| ERROR | CREATION_WITH_NON_TYPE | 6 |
| ERROR | NON_TYPE_AS_TYPE_ARGUMENT | 6 |
| ERROR | URI_DOES_NOT_EXIST | 6 |
| ERROR | UNDEFINED_METHOD | 2 |
| ERROR | CONST_INITIALIZED_WITH_NON_CONSTANT_VALUE | 1 |
| INFO | UNNECESSARY_IMPORT | 1 |
| INFO | USE_NULL_AWARE_ELEMENTS | 1 |
| WARNING | UNUSED_IMPORT | 1 |

**Top diagnostics (first 15):**
- [ERROR] UNDEFINED_METHOD (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/_impl/state/__clickable_state.dart:117:12) The method 'FocusOutline' isn't defined for the type '_ClickableState'.
- [ERROR] UNDEFINED_METHOD (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/_impl/state/__clickable_state.dart:253:26) The method 'AnimatedValueBuilder' isn't defined for the type '_ClickableState'.
- [ERROR] URI_DOES_NOT_EXIST (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/clickable.dart:8:8) Target of URI doesn't exist: 'animated_value_builder.dart'.
- [ERROR] URI_DOES_NOT_EXIST (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/clickable.dart:9:8) Target of URI doesn't exist: 'focus_outline.dart'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/component_theme_data.dart:6:9) Undefined class 'Density'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/component_theme_data.dart:9:9) Undefined class 'SpacingScale'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/component_theme_data.dart:12:9) Undefined class 'ShadowScale'.
- [ERROR] CONST_INITIALIZED_WITH_NON_CONSTANT_VALUE (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme.dart:37:22) Const variables must be initialized with a constant value.
- [ERROR] UNDEFINED_IDENTIFIER (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme.dart:37:22) Undefined name 'ColorSchemes'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:6:9) Undefined class 'ColorScheme'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:9:9) Undefined class 'Typography'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:18:9) Undefined class 'Density'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:21:9) Undefined class 'SpacingScale'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:24:9) Undefined class 'TrackingScale'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:27:9) Undefined class 'ShadowScale'.

## 18. docs

- Command: `/Users/ibrar/.pub-cache/bin/flutter_shadcn docs --generate`
- Command exit code: `0`
- Command stdout: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_20260214_030044/18_docs.stdout.log`
- Command stderr: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_20260214_030044/18_docs.stderr.log`
- `dart analyze` exit code: `3`
- Analyzer totals: `ERROR=43`, `WARNING=1`, `INFO=2`

| Severity | Diagnostic Code | Count |
|---|---|---:|
| ERROR | UNDEFINED_IDENTIFIER | 13 |
| ERROR | UNDEFINED_CLASS | 9 |
| ERROR | CREATION_WITH_NON_TYPE | 6 |
| ERROR | NON_TYPE_AS_TYPE_ARGUMENT | 6 |
| ERROR | URI_DOES_NOT_EXIST | 6 |
| ERROR | UNDEFINED_METHOD | 2 |
| ERROR | CONST_INITIALIZED_WITH_NON_CONSTANT_VALUE | 1 |
| INFO | UNNECESSARY_IMPORT | 1 |
| INFO | USE_NULL_AWARE_ELEMENTS | 1 |
| WARNING | UNUSED_IMPORT | 1 |

**Top diagnostics (first 15):**
- [ERROR] UNDEFINED_METHOD (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/_impl/state/__clickable_state.dart:117:12) The method 'FocusOutline' isn't defined for the type '_ClickableState'.
- [ERROR] UNDEFINED_METHOD (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/_impl/state/__clickable_state.dart:253:26) The method 'AnimatedValueBuilder' isn't defined for the type '_ClickableState'.
- [ERROR] URI_DOES_NOT_EXIST (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/clickable.dart:8:8) Target of URI doesn't exist: 'animated_value_builder.dart'.
- [ERROR] URI_DOES_NOT_EXIST (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/clickable.dart:9:8) Target of URI doesn't exist: 'focus_outline.dart'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/component_theme_data.dart:6:9) Undefined class 'Density'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/component_theme_data.dart:9:9) Undefined class 'SpacingScale'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/component_theme_data.dart:12:9) Undefined class 'ShadowScale'.
- [ERROR] CONST_INITIALIZED_WITH_NON_CONSTANT_VALUE (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme.dart:37:22) Const variables must be initialized with a constant value.
- [ERROR] UNDEFINED_IDENTIFIER (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme.dart:37:22) Undefined name 'ColorSchemes'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:6:9) Undefined class 'ColorScheme'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:9:9) Undefined class 'Typography'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:18:9) Undefined class 'Density'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:21:9) Undefined class 'SpacingScale'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:24:9) Undefined class 'TrackingScale'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:27:9) Undefined class 'ShadowScale'.

## 19. install_skill

- Command: `/Users/ibrar/.pub-cache/bin/flutter_shadcn install-skill --available`
- Command exit code: `0`
- Command stdout: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_20260214_030044/19_install_skill.stdout.log`
- Command stderr: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_20260214_030044/19_install_skill.stderr.log`
- `dart analyze` exit code: `3`
- Analyzer totals: `ERROR=43`, `WARNING=1`, `INFO=2`

| Severity | Diagnostic Code | Count |
|---|---|---:|
| ERROR | UNDEFINED_IDENTIFIER | 13 |
| ERROR | UNDEFINED_CLASS | 9 |
| ERROR | CREATION_WITH_NON_TYPE | 6 |
| ERROR | NON_TYPE_AS_TYPE_ARGUMENT | 6 |
| ERROR | URI_DOES_NOT_EXIST | 6 |
| ERROR | UNDEFINED_METHOD | 2 |
| ERROR | CONST_INITIALIZED_WITH_NON_CONSTANT_VALUE | 1 |
| INFO | UNNECESSARY_IMPORT | 1 |
| INFO | USE_NULL_AWARE_ELEMENTS | 1 |
| WARNING | UNUSED_IMPORT | 1 |

**Top diagnostics (first 15):**
- [ERROR] UNDEFINED_METHOD (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/_impl/state/__clickable_state.dart:117:12) The method 'FocusOutline' isn't defined for the type '_ClickableState'.
- [ERROR] UNDEFINED_METHOD (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/_impl/state/__clickable_state.dart:253:26) The method 'AnimatedValueBuilder' isn't defined for the type '_ClickableState'.
- [ERROR] URI_DOES_NOT_EXIST (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/clickable.dart:8:8) Target of URI doesn't exist: 'animated_value_builder.dart'.
- [ERROR] URI_DOES_NOT_EXIST (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/clickable.dart:9:8) Target of URI doesn't exist: 'focus_outline.dart'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/component_theme_data.dart:6:9) Undefined class 'Density'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/component_theme_data.dart:9:9) Undefined class 'SpacingScale'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/component_theme_data.dart:12:9) Undefined class 'ShadowScale'.
- [ERROR] CONST_INITIALIZED_WITH_NON_CONSTANT_VALUE (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme.dart:37:22) Const variables must be initialized with a constant value.
- [ERROR] UNDEFINED_IDENTIFIER (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme.dart:37:22) Undefined name 'ColorSchemes'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:6:9) Undefined class 'ColorScheme'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:9:9) Undefined class 'Typography'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:18:9) Undefined class 'Density'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:21:9) Undefined class 'SpacingScale'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:24:9) Undefined class 'TrackingScale'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:27:9) Undefined class 'ShadowScale'.

## 20. version

- Command: `/Users/ibrar/.pub-cache/bin/flutter_shadcn version --check`
- Command exit code: `0`
- Command stdout: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_20260214_030044/20_version.stdout.log`
- Command stderr: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_20260214_030044/20_version.stderr.log`
- `dart analyze` exit code: `3`
- Analyzer totals: `ERROR=43`, `WARNING=1`, `INFO=2`

| Severity | Diagnostic Code | Count |
|---|---|---:|
| ERROR | UNDEFINED_IDENTIFIER | 13 |
| ERROR | UNDEFINED_CLASS | 9 |
| ERROR | CREATION_WITH_NON_TYPE | 6 |
| ERROR | NON_TYPE_AS_TYPE_ARGUMENT | 6 |
| ERROR | URI_DOES_NOT_EXIST | 6 |
| ERROR | UNDEFINED_METHOD | 2 |
| ERROR | CONST_INITIALIZED_WITH_NON_CONSTANT_VALUE | 1 |
| INFO | UNNECESSARY_IMPORT | 1 |
| INFO | USE_NULL_AWARE_ELEMENTS | 1 |
| WARNING | UNUSED_IMPORT | 1 |

**Top diagnostics (first 15):**
- [ERROR] UNDEFINED_METHOD (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/_impl/state/__clickable_state.dart:117:12) The method 'FocusOutline' isn't defined for the type '_ClickableState'.
- [ERROR] UNDEFINED_METHOD (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/_impl/state/__clickable_state.dart:253:26) The method 'AnimatedValueBuilder' isn't defined for the type '_ClickableState'.
- [ERROR] URI_DOES_NOT_EXIST (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/clickable.dart:8:8) Target of URI doesn't exist: 'animated_value_builder.dart'.
- [ERROR] URI_DOES_NOT_EXIST (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/clickable.dart:9:8) Target of URI doesn't exist: 'focus_outline.dart'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/component_theme_data.dart:6:9) Undefined class 'Density'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/component_theme_data.dart:9:9) Undefined class 'SpacingScale'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/component_theme_data.dart:12:9) Undefined class 'ShadowScale'.
- [ERROR] CONST_INITIALIZED_WITH_NON_CONSTANT_VALUE (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme.dart:37:22) Const variables must be initialized with a constant value.
- [ERROR] UNDEFINED_IDENTIFIER (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme.dart:37:22) Undefined name 'ColorSchemes'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:6:9) Undefined class 'ColorScheme'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:9:9) Undefined class 'Typography'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:18:9) Undefined class 'Density'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:21:9) Undefined class 'SpacingScale'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:24:9) Undefined class 'TrackingScale'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:27:9) Undefined class 'ShadowScale'.

## 21. doctor

- Command: `/Users/ibrar/.pub-cache/bin/flutter_shadcn doctor`
- Command exit code: `60`
- Command stdout: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_20260214_030044/21_doctor.stdout.log`
- Command stderr: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_20260214_030044/21_doctor.stderr.log`
- `dart analyze` exit code: `3`
- Analyzer totals: `ERROR=43`, `WARNING=1`, `INFO=2`

| Severity | Diagnostic Code | Count |
|---|---|---:|
| ERROR | UNDEFINED_IDENTIFIER | 13 |
| ERROR | UNDEFINED_CLASS | 9 |
| ERROR | CREATION_WITH_NON_TYPE | 6 |
| ERROR | NON_TYPE_AS_TYPE_ARGUMENT | 6 |
| ERROR | URI_DOES_NOT_EXIST | 6 |
| ERROR | UNDEFINED_METHOD | 2 |
| ERROR | CONST_INITIALIZED_WITH_NON_CONSTANT_VALUE | 1 |
| INFO | UNNECESSARY_IMPORT | 1 |
| INFO | USE_NULL_AWARE_ELEMENTS | 1 |
| WARNING | UNUSED_IMPORT | 1 |

**Top diagnostics (first 15):**
- [ERROR] UNDEFINED_METHOD (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/_impl/state/__clickable_state.dart:117:12) The method 'FocusOutline' isn't defined for the type '_ClickableState'.
- [ERROR] UNDEFINED_METHOD (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/_impl/state/__clickable_state.dart:253:26) The method 'AnimatedValueBuilder' isn't defined for the type '_ClickableState'.
- [ERROR] URI_DOES_NOT_EXIST (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/clickable.dart:8:8) Target of URI doesn't exist: 'animated_value_builder.dart'.
- [ERROR] URI_DOES_NOT_EXIST (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/clickable.dart:9:8) Target of URI doesn't exist: 'focus_outline.dart'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/component_theme_data.dart:6:9) Undefined class 'Density'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/component_theme_data.dart:9:9) Undefined class 'SpacingScale'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/component_theme_data.dart:12:9) Undefined class 'ShadowScale'.
- [ERROR] CONST_INITIALIZED_WITH_NON_CONSTANT_VALUE (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme.dart:37:22) Const variables must be initialized with a constant value.
- [ERROR] UNDEFINED_IDENTIFIER (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme.dart:37:22) Undefined name 'ColorSchemes'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:6:9) Undefined class 'ColorScheme'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:9:9) Undefined class 'Typography'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:18:9) Undefined class 'Density'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:21:9) Undefined class 'SpacingScale'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:24:9) Undefined class 'TrackingScale'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:27:9) Undefined class 'ShadowScale'.

## 22. feedback

- Command: `/Users/ibrar/.pub-cache/bin/flutter_shadcn feedback --type invalid --title 'Smoke test' --body 'Command smoke test'`
- Command exit code: `0`
- Command stdout: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_20260214_030044/22_feedback.stdout.log`
- Command stderr: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_20260214_030044/22_feedback.stderr.log`
- `dart analyze` exit code: `3`
- Analyzer totals: `ERROR=43`, `WARNING=1`, `INFO=2`

| Severity | Diagnostic Code | Count |
|---|---|---:|
| ERROR | UNDEFINED_IDENTIFIER | 13 |
| ERROR | UNDEFINED_CLASS | 9 |
| ERROR | CREATION_WITH_NON_TYPE | 6 |
| ERROR | NON_TYPE_AS_TYPE_ARGUMENT | 6 |
| ERROR | URI_DOES_NOT_EXIST | 6 |
| ERROR | UNDEFINED_METHOD | 2 |
| ERROR | CONST_INITIALIZED_WITH_NON_CONSTANT_VALUE | 1 |
| INFO | UNNECESSARY_IMPORT | 1 |
| INFO | USE_NULL_AWARE_ELEMENTS | 1 |
| WARNING | UNUSED_IMPORT | 1 |

**Top diagnostics (first 15):**
- [ERROR] UNDEFINED_METHOD (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/_impl/state/__clickable_state.dart:117:12) The method 'FocusOutline' isn't defined for the type '_ClickableState'.
- [ERROR] UNDEFINED_METHOD (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/_impl/state/__clickable_state.dart:253:26) The method 'AnimatedValueBuilder' isn't defined for the type '_ClickableState'.
- [ERROR] URI_DOES_NOT_EXIST (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/clickable.dart:8:8) Target of URI doesn't exist: 'animated_value_builder.dart'.
- [ERROR] URI_DOES_NOT_EXIST (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/clickable.dart:9:8) Target of URI doesn't exist: 'focus_outline.dart'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/component_theme_data.dart:6:9) Undefined class 'Density'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/component_theme_data.dart:9:9) Undefined class 'SpacingScale'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/component_theme_data.dart:12:9) Undefined class 'ShadowScale'.
- [ERROR] CONST_INITIALIZED_WITH_NON_CONSTANT_VALUE (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme.dart:37:22) Const variables must be initialized with a constant value.
- [ERROR] UNDEFINED_IDENTIFIER (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme.dart:37:22) Undefined name 'ColorSchemes'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:6:9) Undefined class 'ColorScheme'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:9:9) Undefined class 'Typography'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:18:9) Undefined class 'Density'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:21:9) Undefined class 'SpacingScale'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:24:9) Undefined class 'TrackingScale'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:27:9) Undefined class 'ShadowScale'.

## 23. upgrade

- Command: `/Users/ibrar/.pub-cache/bin/flutter_shadcn upgrade`
- Command exit code: `0`
- Command stdout: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_20260214_030044/23_upgrade.stdout.log`
- Command stderr: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_20260214_030044/23_upgrade.stderr.log`
- `dart analyze` exit code: `3`
- Analyzer totals: `ERROR=43`, `WARNING=1`, `INFO=2`

| Severity | Diagnostic Code | Count |
|---|---|---:|
| ERROR | UNDEFINED_IDENTIFIER | 13 |
| ERROR | UNDEFINED_CLASS | 9 |
| ERROR | CREATION_WITH_NON_TYPE | 6 |
| ERROR | NON_TYPE_AS_TYPE_ARGUMENT | 6 |
| ERROR | URI_DOES_NOT_EXIST | 6 |
| ERROR | UNDEFINED_METHOD | 2 |
| ERROR | CONST_INITIALIZED_WITH_NON_CONSTANT_VALUE | 1 |
| INFO | UNNECESSARY_IMPORT | 1 |
| INFO | USE_NULL_AWARE_ELEMENTS | 1 |
| WARNING | UNUSED_IMPORT | 1 |

**Top diagnostics (first 15):**
- [ERROR] UNDEFINED_METHOD (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/_impl/state/__clickable_state.dart:117:12) The method 'FocusOutline' isn't defined for the type '_ClickableState'.
- [ERROR] UNDEFINED_METHOD (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/_impl/state/__clickable_state.dart:253:26) The method 'AnimatedValueBuilder' isn't defined for the type '_ClickableState'.
- [ERROR] URI_DOES_NOT_EXIST (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/clickable.dart:8:8) Target of URI doesn't exist: 'animated_value_builder.dart'.
- [ERROR] URI_DOES_NOT_EXIST (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/clickable.dart:9:8) Target of URI doesn't exist: 'focus_outline.dart'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/component_theme_data.dart:6:9) Undefined class 'Density'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/component_theme_data.dart:9:9) Undefined class 'SpacingScale'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/component_theme_data.dart:12:9) Undefined class 'ShadowScale'.
- [ERROR] CONST_INITIALIZED_WITH_NON_CONSTANT_VALUE (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme.dart:37:22) Const variables must be initialized with a constant value.
- [ERROR] UNDEFINED_IDENTIFIER (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme.dart:37:22) Undefined name 'ColorSchemes'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:6:9) Undefined class 'ColorScheme'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:9:9) Undefined class 'Typography'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:18:9) Undefined class 'Density'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:21:9) Undefined class 'SpacingScale'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:24:9) Undefined class 'TrackingScale'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme_data.dart:27:9) Undefined class 'ShadowScale'.

## Summary

| # | Command | Cmd Exit | Analyze Exit | Errors | Warnings | Infos |
|---:|---|---:|---:|---:|---:|---:|
| 1 | install_cli | 0 | 0 | 0 | 0 | 0 |
| 2 | init | 0 | 3 | 46 | 0 | 5 |
| 3 | theme | 0 | 3 | 46 | 0 | 5 |
| 4 | add | 0 | 3 | 86 | 69 | 3 |
| 5 | dry_run | 30 | 3 | 58 | 73 | 3 |
| 6 | remove | 0 | 3 | 58 | 0 | 7 |
| 7 | sync | 0 | 3 | 58 | 0 | 2 |
| 8 | assets | 255 | 3 | 43 | 1 | 2 |
| 9 | platform | 0 | 3 | 43 | 1 | 2 |
| 10 | registries | 0 | 3 | 43 | 1 | 2 |
| 11 | default | 0 | 3 | 43 | 1 | 2 |
| 12 | list | 0 | 3 | 43 | 1 | 2 |
| 13 | search | 0 | 3 | 43 | 1 | 2 |
| 14 | info | 0 | 3 | 43 | 1 | 2 |
| 15 | validate | 0 | 3 | 43 | 1 | 2 |
| 16 | audit | 0 | 3 | 43 | 1 | 2 |
| 17 | deps | 50 | 3 | 43 | 1 | 2 |
| 18 | docs | 0 | 3 | 43 | 1 | 2 |
| 19 | install_skill | 0 | 3 | 43 | 1 | 2 |
| 20 | version | 0 | 3 | 43 | 1 | 2 |
| 21 | doctor | 60 | 3 | 43 | 1 | 2 |
| 22 | feedback | 0 | 3 | 43 | 1 | 2 |
| 23 | upgrade | 0 | 3 | 43 | 1 | 2 |

### Recurring analyzer categories across all steps

| Severity | Diagnostic Code | Occurrences |
|---|---|---:|
| ERROR | UNDEFINED_IDENTIFIER | 328 |
| ERROR | UNDEFINED_CLASS | 203 |
| ERROR | URI_DOES_NOT_EXIST | 166 |
| WARNING | UNUSED_IMPORT | 158 |
| ERROR | CREATION_WITH_NON_TYPE | 138 |
| ERROR | NON_TYPE_AS_TYPE_ARGUMENT | 132 |
| ERROR | UNDEFINED_METHOD | 46 |
| INFO | UNNECESSARY_IMPORT | 24 |
| ERROR | CONST_INITIALIZED_WITH_NON_CONSTANT_VALUE | 22 |
| INFO | USE_NULL_AWARE_ELEMENTS | 20 |
| INFO | DEPEND_ON_REFERENCED_PACKAGES | 13 |
| ERROR | UNDEFINED_FUNCTION | 5 |
