# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SwiftfulGamification is a Swift Package Manager (SPM) library for iOS (15+) and macOS (10.15+). It depends on SwiftfulFirestore (v11.x) for Firebase/Firestore integration.

## Building and Testing

### Build the package
```bash
swift build
```

### Run all tests
```bash
swift test
```

### Run a single test
```bash
swift test --filter SwiftfulGamificationTests.example
```

### Open in Xcode
```bash
xed .
```

## Package Structure

- `Package.swift` - SPM manifest with platforms, dependencies (SwiftfulFirestore), and targets
- `Sources/SwiftfulGamification/` - Main library code
- `Tests/SwiftfulGamificationTests/` - Test suite using Swift Testing framework

## Architecture Notes

- Uses Swift 6.1 toolchain
- Depends on SwiftfulFirestore package for Firestore operations
- Tests use the Swift Testing framework (not XCTest) - note the `@Test` attribute and `#expect()` assertions
