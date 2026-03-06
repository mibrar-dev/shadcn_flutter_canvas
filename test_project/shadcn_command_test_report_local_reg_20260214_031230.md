# flutter_shadcn Command Test Report (Local registries.json)

- Project: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project`
- CLI source: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/shadcn_flutter_cli`
- Local registries file: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/registry-directory/registries/registries.json`
- Served as: `http://127.0.0.1:18765/registries.json`
- Generated at: `2026-02-14T03:12:31Z`
- Raw logs: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_reg_20260214_031230`

This report runs install + each top-level CLI command one by one. Every CLI command is forced to use the local registries file via `--registries-url`. After each command, `dart analyze --format machine` is executed and categorized.

## 01. install_cli

- Command: `dart pub global activate --source path '/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/shadcn_flutter_cli'`
- Command exit code: `0`
- Command stdout: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_reg_20260214_031230/1_install_cli.stdout.log`
- Command stderr: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_reg_20260214_031230/1_install_cli.stderr.log`
- `dart analyze` exit code: `0`
- Analyzer totals: `ERROR=0`, `WARNING=0`, `INFO=0`

| Severity | Diagnostic Code | Count |
|---|---|---:|

**Top diagnostics (first 15):**

## 02. init

- Command: `/Users/ibrar/.pub-cache/bin/flutter_shadcn --registries-url 'http://127.0.0.1:18765/registries.json' init --yes --install-icons --install-fonts`
- Command exit code: `0`
- Command stdout: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_reg_20260214_031230/2_init.stdout.log`
- Command stderr: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_reg_20260214_031230/2_init.stderr.log`
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

- Command: `/Users/ibrar/.pub-cache/bin/flutter_shadcn --registries-url 'http://127.0.0.1:18765/registries.json' theme --list`
- Command exit code: `0`
- Command stdout: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_reg_20260214_031230/3_theme.stdout.log`
- Command stderr: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_reg_20260214_031230/3_theme.stderr.log`
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

- Command: `/Users/ibrar/.pub-cache/bin/flutter_shadcn --registries-url 'http://127.0.0.1:18765/registries.json' add @shadcn/button`
- Command exit code: `0`
- Command stdout: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_reg_20260214_031230/4_add.stdout.log`
- Command stderr: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_reg_20260214_031230/4_add.stderr.log`
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

- Command: `/Users/ibrar/.pub-cache/bin/flutter_shadcn --registries-url 'http://127.0.0.1:18765/registries.json' dry-run @shadcn/button`
- Command exit code: `30`
- Command stdout: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_reg_20260214_031230/5_dry_run.stdout.log`
- Command stderr: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_reg_20260214_031230/5_dry_run.stderr.log`
- `dart analyze` exit code: `3`
- Analyzer totals: `ERROR=58`, `WARNING=72`, `INFO=3`

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
| WARNING | UNUSED_IMPORT | 72 |

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

- Command: `/Users/ibrar/.pub-cache/bin/flutter_shadcn --registries-url 'http://127.0.0.1:18765/registries.json' remove @shadcn/button --force`
- Command exit code: `0`
- Command stdout: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_reg_20260214_031230/6_remove.stdout.log`
- Command stderr: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_reg_20260214_031230/6_remove.stderr.log`
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

- Command: `/Users/ibrar/.pub-cache/bin/flutter_shadcn --registries-url 'http://127.0.0.1:18765/registries.json' sync`
- Command exit code: `0`
- Command stdout: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_reg_20260214_031230/7_sync.stdout.log`
- Command stderr: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_reg_20260214_031230/7_sync.stderr.log`
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

- Command: `/Users/ibrar/.pub-cache/bin/flutter_shadcn --registries-url 'http://127.0.0.1:18765/registries.json' assets --icons`
- Command exit code: `255`
- Command stdout: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_reg_20260214_031230/8_assets.stdout.log`
- Command stderr: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_reg_20260214_031230/8_assets.stderr.log`
- `dart analyze` exit code: `3`
- Analyzer totals: `ERROR=86`, `WARNING=2`, `INFO=4`

| Severity | Diagnostic Code | Count |
|---|---|---:|
| ERROR | UNDEFINED_IDENTIFIER | 26 |
| ERROR | UNDEFINED_CLASS | 18 |
| ERROR | CREATION_WITH_NON_TYPE | 12 |
| ERROR | NON_TYPE_AS_TYPE_ARGUMENT | 12 |
| ERROR | URI_DOES_NOT_EXIST | 12 |
| ERROR | UNDEFINED_METHOD | 4 |
| ERROR | CONST_INITIALIZED_WITH_NON_CONSTANT_VALUE | 2 |
| INFO | UNNECESSARY_IMPORT | 2 |
| INFO | USE_NULL_AWARE_ELEMENTS | 2 |
| WARNING | UNUSED_IMPORT | 2 |

**Top diagnostics (first 15):**
- [ERROR] UNDEFINED_METHOD (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/_impl/state/__clickable_state.dart:117:12) The method 'FocusOutline' isn't defined for the type '_ClickableState'.
- [ERROR] UNDEFINED_METHOD (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/_impl/state/__clickable_state.dart:117:12) The method 'FocusOutline' isn't defined for the type '_ClickableState'.
- [ERROR] UNDEFINED_METHOD (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/_impl/state/__clickable_state.dart:253:26) The method 'AnimatedValueBuilder' isn't defined for the type '_ClickableState'.
- [ERROR] UNDEFINED_METHOD (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/_impl/state/__clickable_state.dart:253:26) The method 'AnimatedValueBuilder' isn't defined for the type '_ClickableState'.
- [ERROR] URI_DOES_NOT_EXIST (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/clickable.dart:8:8) Target of URI doesn't exist: 'animated_value_builder.dart'.
- [ERROR] URI_DOES_NOT_EXIST (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/clickable.dart:8:8) Target of URI doesn't exist: 'animated_value_builder.dart'.
- [ERROR] URI_DOES_NOT_EXIST (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/clickable.dart:9:8) Target of URI doesn't exist: 'focus_outline.dart'.
- [ERROR] URI_DOES_NOT_EXIST (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/primitives/clickable.dart:9:8) Target of URI doesn't exist: 'focus_outline.dart'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/component_theme_data.dart:6:9) Undefined class 'Density'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/component_theme_data.dart:6:9) Undefined class 'Density'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/component_theme_data.dart:9:9) Undefined class 'SpacingScale'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/component_theme_data.dart:9:9) Undefined class 'SpacingScale'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/component_theme_data.dart:12:9) Undefined class 'ShadowScale'.
- [ERROR] UNDEFINED_CLASS (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/component_theme_data.dart:12:9) Undefined class 'ShadowScale'.
- [ERROR] CONST_INITIALIZED_WITH_NON_CONSTANT_VALUE (/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/lib/ui/shadcn/shared/theme/_impl/themes/theme.dart:37:22) Const variables must be initialized with a constant value.

## 09. platform

- Command: `/Users/ibrar/.pub-cache/bin/flutter_shadcn --registries-url 'http://127.0.0.1:18765/registries.json' platform --list`
- Command exit code: `0`
- Command stdout: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_reg_20260214_031230/9_platform.stdout.log`
- Command stderr: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_reg_20260214_031230/9_platform.stderr.log`
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

- Command: `/Users/ibrar/.pub-cache/bin/flutter_shadcn --registries-url 'http://127.0.0.1:18765/registries.json' registries`
- Command exit code: `0`
- Command stdout: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_reg_20260214_031230/10_registries.stdout.log`
- Command stderr: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_reg_20260214_031230/10_registries.stderr.log`
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

- Command: `/Users/ibrar/.pub-cache/bin/flutter_shadcn --registries-url 'http://127.0.0.1:18765/registries.json' default`
- Command exit code: `0`
- Command stdout: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_reg_20260214_031230/11_default.stdout.log`
- Command stderr: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_reg_20260214_031230/11_default.stderr.log`
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

- Command: `/Users/ibrar/.pub-cache/bin/flutter_shadcn --registries-url 'http://127.0.0.1:18765/registries.json' list`
- Command exit code: `0`
- Command stdout: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_reg_20260214_031230/12_list.stdout.log`
- Command stderr: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_reg_20260214_031230/12_list.stderr.log`
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

- Command: `/Users/ibrar/.pub-cache/bin/flutter_shadcn --registries-url 'http://127.0.0.1:18765/registries.json' search button`
- Command exit code: `0`
- Command stdout: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_reg_20260214_031230/13_search.stdout.log`
- Command stderr: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_reg_20260214_031230/13_search.stderr.log`
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

- Command: `/Users/ibrar/.pub-cache/bin/flutter_shadcn --registries-url 'http://127.0.0.1:18765/registries.json' info @shadcn/button`
- Command exit code: `0`
- Command stdout: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_reg_20260214_031230/14_info.stdout.log`
- Command stderr: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_reg_20260214_031230/14_info.stderr.log`
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

- Command: `/Users/ibrar/.pub-cache/bin/flutter_shadcn --registries-url 'http://127.0.0.1:18765/registries.json' validate`
- Command exit code: `0`
- Command stdout: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_reg_20260214_031230/15_validate.stdout.log`
- Command stderr: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_reg_20260214_031230/15_validate.stderr.log`
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

- Command: `/Users/ibrar/.pub-cache/bin/flutter_shadcn --registries-url 'http://127.0.0.1:18765/registries.json' audit`
- Command exit code: `0`
- Command stdout: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_reg_20260214_031230/16_audit.stdout.log`
- Command stderr: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_reg_20260214_031230/16_audit.stderr.log`
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

- Command: `/Users/ibrar/.pub-cache/bin/flutter_shadcn --registries-url 'http://127.0.0.1:18765/registries.json' deps`
- Command exit code: `50`
- Command stdout: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_reg_20260214_031230/17_deps.stdout.log`
- Command stderr: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_reg_20260214_031230/17_deps.stderr.log`
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

- Command: `/Users/ibrar/.pub-cache/bin/flutter_shadcn --registries-url 'http://127.0.0.1:18765/registries.json' docs --generate`
- Command exit code: `0`
- Command stdout: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_reg_20260214_031230/18_docs.stdout.log`
- Command stderr: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_reg_20260214_031230/18_docs.stderr.log`
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

- Command: `/Users/ibrar/.pub-cache/bin/flutter_shadcn --registries-url 'http://127.0.0.1:18765/registries.json' install-skill --available`
- Command exit code: `0`
- Command stdout: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_reg_20260214_031230/19_install_skill.stdout.log`
- Command stderr: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_reg_20260214_031230/19_install_skill.stderr.log`
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

- Command: `/Users/ibrar/.pub-cache/bin/flutter_shadcn --registries-url 'http://127.0.0.1:18765/registries.json' version --check`
- Command exit code: `0`
- Command stdout: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_reg_20260214_031230/20_version.stdout.log`
- Command stderr: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_reg_20260214_031230/20_version.stderr.log`
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

- Command: `/Users/ibrar/.pub-cache/bin/flutter_shadcn --registries-url 'http://127.0.0.1:18765/registries.json' doctor`
- Command exit code: `60`
- Command stdout: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_reg_20260214_031230/21_doctor.stdout.log`
- Command stderr: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_reg_20260214_031230/21_doctor.stderr.log`
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

- Command: `/Users/ibrar/.pub-cache/bin/flutter_shadcn --registries-url 'http://127.0.0.1:18765/registries.json' feedback --type invalid --title 'Smoke test' --body 'Command smoke test'`
- Command exit code: `0`
- Command stdout: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_reg_20260214_031230/22_feedback.stdout.log`
- Command stderr: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_reg_20260214_031230/22_feedback.stderr.log`
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

- Command: `/Users/ibrar/.pub-cache/bin/flutter_shadcn --registries-url 'http://127.0.0.1:18765/registries.json' upgrade`
- Command exit code: `0`
- Command stdout: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_reg_20260214_031230/23_upgrade.stdout.log`
- Command stderr: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_reg_20260214_031230/23_upgrade.stderr.log`
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
| 5 | dry_run | 30 | 3 | 58 | 72 | 3 |
| 6 | remove | 0 | 3 | 58 | 0 | 7 |
| 7 | sync | 0 | 3 | 58 | 0 | 2 |
| 8 | assets | 255 | 3 | 86 | 2 | 4 |
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
| ERROR | UNDEFINED_IDENTIFIER | 341 |
| ERROR | UNDEFINED_CLASS | 212 |
| ERROR | URI_DOES_NOT_EXIST | 172 |
| WARNING | UNUSED_IMPORT | 158 |
| ERROR | CREATION_WITH_NON_TYPE | 144 |
| ERROR | NON_TYPE_AS_TYPE_ARGUMENT | 138 |
| ERROR | UNDEFINED_METHOD | 48 |
| INFO | UNNECESSARY_IMPORT | 25 |
| ERROR | CONST_INITIALIZED_WITH_NON_CONSTANT_VALUE | 23 |
| INFO | USE_NULL_AWARE_ELEMENTS | 21 |
| INFO | DEPEND_ON_REFERENCED_PACKAGES | 13 |
| ERROR | UNDEFINED_FUNCTION | 5 |
