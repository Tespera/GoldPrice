# GoldPrice Makefile

.PHONY: build run clean

build:
	swift build -c release

run: build
	./.build/x86_64-apple-macosx/release/GoldPrice

clean:
	swift package clean
	-rm -rf .build