SIMULATOR ?= iPhone 18 Pro
DESTINATION := platform=iOS Simulator,name=$(SIMULATOR)
PROJECT := ios/EmbalseSanJuan.xcodeproj
DERIVED := build/DerivedData
# Homebrew keeps JDK 21 off the PATH, and Gradle needs it.
export JAVA_HOME ?= /opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home

.PHONY: firestore-check check check-backend check-ios check-android check-site site-smoke deploy-site run-android scan-secrets live-check widgets generate fixture run-info

## The one command that says whether the project is healthy.
check: scan-secrets check-backend check-site check-ios check-android

check-backend:
	cd backend && npm run -s check

generate:
	cd ios && xcodegen generate --quiet

check-ios: generate
	python3 -I scripts/l10n.py check
	xcodebuild test -quiet -project $(PROJECT) -scheme EmbalseSanJuan \
		-destination '$(DESTINATION)' -derivedDataPath $(DERIVED) CODE_SIGNING_ALLOWED=NO
	xcodebuild build -quiet -project $(PROJECT) -scheme EmbalseWatch \
		-destination 'generic/platform=watchOS Simulator' -derivedDataPath $(DERIVED) CODE_SIGNING_ALLOWED=NO

## Fails if anything that looks like a credential is tracked or staged.
scan-secrets:
	@if git grep --cached -nE 'BEGIN (RSA )?PRIVATE KEY|"private_key"' -- . ':!Makefile' ':!scripts/claude-hooks/guard-secrets.sh' ':!docs/*'; then \
		echo "Possible secret in the repo" >&2; exit 1; \
	fi
	@echo "No secrets found"

## The landing page in firebase/site, end to end in the system Chrome, at four sizes and in dark mode.
check-site:
	cd firebase/e2e && npm ci --silent --no-audit --no-fund && npx playwright test

## The same tests against the deployed site, plus one with the real Firestore data.
site-smoke:
	cd firebase/e2e && npm ci --silent --no-audit --no-fund && BASE_URL=https://embalse-san-juan.web.app npx playwright test

## Tests, deploys the site to Firebase Hosting, then checks production.
deploy-site: check-site
	cd firebase && firebase deploy --only hosting --project embalse-san-juan
	$(MAKE) site-smoke

## Unit tests, including the shared fixture, and both Android builds.
check-android:
	cd android && ./gradlew --quiet testDebugUnitTest assembleDebug assembleRelease

## Installs and opens the debug build on the running emulator or device.
run-android:
	cd android && ./gradlew --quiet installDebug
	adb shell am start -n com.lucferbux.embalsesanjuan/.MainActivity

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

## Checks the published data and the access rules from outside, with no credentials.
firestore-check:
	scripts/firestore-check.sh
