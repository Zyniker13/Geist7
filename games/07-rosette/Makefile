SHELL := /bin/bash
.PHONY: bootstrap gen build test lint snapshot perf coverage sim all

XCODEGEN := xcodegen
SWIFTLINT := swiftlint
SWIFTFORMAT := swift-format
SWIFT := swift

bootstrap:
	@which $(XCODEGEN) >/dev/null 2>&1 || brew install xcodegen
	@which $(SWIFTLINT) >/dev/null 2>&1 || brew install swiftlint
	@which $(SWIFTFORMAT) >/dev/null 2>&1 || brew install swift-format

gen: bootstrap
	$(XCODEGEN) generate

build: gen
	xcodebuild build -scheme Rosette-iOS -destination "platform=iOS Simulator,name=iPad Pro 13-inch (M5)" -configuration Debug COMPILER_INDEX_STORE_ENABLE=NO 2>&1 | tee build-ios.log
	xcodebuild build -scheme Rosette-macOS -destination "platform=macOS" -configuration Debug COMPILER_INDEX_STORE_ENABLE=NO 2>&1 | tee build-macos.log

test: gen
	@for pkg in Packages/*/; do \
	  echo "Testing $${pkg}"; \
	  $(SWIFT) test --package-path "$${pkg}" 2>&1 | tee "test-$$(basename $${pkg}).log" | tail -3 || exit 1; \
	done
	xcodebuild test -scheme Rosette-iOS -destination "platform=iOS Simulator,name=iPad Pro 13-inch (M5)" -configuration Debug -only-testing:Rosette-iOS/UITests COMPILER_INDEX_STORE_ENABLE=NO 2>&1 | tee uitest.log || true

lint: gen
	@set -o pipefail; $(SWIFTLINT) lint --strict 2>&1 | tee lint-swiftlint.log
	@set -o pipefail; $(SWIFTFORMAT) lint --recursive Packages/ App/ Tools/ Tests/ 2>&1 | tee lint-swiftformat.log
	@bash Tools/check-imports.sh 2>&1 | tee lint-imports.log
	@bash Tools/content-lint/run.sh 2>&1 | tee lint-content.log

snapshot: gen
	xcodebuild test -scheme Rosette-iOS -destination "platform=iOS Simulator,name=iPad Pro 13-inch (M5)" -configuration Debug -only-testing:Rosette-iOS Snapshots COMPILER_INDEX_STORE_ENABLE=NO 2>&1 | tee snapshot.log

perf: gen
	@echo "Performance: run with Instruments"
	@echo "  xcrun instruments -t 'Game Performance' -w 'iPad Pro 13-inch (M5)' $(HOME)/Library/Developer/Xcode/DerivedData/Rosette*/Build/Products/Debug-iphonesimulator/Rosette-iOS.app"

coverage: gen
	@echo "Coverage: run 'make test' first, then"
	@echo "  xcrun xccov view --report Rosette-iOS.xctest 2>&1 | tee COVERAGE.md"

sim: gen
	@N=${N:-200}; echo "Running $$N seeded AI-vs-AI games..."; $(SWIFT) run --package-path Tools/sim sim --count $$N 2>&1 | tee sim.log

all: test lint
