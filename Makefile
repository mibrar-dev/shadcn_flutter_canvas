CLI_PATH ?= shadcn_flutter_cli
PUB_CACHE ?= $(HOME)/.pub-cache
KIT_PATH ?= shadcn_flutter_kit/flutter_shadcn_kit

.PHONY: cli-clean cli-install cli-reset schemas schemas-dart schemas-all

cli-clean:
	dart pub global deactivate flutter_shadcn_cli || true
	rm -f $(PUB_CACHE)/bin/flutter_shadcn
	rm -f $(PUB_CACHE)/bin/shadcn
	rm -rf $(PUB_CACHE)/global_packages/flutter_shadcn_cli
	rm -rf $(CLI_PATH)/.dart_tool/pub/bin/flutter_shadcn_cli
	rm -rf $(CLI_PATH)/.dart_tool/pub/bin/flutter_shadcn.dart-*.snapshot
	rm -rf $(CLI_PATH)/.dart_tool/pub/bin/shadcn.dart-*.snapshot

cli-install:
	dart pub global activate --source path $(CLI_PATH)

cli-reset: cli-clean cli-install

schemas:
	@echo "🔄 Generating convention-based JSON schemas..."
	@cd $(KIT_PATH) && dart run tool/generate_schemas_convention.dart --format=json

schemas-dart:
	@echo "🧩 Generating convention-based Dart schema files..."
	@cd $(KIT_PATH) && dart run tool/generate_schemas_convention.dart --format=dart

schemas-all:
	@echo "📦 Generating convention-based schemas (JSON + Dart)..."
	@cd $(KIT_PATH) && dart run tool/generate_schemas_convention.dart --format=both
