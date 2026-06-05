APP       = Gridly
XCPROJ    = $(APP).xcodeproj
BUILD     = build
BUNDLE_ID = com.gridly.app
VERSION  := $(shell /usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Resources/Info.plist 2>/dev/null || echo "1.0")

# ── Distribution credentials ────────────────────────────────────────────────
# Option A (recommended): store credentials in keychain once, then just set:
#   NOTARIZE_PROFILE=<profile-name>  (created via: make notarize-store-creds)
# Option B: pass inline each time:
#   APPLE_TEAM_ID, APPLE_ID, APPLE_PASSWORD (app-specific password)
TEAM_ID          ?= $(APPLE_TEAM_ID)
NOTARIZE_PROFILE ?=
ifdef NOTARIZE_PROFILE
  NOTARIZE_FLAGS = --keychain-profile "$(NOTARIZE_PROFILE)"
else
  NOTARIZE_FLAGS = --apple-id "$(APPLE_ID)" --password "$(APPLE_PASSWORD)" --team-id "$(TEAM_ID)"
endif

DMG_NAME = $(APP)-$(VERSION).dmg
DMG_PATH = $(BUILD)/$(DMG_NAME)

.PHONY: generate build run clean setup icons dist signed-app dmg notarize staple notarize-store-creds

# ── Primary build (swift build, works without full Xcode) ──────────────────
build:
	swift build -c release

app: build
	mkdir -p $(BUILD)/$(APP).app/Contents/MacOS
	mkdir -p $(BUILD)/$(APP).app/Contents/Resources
	cp .build/release/$(APP)   $(BUILD)/$(APP).app/Contents/MacOS/$(APP)
	cp Resources/Info.plist    $(BUILD)/$(APP).app/Contents/Info.plist
	cp -r Sources/$(APP)/Assets.xcassets \
	      $(BUILD)/$(APP).app/Contents/Resources/
	# Compile asset catalog (actool ships with Command Line Tools)
	xcrun actool Sources/$(APP)/Assets.xcassets \
	  --compile $(BUILD)/$(APP).app/Contents/Resources \
	  --platform macosx --minimum-deployment-target 14.0 \
	  --app-icon AppIcon --output-partial-info-plist /dev/null 2>/dev/null || true
	codesign --force --deep --sign - $(BUILD)/$(APP).app
	@echo "✓ Built $(BUILD)/$(APP).app"

run: app
	open $(BUILD)/$(APP).app

# ── Xcode project (open in Xcode once installed, used for signing) ──────────
generate:
	xcodegen generate

$(XCPROJ):
	xcodegen generate

# ── One-time setup ──────────────────────────────────────────────────────────
icons:
	swift scripts/generate_icon.swift

setup: icons generate

# ── When Xcode IS installed ─────────────────────────────────────────────────
xcode-build: $(XCPROJ)
	xcodebuild \
	  -project $(XCPROJ) -scheme $(APP) \
	  -configuration Release \
	  CONFIGURATION_BUILD_DIR=$(PWD)/$(BUILD) \
	  CODE_SIGNING_ALLOWED=NO build

clean:
	rm -rf $(BUILD)
	swift package clean

# ── Distribution pipeline ───────────────────────────────────────────────────
# Full pipeline: make dist APPLE_TEAM_ID=XXXXXXXXXX NOTARIZE_PROFILE=myprofile
# or:           make dist APPLE_TEAM_ID=XX APPLE_ID=you@email.com APPLE_PASSWORD=xxxx-xxxx-xxxx-xxxx
dist: signed-app dmg notarize staple
	@echo "✓ $(DMG_PATH) is ready to ship"

signed-app: $(XCPROJ)
	@test -n "$(TEAM_ID)" || (echo "error: set APPLE_TEAM_ID (your 10-char Apple Developer team ID)" && exit 1)
	xcodebuild \
	  -project $(XCPROJ) -scheme $(APP) \
	  -configuration Release \
	  CONFIGURATION_BUILD_DIR=$(PWD)/$(BUILD) \
	  CODE_SIGN_STYLE=Manual \
	  CODE_SIGN_IDENTITY="Developer ID Application" \
	  DEVELOPMENT_TEAM="$(TEAM_ID)" \
	  CODE_SIGNING_REQUIRED=YES \
	  build
	codesign --verify --deep --strict --verbose=2 $(BUILD)/$(APP).app
	@echo "✓ Signed $(BUILD)/$(APP).app"

dmg:
	@test -d "$(BUILD)/$(APP).app" || (echo "error: run 'make signed-app' first" && exit 1)
	rm -f "$(DMG_PATH)"
	rm -rf "$(BUILD)/dmg-staging"
	mkdir -p "$(BUILD)/dmg-staging"
	cp -r "$(BUILD)/$(APP).app" "$(BUILD)/dmg-staging/"
	ln -s /Applications "$(BUILD)/dmg-staging/Applications"
	hdiutil create \
	  -volname "$(APP)" \
	  -srcfolder "$(BUILD)/dmg-staging" \
	  -ov -format UDZO \
	  "$(DMG_PATH)"
	rm -rf "$(BUILD)/dmg-staging"
	@test -n "$(TEAM_ID)" && \
	  codesign --sign "Developer ID Application: $(TEAM_ID)" "$(DMG_PATH)" || \
	  codesign --sign "Developer ID Application" "$(DMG_PATH)"
	@echo "✓ Created and signed $(DMG_PATH)"

notarize:
	@test -f "$(DMG_PATH)" || (echo "error: run 'make dmg' first" && exit 1)
	xcrun notarytool submit "$(DMG_PATH)" $(NOTARIZE_FLAGS) --wait
	@echo "✓ Notarization complete"

staple:
	xcrun stapler staple "$(DMG_PATH)"
	xcrun stapler validate "$(DMG_PATH)"
	@echo "✓ Stapled and validated $(DMG_PATH)"

# Run once to store credentials in keychain (avoids passing them every time)
# Usage: make notarize-store-creds APPLE_TEAM_ID=XX APPLE_ID=you@me.com NOTARIZE_PROFILE=windowmanager
notarize-store-creds:
	@test -n "$(NOTARIZE_PROFILE)" || (echo "error: set NOTARIZE_PROFILE=<name>" && exit 1)
	@test -n "$(APPLE_ID)"         || (echo "error: set APPLE_ID" && exit 1)
	@test -n "$(TEAM_ID)"          || (echo "error: set APPLE_TEAM_ID" && exit 1)
	xcrun notarytool store-credentials "$(NOTARIZE_PROFILE)" \
	  --apple-id "$(APPLE_ID)" \
	  --team-id "$(TEAM_ID)"
	@echo "✓ Credentials stored in keychain under profile '$(NOTARIZE_PROFILE)'"
