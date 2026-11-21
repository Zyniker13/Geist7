# Mattang
#
# Run under a chosen DEVELOPER_DIR if the shell does not carry one
# (this machine's Xcode lives at a fixed path; see _CONVENTIONS S0.3).

XCODEGEN ?= xcodegen
XCODEBUILD ?= xcodebuild
SWIFT ?= swift
SIMDEST ?= platform=iOS Simulator,name=iPhone 17
DEST ?= platform=macOS

.PHONY: help generate build build-mac test test-pkgs test-mac lint swiftlint \
        swiftformat check-imports content-lint sim perf coverage clean

help:
	@echo "make generate   - regenerate Mattang.xcodeproj with xcodegen"
	@echo "make build      - build iOS app (simulator)"
	@echo "make build-mac  - build macOS app"
	@echo "make test       - run package tests, then iOS UI tests"
	@echo "make test-pkgs  - run every Swift package's tests"
	@echo "make test-mac   - run macOS unit + UI tests"
	@echo "make lint       - swiftlint + swift-format + import + content checks"
	@echo "make sim N=5000 - seeded random-legal playouts (G1 determinism check)"
	@echo "make perf       - release-mode INV-9 field-update timing"
	@echo "make coverage   - MTCore line coverage (swift test + llvm-cov)"

generate:
	$(XCODEGEN)

build: generate
	$(XCODEBUILD) -project Mattang.xcodeproj -scheme Mattang-iOS \
	  -destination "$(SIMDEST)" -configuration Debug build

build-mac: generate
	$(XCODEBUILD) -project Mattang.xcodeproj -scheme Mattang-macOS \
	  -destination "$(DEST)" -configuration Debug build

test: test-pkgs generate
	$(XCODEBUILD) -project Mattang.xcodeproj -scheme Mattang-iOS \
	  -destination "$(SIMDEST)" -configuration Debug test

test-pkgs:
	@set -o pipefail; \
	for pkg in Packages/*/; do \
	  echo "Testing $${pkg}"; \
	  $(SWIFT) test --package-path "$${pkg}" 2>&1 | tee "test-$$(basename $${pkg}).log" | grep -E "Executed [0-9]+ tests|Test Suite '.*' (passed|failed)|Test run with .* (passed|failed)|error:" || exit 1; \
	done

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

sim:
	@N=$(if $(N),$(N),200); echo "Running $$N seeded random-legal games..."; \
	set -o pipefail; \
	$(SWIFT) run --package-path Tools/sim sim --count $$N --seed 20261120 2>&1 | tee sim.log

perf:
	$(SWIFT) test -c release --package-path Packages/MTCore \
	  --filter InvariantPlayoutTests 2>&1 | tee perf.log | \
	  grep -E "worst incremental|Executed .* tests, with"

coverage: test-pkgs
	@$(SWIFT) test --package-path Packages/MTCore --enable-code-coverage \
	  2>&1 | tail -2; \
	XCPATH=$$(ls -d Packages/MTCore/.build/out/Products/Debug/MTCoreTests.xctest 2>/dev/null | head -1); \
	PROFDATA=Packages/MTCore/.build/out/Products/Debug/codecov/default.profdata; \
	XCBIN="$$XCPATH/Contents/MacOS/MTCoreTests"; \
	echo "Coverage profile: $$XCBIN"; \
	test -n "$$XCPATH" || { echo "coverage: test bundle not found"; exit 1; }; \
	test -x "$$XCBIN" || { echo "coverage: test binary not found at $$XCBIN"; exit 1; }; \
	test -f "$$PROFDATA" || { echo "coverage: profdata not found"; exit 1; }; \
	xcrun llvm-cov report "$$XCBIN" -instr-profile=$$PROFDATA \
	  --sources Packages/MTCore/Sources 2>&1 | tail -12

clean:
	rm -rf Mattang.xcodeproj ~/Library/Developer/Xcode/DerivedData/Mattang-*
