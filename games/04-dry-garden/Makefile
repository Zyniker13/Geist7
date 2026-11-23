# Dry Garden
#
# Run under a chosen DEVELOPER_DIR if the shell does not carry one
# (this machine's Xcode lives at a fixed path; see _CONVENTIONS S0.3).

XCODEGEN ?= xcodegen
XCODEBUILD ?= xcodebuild
SWIFT ?= swift
SIMDEST ?= platform=iOS Simulator,name=iPhone 18 Pro Max
DEST ?= platform=macOS

.PHONY: help generate build build-mac test test-pkgs test-mac lint swiftlint \
        swiftformat check-imports sim coverage clean

help:
	@echo "make generate   - regenerate DryGarden.xcodeproj with xcodegen"
	@echo "make build      - build iOS app (simulator)"
	@echo "make build-mac  - build macOS app"
	@echo "make test       - run package tests, then iOS UI tests"
	@echo "make test-pkgs  - run every Swift package's tests"
	@echo "make test-mac   - run macOS unit tests"
	@echo "make lint       - swiftlint + swift-format + import checks"
	@echo "make sim N=200  - seeded random-legal playouts (arrives in P1)"
	@echo "make coverage   - DGCore line coverage (swift test + llvm-cov)"

generate:
	$(XCODEGEN)

build: generate
	$(XCODEBUILD) -project DryGarden.xcodeproj -scheme DryGarden-iOS \
	  -destination "$(SIMDEST)" -configuration Debug build

build-mac: generate
	$(XCODEBUILD) -project DryGarden.xcodeproj -scheme DryGarden-macOS \
	  -destination "$(DEST)" -configuration Debug build

test: test-pkgs generate
	$(XCODEBUILD) -project DryGarden.xcodeproj -scheme DryGarden-iOS \
	  -destination "$(SIMDEST)" -configuration Debug test

test-pkgs:
	@set -o pipefail; \
	for pkg in Packages/*/; do \
	  echo "Testing $${pkg}"; \
	  $(SWIFT) test --package-path "$${pkg}" 2>&1 | tee "test-$$(basename $${pkg}).log" | grep -E "Executed [0-9]+ tests|Test Suite '.*' (passed|failed)|Test run with .* (passed|failed)|error:" || exit 1; \
	done

test-mac: generate
	$(XCODEBUILD) -project DryGarden.xcodeproj -scheme DryGarden-macOS \
	-destination "$(DEST)" -configuration Debug test

lint: swiftlint swiftformat check-imports

swiftlint:
	swiftlint --quiet

swiftformat:
	swift-format lint --configuration .swift-format --recursive --strict Packages App Tests Tools

check-imports:
	Tools/check-imports.sh

sim:
	@echo "sim: arrives in P1 with the rules engine (DG-P1.x)"; exit 1

coverage: test-pkgs
	@$(SWIFT) test --package-path Packages/DGCore --enable-code-coverage \
	  2>&1 | tail -2; \
	XCPATH=$$(ls -d Packages/DGCore/.build/out/Products/Debug/DGCoreTests.xctest 2>/dev/null | head -1); \
	PROFDATA=Packages/DGCore/.build/out/Products/Debug/codecov/default.profdata; \
	XCBIN="$$XCPATH/Contents/MacOS/DGCoreTests"; \
	echo "Coverage profile: $$XCBIN"; \
	test -n "$$XCPATH" || { echo "coverage: test bundle not found"; exit 1; }; \
	test -x "$$XCBIN" || { echo "coverage: test binary not found at $$XCBIN"; exit 1; }; \
	test -f "$$PROFDATA" || { echo "coverage: profdata not found"; exit 1; }; \
	xcrun llvm-cov report "$$XCBIN" -instr-profile=$$PROFDATA \
	  --sources Packages/DGCore/Sources 2>&1 | tail -12

clean:
	rm -rf DryGarden.xcodeproj ~/Library/Developer/Xcode/DerivedData/DryGarden-*
