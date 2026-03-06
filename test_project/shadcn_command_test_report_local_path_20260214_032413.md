# flutter_shadcn Command Test Report (Local registries path)

- Project: /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project
- CLI source: /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/shadcn_flutter_cli
- Local registries path: /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/registry-directory/registries/registries.json
- Generated at: 2026-02-14T03:24:13Z
- Raw logs: /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_path_20260214_032413

This report runs top-level CLI commands using the local registries file via --registries-path.

## 0. install_cli

- Command: dart pub global activate --source path '/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/shadcn_flutter_cli'
- Command exit code: 0
- Command stdout: /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_path_20260214_032413/0_install_cli.stdout.log
- Command stderr: /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_path_20260214_032413/0_install_cli.stderr.log

## 1. init

- Command: dart /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/shadcn_flutter_cli/bin/shadcn.dart --registries-path '/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/registry-directory/registries/registries.json' init --yes --install-icons --install-fonts
- Command exit code: 0
- Command stdout: /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_path_20260214_032413/1_init.stdout.log
- Command stderr: /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_path_20260214_032413/1_init.stderr.log
- dart analyze exit code: 3
- Analyzer log: /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_path_20260214_032413/analyze_1_init.log

## 2. theme

- Command: dart /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/shadcn_flutter_cli/bin/shadcn.dart --registries-path '/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/registry-directory/registries/registries.json' theme --list
- Command exit code: 0
- Command stdout: /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_path_20260214_032413/2_theme.stdout.log
- Command stderr: /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_path_20260214_032413/2_theme.stderr.log
- dart analyze exit code: 3
- Analyzer log: /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_path_20260214_032413/analyze_2_theme.log

## 3. add

- Command: dart /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/shadcn_flutter_cli/bin/shadcn.dart --registries-path '/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/registry-directory/registries/registries.json' add @shadcn/button
- Command exit code: 255
- Command stdout: /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_path_20260214_032413/3_add.stdout.log
- Command stderr: /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_path_20260214_032413/3_add.stderr.log
- dart analyze exit code: 3
- Analyzer log: /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_path_20260214_032413/analyze_3_add.log

## 4. dry_run

- Command: dart /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/shadcn_flutter_cli/bin/shadcn.dart --registries-path '/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/registry-directory/registries/registries.json' dry-run @shadcn/button
- Command exit code: 30
- Command stdout: /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_path_20260214_032413/4_dry_run.stdout.log
- Command stderr: /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_path_20260214_032413/4_dry_run.stderr.log
- dart analyze exit code: 3
- Analyzer log: /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_path_20260214_032413/analyze_4_dry_run.log

## 5. remove

- Command: dart /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/shadcn_flutter_cli/bin/shadcn.dart --registries-path '/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/registry-directory/registries/registries.json' remove @shadcn/button --force
- Command exit code: 0
- Command stdout: /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_path_20260214_032413/5_remove.stdout.log
- Command stderr: /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_path_20260214_032413/5_remove.stderr.log
- dart analyze exit code: 3
- Analyzer log: /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_path_20260214_032413/analyze_5_remove.log

## 6. sync

- Command: dart /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/shadcn_flutter_cli/bin/shadcn.dart --registries-path '/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/registry-directory/registries/registries.json' sync
- Command exit code: 0
- Command stdout: /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_path_20260214_032413/6_sync.stdout.log
- Command stderr: /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_path_20260214_032413/6_sync.stderr.log
- dart analyze exit code: 3
- Analyzer log: /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_path_20260214_032413/analyze_6_sync.log

## 7. assets

- Command: dart /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/shadcn_flutter_cli/bin/shadcn.dart --registries-path '/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/registry-directory/registries/registries.json' assets --icons
- Command exit code: 255
- Command stdout: /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_path_20260214_032413/7_assets.stdout.log
- Command stderr: /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_path_20260214_032413/7_assets.stderr.log
- dart analyze exit code: 3
- Analyzer log: /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_path_20260214_032413/analyze_7_assets.log

## 8. platform

