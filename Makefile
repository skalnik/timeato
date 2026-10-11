PROJECT := Timeato.xcodeproj
SCHEME := Timeato
APPSTORE_SCHEME := Timeato-AppStore
APP := Timeato.app
# Debug builds of the App Store app have a different name. See project.yml.
APPSTORE_APP := Timeato App Store.app
DESTINATION := platform=macOS
BUILD_DIR := build

FORMAT := $(shell command -v xcbeautify >/dev/null 2>&1 && echo "| xcbeautify" || echo "")

.PHONY: help
help: ## Show this help
	@grep -hE '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'

.PHONY: generate
generate: ## Make the Xcode project from project.yml
	@xcodegen generate

.PHONY: build
build: generate ## Build the app
	set -o pipefail; xcodebuild build \
		-project "$(PROJECT)" -scheme "$(SCHEME)" \
		-destination "$(DESTINATION)" -configuration Debug $(FORMAT)

.PHONY: build-appstore
build-appstore: generate ## Build the Mac App Store app, without Sparkle
	set -o pipefail; xcodebuild build \
		-project "$(PROJECT)" -scheme "$(APPSTORE_SCHEME)" \
		-destination "$(DESTINATION)" -configuration Debug $(FORMAT)

.PHONY: test
test: generate ## Run the unit tests
	set -o pipefail; xcodebuild test \
		-project "$(PROJECT)" -scheme "$(SCHEME)" \
		-destination "$(DESTINATION)" $(FORMAT)

.PHONY: run
run: build ## Build and start the app
	@set -e -o pipefail; \
	dir=$$(xcodebuild -project "$(PROJECT)" -scheme "$(SCHEME)" \
		-destination "$(DESTINATION)" -configuration Debug -showBuildSettings \
		| awk -F' = ' '/ BUILT_PRODUCTS_DIR/ {print $$2; exit}'); \
	test -n "$$dir"; \
	open "$$dir/$(APP)"

.PHONY: run-appstore
run-appstore: build-appstore ## Build and start the Mac App Store app
	@set -e -o pipefail; \
	dir=$$(xcodebuild -project "$(PROJECT)" -scheme "$(APPSTORE_SCHEME)" \
		-destination "$(DESTINATION)" -configuration Debug -showBuildSettings \
		| awk -F' = ' '/ BUILT_PRODUCTS_DIR/ {print $$2; exit}'); \
	test -n "$$dir"; \
	open "$$dir/$(APPSTORE_APP)"

.PHONY: archive
archive: generate ## Make an archive in build/
	set -o pipefail; xcodebuild archive \
		-project "$(PROJECT)" -scheme "$(SCHEME)" \
		-destination "generic/platform=macOS" \
		-archivePath "$(BUILD_DIR)/Timeato.xcarchive" $(FORMAT)

.PHONY: release
release: ## Sign and notarize the app, make a GitHub release, and push appcast.xml
	bin/release-macos

.PHONY: bump
bump: ## Set the version to today's date and the build number to the time
	bin/bump-version
	@$(MAKE) generate

.PHONY: open
open: generate ## Open the project in Xcode
	open "$(PROJECT)"

.PHONY: clean
clean: ## Remove build output
	rm -rf "$(BUILD_DIR)"
	xcodebuild clean -project "$(PROJECT)" -scheme "$(SCHEME)" >/dev/null 2>&1 || true

.PHONY: distclean
distclean: clean ## Remove build output and the generated Xcode project
	rm -rf "$(PROJECT)"
