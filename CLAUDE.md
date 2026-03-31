# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

GoldPrice is a native macOS menu bar application (status bar app) that displays real-time gold prices from 15+ Chinese data sources. Built with Swift 5.5+ / SwiftUI, targeting macOS 12.0+. No external dependencies — uses only system frameworks (Foundation, SwiftUI, AppKit, Combine).

The app runs as a menu bar-only app (`LSUIElement=true`) with no dock icon. Bundle ID: `com.goldprice.app`.

## Build & Run

```bash
swift build                     # Debug build
swift build -c release          # Release build
swift run                       # Run the app
./Build/build_app.sh            # Full build: compile, create .app bundle, archive previous version
./Build/create_dmg.sh           # Create DMG and ZIP installers
```

No test suite exists in this project.

## Architecture

Four source files with clear separation:

- **GoldPriceApp.swift** — Entry point, app delegate setup
- **GoldPriceService.swift** — Core data layer (ObservableObject). Fetches prices from all sources via URLSession, parses JSON APIs and HTML (regex-based scraping), manages state with `@Published` properties and Combine
- **StatusBarController.swift** — NSStatusBar controller. Manages menu bar button, right-click context menu for source selection, NSPopover for detail view, and refresh timers
- **GoldPriceView.swift** — SwiftUI detail view shown in the popover

Data flows: API endpoints → GoldPriceService (fetch/parse) → Combine `@Published` → StatusBarController + GoldPriceView.

## Data Sources & Refresh Intervals

Three categories with different refresh strategies:
- **JD Finance sources** (京东): ~1s refresh via REST API
- **Shuibei Gold** (水贝黄金): ~5min refresh, HTML scraping with regex
- **Brand jewelry stores** (11 brands): ~10min refresh via cngold.org API

All network calls use `URLSession` with no third-party HTTP libraries.

## Key Patterns

- State centralized in `GoldPriceService` using two dictionaries: `allSourcePrices` (price data) and `allSourcePriceAvailability` (source status)
- Data sources enumerated in `GoldPriceSource` enum
- HTML parsing uses `NSRegularExpression` — no external HTML parser
- Status bar text updates on a 100ms timer; data fetches on separate per-source timers
- All UI text is in Simplified Chinese