- Command: dart /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/shadcn_flutter_cli/bin/shadcn.dart --registries-path '/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/registry-directory/registries/registries.json' platform --list
- Command exit code: 0
- Command stdout: /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_path_20260214_032413/8_platform.stdout.log
- Command stderr: /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_path_20260214_032413/8_platform.stderr.log
- dart analyze exit code: 3
- Analyzer log: /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_path_20260214_032413/analyze_8_platform.log

## 9. registries

- Command: dart /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/shadcn_flutter_cli/bin/shadcn.dart --registries-path '/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/registry-directory/registries/registries.json' registries
- Command exit code: 0
- Command stdout: /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_path_20260214_032413/9_registries.stdout.log
- Command stderr: /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_path_20260214_032413/9_registries.stderr.log
- dart analyze exit code: 3
- Analyzer log: /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_path_20260214_032413/analyze_9_registries.log

## 10. default

- Command: dart /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/shadcn_flutter_cli/bin/shadcn.dart --registries-path '/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/registry-directory/registries/registries.json' default
- Command exit code: 0
- Command stdout: /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_path_20260214_032413/10_default.stdout.log
- Command stderr: /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_path_20260214_032413/10_default.stderr.log
- dart analyze exit code: 3
- Analyzer log: /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_path_20260214_032413/analyze_10_default.log

## 11. list

- Command: dart /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/shadcn_flutter_cli/bin/shadcn.dart --registries-path '/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/registry-directory/registries/registries.json' list
- Command exit code: 0
- Command stdout: /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_path_20260214_032413/11_list.stdout.log
- Command stderr: /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_path_20260214_032413/11_list.stderr.log
- dart analyze exit code: 3
- Analyzer log: /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_path_20260214_032413/analyze_11_list.log

## 12. search

- Command: dart /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/shadcn_flutter_cli/bin/shadcn.dart --registries-path '/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/registry-directory/registries/registries.json' search button
- Command exit code: 0
- Command stdout: /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_path_20260214_032413/12_search.stdout.log
- Command stderr: /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_path_20260214_032413/12_search.stderr.log
- dart analyze exit code: 3
- Analyzer log: /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_path_20260214_032413/analyze_12_search.log

## 13. info

- Command: dart /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/shadcn_flutter_cli/bin/shadcn.dart --registries-path '/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/registry-directory/registries/registries.json' info @shadcn/button
- Command exit code: 0
- Command stdout: /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_path_20260214_032413/13_info.stdout.log
- Command stderr: /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_path_20260214_032413/13_info.stderr.log
- dart analyze exit code: 3
- Analyzer log: /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_path_20260214_032413/analyze_13_info.log

## 14. validate

- Command: dart /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/shadcn_flutter_cli/bin/shadcn.dart --registries-path '/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/registry-directory/registries/registries.json' validate
- Command exit code: 0
- Command stdout: /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_path_20260214_032413/14_validate.stdout.log
- Command stderr: /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_path_20260214_032413/14_validate.stderr.log
- dart analyze exit code: 3
- Analyzer log: /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_path_20260214_032413/analyze_14_validate.log

## 15. audit

- Command: dart /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/shadcn_flutter_cli/bin/shadcn.dart --registries-path '/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/registry-directory/registries/registries.json' audit
- Command exit code: 0
- Command stdout: /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_path_20260214_032413/15_audit.stdout.log
- Command stderr: /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_path_20260214_032413/15_audit.stderr.log
- dart analyze exit code: 3
- Analyzer log: /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_path_20260214_032413/analyze_15_audit.log

## 16. deps

- Command: dart /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/shadcn_flutter_cli/bin/shadcn.dart --registries-path '/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/registry-directory/registries/registries.json' deps
- Command exit code: 50
- Command stdout: /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_path_20260214_032413/16_deps.stdout.log
- Command stderr: /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_path_20260214_032413/16_deps.stderr.log
- dart analyze exit code: 3
- Analyzer log: /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_path_20260214_032413/analyze_16_deps.log

## 17. docs

- Command: dart /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/shadcn_flutter_cli/bin/shadcn.dart --registries-path '/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/registry-directory/registries/registries.json' docs --generate
- Command exit code: 0
- Command stdout: /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_path_20260214_032413/17_docs.stdout.log
- Command stderr: /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_path_20260214_032413/17_docs.stderr.log
- dart analyze exit code: 3
- Analyzer log: /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_path_20260214_032413/analyze_17_docs.log

