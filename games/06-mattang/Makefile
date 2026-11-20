# Mattang

# Run under a chosen DEVELOPER_DIR if the shell does not carry one
# (this machine's Xcode lives at a fixed path; see _CONVENTIONS S0.3).

XCODEGEN ?= xcodegen
XCODEBUILD ?= xcodebuild
SIMDEST ?= platform=iOS Simulator,name=iPhone 17
DEST ?= platform=macOS

.PHONY: help generate build build-mac test test-mac lint swiftlint swiftformat \
        check-imports content-lint clean

help:
	@echo "make generate   - regenerate Mattang.xcodeproj with xcodegen"
	@echo "make build      - build iOS app (simulator)"
	@echo "make build-mac  - build macOS app"
	@echo "make test       - run iOS UI tests"
	@echo "make test-mac   - run macOS unit + UI tests"
	@echo "make lint       - swiftlint + swift-format + import + content checks"

generate:
	$(XCODEGEN)

build: generate
	$(XCODEBUILD) -project Mattang.xcodeproj -scheme Mattang-iOS \
	  -destination "$(SIMDEST)" -configuration Debug build

build-mac: generate
	$(XCODEBUILD) -project Mattang.xcodeproj -scheme Mattang-macOS \
	  -destination "$(DEST)" -configuration Debug build

test: generate
	$(XCODEBUILD) -project Mattang.xcodeproj -scheme Mattang-iOS \
	  -destination "$(SIMDEST)" -configuration Debug test

test-mac: generate
	$(XCODEBUILD) -project Mattang.xcodeproj -scheme Mattang-macOS \
	  -destination "$(DEST)" -configuration Debug test

lint: swiftlint swiftformat check-imports content-lint

swiftlint:
	swiftlint --quiet

swiftformat:
	swift-format lint --recursive --strict Packages App Tests

check-imports:
	Tools/check-imports.sh

content-lint:
	Tools/content-lint/run.sh

clean:
	rm -rf Mattang.xcodeproj ~/Library/Developer/Xcode/DerivedData/Mattang-*
