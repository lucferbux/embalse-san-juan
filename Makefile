SIMULATOR ?= iPhone 18 Pro
DESTINATION := platform=iOS Simulator,name=$(SIMULATOR)
PROJECT := ios/EmbalseSanJuan.xcodeproj
DERIVED := build/DerivedData

.PHONY: check check-backend check-ios scan-secrets live-check widgets generate fixture run-info

## The one command that says whether the project is healthy.
check: scan-secrets check-backend check-ios

check-backend:
	cd backend && npm run -s check

generate:
	cd ios && xcodegen generate --quiet

check-ios: generate
	xcodebuild test -quiet -project $(PROJECT) -scheme EmbalseSanJuan \
		-destination '$(DESTINATION)' -derivedDataPath $(DERIVED) CODE_SIGNING_ALLOWED=NO

## Fails if anything that looks like a credential is tracked or staged.
scan-secrets:
	@if git grep --cached -nE 'BEGIN (RSA )?PRIVATE KEY|"private_key"' -- . ':!Makefile' ':!.claude/hooks/guard-secrets.sh' ':!docs/*'; then \
		echo "Possible secret in the repo" >&2; exit 1; \
	fi
	@echo "No secrets found"

## Calls the real sources, writing nothing.
live-check:
	cd backend && npm run -s live-check

## Rebuilds the fixture shared by the TypeScript and Swift tests.
fixture:
	cd backend && npm run -s generate-fixture

## Renders every widget size and mode to build/widget-snapshots for review.
widgets: generate
	rm -rf build/widget-snapshots
	mkdir -p build/widget-snapshots
	xcodebuild test -quiet -project $(PROJECT) -scheme EmbalseSanJuan \
		-destination '$(DESTINATION)' -derivedDataPath $(DERIVED) CODE_SIGNING_ALLOWED=NO \
		-only-testing:EmbalseKitTests/WidgetSnapshotTests
	@ls build/widget-snapshots