## 18. install_skill

- Command: dart /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/shadcn_flutter_cli/bin/shadcn.dart --registries-path '/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/registry-directory/registries/registries.json' install-skill --available
- Command exit code: 0
- Command stdout: /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_path_20260214_032413/18_install_skill.stdout.log
- Command stderr: /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_path_20260214_032413/18_install_skill.stderr.log
- dart analyze exit code: 3
- Analyzer log: /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_path_20260214_032413/analyze_18_install_skill.log

## 19. version

- Command: dart /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/shadcn_flutter_cli/bin/shadcn.dart --registries-path '/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/registry-directory/registries/registries.json' version --check
- Command exit code: 0
- Command stdout: /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_path_20260214_032413/19_version.stdout.log
- Command stderr: /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_path_20260214_032413/19_version.stderr.log
- dart analyze exit code: 3
- Analyzer log: /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_path_20260214_032413/analyze_19_version.log

## 20. doctor

- Command: dart /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/shadcn_flutter_cli/bin/shadcn.dart --registries-path '/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/registry-directory/registries/registries.json' doctor
- Command exit code: 60
- Command stdout: /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_path_20260214_032413/20_doctor.stdout.log
- Command stderr: /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_path_20260214_032413/20_doctor.stderr.log
- dart analyze exit code: 3
- Analyzer log: /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_path_20260214_032413/analyze_20_doctor.log

## 21. feedback

- Command: dart /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/shadcn_flutter_cli/bin/shadcn.dart --registries-path '/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/registry-directory/registries/registries.json' feedback --type invalid --title Smoke test --body Command smoke test
- Command exit code: 0
- Command stdout: /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_path_20260214_032413/21_feedback.stdout.log
- Command stderr: /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_path_20260214_032413/21_feedback.stderr.log
- dart analyze exit code: 3
- Analyzer log: /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_path_20260214_032413/analyze_21_feedback.log

## 22. upgrade

- Command: dart /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/shadcn_flutter_cli/bin/shadcn.dart --registries-path '/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/registry-directory/registries/registries.json' upgrade
- Command exit code: 0
- Command stdout: /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_path_20260214_032413/22_upgrade.stdout.log
- Command stderr: /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_path_20260214_032413/22_upgrade.stderr.log
- dart analyze exit code: 3
- Analyzer log: /Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/test_project/.codex/shadcn_command_test_logs_local_path_20260214_032413/analyze_22_upgrade.log

## Summary

| Step | Command Exit | Analyze Exit | Errors | Warnings | Infos |
|---|---:|---:|---:|---:|---:|
| 1_init | 0 | 3 | 58 | 0 | 7 |
| 2_theme | 0 | 3 | 58 | 0 | 7 |
| 3_add | 255 | 3 | 86 | 69 | 15 |
| 4_dry_run | 30 | 3 | 86 | 69 | 15 |
| 5_remove | 0 | 3 | 58 | 0 | 7 |
| 6_sync | 0 | 3 | 58 | 0 | 2 |
| 7_assets | 255 | 3 | 43 | 1 | 2 |
| 8_platform | 0 | 3 | 43 | 1 | 2 |
| 9_registries | 0 | 3 | 43 | 1 | 2 |
| 10_default | 0 | 3 | 43 | 1 | 2 |
| 11_list | 0 | 3 | 43 | 1 | 2 |
| 12_search | 0 | 3 | 43 | 1 | 2 |
| 13_info | 0 | 3 | 43 | 1 | 2 |
| 14_validate | 0 | 3 | 43 | 1 | 2 |
| 15_audit | 0 | 3 | 43 | 1 | 2 |
| 16_deps | 50 | 3 | 43 | 1 | 2 |
| 17_docs | 0 | 3 | 43 | 1 | 2 |
| 18_install_skill | 0 | 3 | 43 | 1 | 2 |
| 19_version | 0 | 3 | 43 | 1 | 2 |
| 20_doctor | 60 | 3 | 43 | 1 | 2 |
| 21_feedback | 0 | 3 | 43 | 1 | 2 |
| 22_upgrade | 0 | 3 | 43 | 1 | 2 |

