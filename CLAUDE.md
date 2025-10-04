# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SwiftfulGamification is a Swift Package Manager (SPM) library for iOS (15+) and macOS (10.15+) that implements gamification features (streaks, streak freezes) for iOS apps. This package follows the **SwiftfulThinking Provider Pattern Architecture** - a dependency-agnostic design where the base package defines protocols and abstract models, while separate implementation packages (like SwiftfulGamificationFirebase) provide concrete implementations for specific backends.

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

## SwiftfulThinking Architecture Pattern

This package is part of the SwiftfulThinking ecosystem and follows a standardized architecture pattern used across all SwiftfulThinking packages. Understanding this pattern is critical for proper implementation.

### Core Principles

1. **Base Package = Zero Dependencies + Protocols**
   - This package (SwiftfulGamification) should have NO external dependencies except SwiftfulFirestore is REMOVED
   - Defines all protocols, models, and manager classes
   - Includes a Mock implementation for testing
   - All public types are protocol-based, Codable, and Sendable

2. **Implementation Package = Concrete Provider**
   - SwiftfulGamificationFirebase (separate SPM) will implement Firebase-specific logic
   - Depends on both the base package AND the provider SDK (Firebase)
   - Implements the service protocol(s) defined in the base package
   - Handles all provider-specific constraints and conversions

3. **Dependency Injection via Protocols**
   - Manager classes accept protocol types in their initializers
   - Application code swaps implementations by changing what's injected
   - Enables mock/dev/prod environment switching at build time

### The Standard Pattern Structure

Based on analysis of SwiftfulAuthenticating, SwiftfulLogging, and SwiftfulPurchasing packages.

**For reference examples of this pattern, see:**
- `AuthService` in `/Users/nicksarno/Documents/documents/GITHUB/SwiftfulAuthenticating/Sources/SwiftfulAuthenticating/Services/AuthService.swift`
- `LogService` in `/Users/nicksarno/Documents/documents/GITHUB/SwiftfulLogging/Sources/SwiftfulLogging/Services/LogService.swift`
- `PurchaseService` in `/Users/nicksarno/Documents/documents/GITHUB/SwiftfulPurchasing/Sources/SwiftfulPurchasing/Services/PurchaseService.swift`
- `AuthManager` in `/Users/nicksarno/Documents/documents/GITHUB/SwiftfulAuthenticating/Sources/SwiftfulAuthenticating/AuthManager.swift`
- `LogManager` in `/Users/nicksarno/Documents/documents/GITHUB/SwiftfulLogging/Sources/SwiftfulLogging/LogManager.swift`
- `PurchaseManager` in `/Users/nicksarno/Documents/documents/GITHUB/SwiftfulPurchasing/Sources/SwiftfulPurchasing/PurchaseManager.swift`
- `MockAuthService` in `/Users/nicksarno/Documents/documents/GITHUB/SwiftfulAuthenticating/Sources/SwiftfulAuthenticating/Services/MockAuthService.swift`
- `MockPurchaseService` in `/Users/nicksarno/Documents/documents/GITHUB/SwiftfulPurchasing/Sources/SwiftfulPurchasing/Services/MockPurchaseService.swift`

**For Firebase implementation examples, see:**
- `FirebaseAuthService` in `/Users/nicksarno/Documents/documents/GITHUB/SwiftfulAuthenticatingFirebase/Sources/SwiftfulAuthenticatingFirebase/FirebaseAuthService.swift`
- `UserAuthInfo+Firebase.swift` in `/Users/nicksarno/Documents/documents/GITHUB/SwiftfulAuthenticatingFirebase/Sources/SwiftfulAuthenticatingFirebase/UserAuthInfo+Firebase.swift`
- `FirebaseAnalyticsService` in `/Users/nicksarno/Documents/documents/GITHUB/SwiftfulLoggingFirebaseAnalytics/Sources/SwiftfulLoggingFirebaseAnalytics/FirebaseAnalyticsService.swift`
- `RevenueCatPurchaseService` in `/Users/nicksarno/Documents/documents/GITHUB/SwiftfulPurchasingRevenueCat/Sources/SwiftfulPurchasingRevenueCat/RevenueCatPurchaseService.swift`

### Pattern Requirements

**Service Protocols:**
- `Sendable` conformance for Swift 6 concurrency
- All methods use `async throws` for async operations
- Return abstract types (never provider-specific types)
- Use `AsyncStream` for reactive data (not Combine publishers)
- No platform-specific types in signatures

**Models:**
- All properties public with explicit types
- `Codable` for serialization
- `Sendable` for concurrency safety
- Public initializer with all parameters
- Mock factory method: `static func mock() -> Self`
- Event parameters for analytics integration
- CodingKeys with snake_case for API compatibility

**Manager:**
- `@MainActor` isolation for UI safety
- `@Observable` for SwiftUI integration
- Dependency injection via initializer
- Optional logger for analytics
- Event enum conforming to logger protocol
- Comprehensive event tracking (start, success, fail)

**Mock Services:**
- Use `@Published` for reactive state
- AsyncStream from Combine publisher for listeners
- Maintain stateful behavior (updates persist)
- No external dependencies
- Always succeeds (useful for UI testing)

### Naming Conventions (CRITICAL - Follow Exactly)

1. **Package Names**:
   - Base: `Swiftful{Feature}` (e.g., `SwiftfulGamification`)
   - Implementation: `Swiftful{Feature}{Provider}` (e.g., `SwiftfulGamificationFirebase`)

2. **Protocol Names**:
   - Service: `{Feature}Service` (e.g., `GamificationService`)
   - Logger: `{Feature}Logger` (e.g., `GamificationLogger`)
   - Log Event: `{Feature}LogEvent` (e.g., `GamificationLogEvent`)

3. **Implementation Names**:
   - Provider service: `{Provider}{Feature}Service` (e.g., `FirebaseGamificationService`)
   - Mock service: `Mock{Feature}Service` (e.g., `MockGamificationService`)

4. **Manager Names**:
   - `{Feature}Manager` (e.g., `GamificationManager`)

5. **Model Names**:
   - Domain-focused (e.g., `UserStreak`, `StreakFreeze`)
   - NOT provider-focused (avoid names like `FirebaseStreak`)

6. **File Names**:
   - Protocol: `{Protocol}.swift`
   - Extension: `{Type}+{Provider}.swift` or `{Type}+EXT.swift`

### Integration in SwiftfulStarterProject

**For examples of integration, see:**
- How `AuthManager` is set up in `/Users/nicksarno/Documents/documents/GITHUB/SwiftfulStarterProject/SwiftfulStarterProject/Root/Dependencies/Dependencies.swift`
- How `PurchaseManager` is registered in the dependency container
- Type aliases in `/Users/nicksarno/Documents/documents/GITHUB/SwiftfulStarterProject/SwiftfulStarterProject/Managers/Auth/SwiftfulAuthenticating+Alias.swift`

## Related Packages (Reference Architecture)

For implementation guidance, refer to these packages that follow the EXACT same pattern:

### Authentication Pattern
- Base: `/Users/nicksarno/Documents/documents/GITHUB/SwiftfulAuthenticating`
- Firebase: `/Users/nicksarno/Documents/documents/GITHUB/SwiftfulAuthenticatingFirebase`
- Key files: `AuthManager.swift`, `AuthService.swift`, `MockAuthService.swift`, `FirebaseAuthService.swift`, `UserAuthInfo.swift`

### Logging Pattern
- Base: `/Users/nicksarno/Documents/documents/GITHUB/SwiftfulLogging`
- Firebase: `/Users/nicksarno/Documents/documents/GITHUB/SwiftfulLoggingFirebaseAnalytics`
- Key files: `LogManager.swift`, `LogService.swift`, `ConsoleService.swift`, `FirebaseAnalyticsService.swift`, `LoggableEvent.swift`

### Purchasing Pattern
- Base: `/Users/nicksarno/Documents/documents/GITHUB/SwiftfulPurchasing`
- RevenueCat: `/Users/nicksarno/Documents/documents/GITHUB/SwiftfulPurchasingRevenueCat`
- Key files: `PurchaseManager.swift`, `PurchaseService.swift`, `MockPurchaseService.swift`, `RevenueCatPurchaseService.swift`, `AnyProduct.swift`, `PurchasedEntitlement.swift`

### Integration Example
- Starter Project: `/Users/nicksarno/Documents/documents/GITHUB/SwiftfulStarterProject`
- Key files: `Dependencies.swift`, `CoreInteractor.swift`, `DependencyContainer.swift`

## Key Architecture Rules (DO NOT VIOLATE)

1. **Base package MUST have zero external dependencies** (except standard Swift/SwiftUI)
2. **All protocols MUST conform to Sendable**
3. **All models MUST be Codable and Sendable**
4. **Manager MUST be @MainActor and @Observable**
5. **Mock implementation MUST be included in base package**
6. **Firebase implementation MUST be in separate package**
7. **Use AsyncStream for reactive data, NOT Combine publishers in protocols**
8. **All public initializers required for models**
9. **Mock factory methods required: `static func mock() -> Self`**
10. **Event parameters required for analytics: `var eventParameters: [String: Any]`**
11. **Follow exact naming conventions above**
12. **Extension files for provider conversions: `{Type}+{Provider}.swift`**

## Package Structure

```
SwiftfulGamification/
├── Package.swift                           # SPM manifest (NO external dependencies)
├── Sources/SwiftfulGamification/
│   ├── Shared/
│   │   └── Models/
│   │       ├── GamificationLogger.swift           # Logger protocol (optional)
│   │       └── GamificationDictionaryValue.swift  # Type-safe dictionary values
│   └── Streaks/
│       ├── StreakManager.swift                    # Main public API (@MainActor, @Observable)
│       ├── Services/
│       │   ├── StreakService.swift                # Service protocols (Sendable)
│       │   ├── Remote/
│       │   │   ├── RemoteStreakService.swift      # Remote data protocol
│       │   │   └── MockRemoteStreakService.swift  # Mock remote implementation
│       │   └── Local/
│       │       ├── LocalStreakPersistence.swift   # Local storage protocol
│       │       └── MockLocalStreakPersistence.swift # Mock local implementation
│       ├── Models/
│       │   ├── CurrentStreakData.swift            # User's current streak state
│       │   ├── StreakEvent.swift                  # Individual streak event
│       │   ├── StreakFreeze.swift                 # Freeze to prevent streak loss
│       │   ├── StreakConfiguration.swift          # Streak behavior settings
│       │   └── StreakStatus.swift                 # Enum: active, atRisk, broken
│       └── Utilities/
│           └── StreakCalculator.swift             # Pure calculation logic
└── Tests/SwiftfulGamificationTests/               # Swift Testing framework tests
```

## Architecture Notes

- Uses Swift 6.1 toolchain
- Tests use Swift Testing framework (not XCTest) - `@Test` attribute and `#expect()` assertions
- All async operations use async/await (not callbacks or Combine)
- Thread safety via @MainActor and Sendable conformance
- SwiftUI integration via @Observable macro

## Implemented Features

### StreakManager
- **Public API**: `StreakManager.swift` (213 lines)
  - `@MainActor` + `@Observable` for SwiftUI integration
  - Lifecycle: `logIn(userId:)`, `logOut()`
  - Event management: `addStreakEvent()`, `getAllStreakEvents()`, `deleteAllStreakEvents()`
  - Freeze management: `addStreakFreeze()`, `useStreakFreeze()`, `getAllStreakFreezes()`
  - Recalculation: `recalculateStreak(userId:)`
  - Auto-freeze consumption (when configured)
  - Remote listener with local persistence
  - Comprehensive analytics tracking (12 events)

### Service Protocols
- **StreakServices**: Container protocol for dependency injection
  - `remote: RemoteStreakService` - Remote data operations
  - `local: LocalStreakPersistence` - Local data storage
- **MockStreakServices**: Mock implementation for testing

### Data Models

#### CurrentStreakData (388 lines)
- Core properties: `currentStreak`, `longestStreak`, `lastEventDate`, `streakStartDate`
- Goal-based: `eventsRequiredPerDay`, `todayEventCount`, `isGoalMet`, `goalProgress`
- Freeze support: `freezesRemaining`, `freezesNeededToSaveStreak`, `canStreakBeSaved`
- Status: `status`, `isStreakActive`, `isStreakAtRisk`, `daysSinceLastEvent`
- Mock factories: `blank()`, `mock()`, `mockActive()`, `mockAtRisk()`, `mockGoalBased()`
- Analytics: `eventParameters`

#### StreakEvent (170 lines)
- Properties: `id`, `timestamp`, `timezone`, `isFreeze`, `freezeId`, `metadata`
- Validation: `isValid`, `isTimestampValid`, `isTimezoneValid`, `isMetadataValid`
- Mock factories: `mock()`, `mock(date:)`, `mock(daysAgo:)`
- Analytics: `eventParameters`

#### StreakFreeze (181 lines)
- Properties: `id`, `streakId`, `earnedDate`, `usedDate`, `expiresAt`
- Status: `isUsed`, `isExpired`, `isAvailable`
- Mock factories: `mockUnused()`, `mockUsed()`, `mockExpired()`
- Analytics: `eventParameters`

#### StreakConfiguration (147 lines)
- Settings: `streakId`, `eventsRequiredPerDay`, `useServerCalculation`, `leewayHours`, `autoConsumeFreeze`
- Computed: `isGoalBasedStreak`, `isStrictMode`, `isTravelFriendly`
- Mock factories: `mockBasic()`, `mockGoalBased()`, `mockLenient()`, `mockTravelFriendly()`, `mockServerCalculation()`

#### StreakStatus (enum)
- Cases: `noEvents`, `active(daysSinceLastEvent:)`, `atRisk`, `broken(daysSinceLastEvent:)`

### Utilities

#### StreakCalculator (225 lines)
- **Pure calculation logic** - no side effects
- Basic mode: 1 event per day = streak continues
- Goal-based mode: N events required per day
- Leeway hours: Grace period around midnight (timezone-aware)
- Auto-freeze consumption: Automatically fill gaps with available freezes
- Returns: `(streak: CurrentStreakData, freezeConsumptions: [FreezeConsumption])`
- Edge cases: "at risk" state, no event today, timezone handling

### Logger Integration
- **GamificationLogger**: Protocol for analytics integration
- **GamificationLogEvent**: Event protocol with `eventName`, `parameters`, `type`
- **GamificationLogType**: Enum with `info`, `analytic`, `warning`, `severe`
- All manager operations tracked with comprehensive events

## Key Implementation Details

### Streak Calculation Logic
1. **Event Grouping**: Groups events by day (timezone-aware)
2. **Goal Qualification**: Filters days that meet `eventsRequiredPerDay` threshold
3. **Current Streak**: Walks backwards from today, checking consecutive days
4. **Leeway Application**: Extends "today" window by configured hours
5. **Freeze Auto-Consumption**: Fills gaps with oldest available freezes (FIFO)
6. **Longest Streak**: Calculates all-time longest consecutive run
7. **Streak Start Date**: Calculated by walking back from today

### Freeze Behavior
- **Auto-Consume**: Enabled by default (`autoConsumeFreeze: true`)
- **FIFO Order**: Oldest freezes consumed first (`earnedDate` sorting)
- **Gap Filling**: Consumes freezes to fill gaps between events
- **Event Creation**: Creates `StreakEvent` with `isFreeze: true` for each consumption
- **Freeze Marking**: Marks freeze as used (`usedDate` set)

### Client vs Server Calculation
- **Client-side** (default): `StreakCalculator` runs locally, full control
- **Server-side**: Triggers remote Cloud Function (requires Firebase deployment)
- Configurable via `StreakConfiguration.useServerCalculation`

### Local Persistence
- Saves `CurrentStreakData` to local storage on every remote update
- Loads saved data on `StreakManager` initialization
- Enables offline functionality and faster app launch

### Analytics Events
**StreakManager Events:**
- `StreakMan_RemoteListener_Start/Success/Fail`
- `StreakMan_SaveLocal_Start/Success/Fail`
- `StreakMan_CalculateStreak_Start/Success/Fail`
- `StreakMan_Freeze_AutoConsumed`

**Event Parameters:**
- All streak data: `current_streak_*` prefix
- All events: `streak_event_*` prefix
- All freezes: `streak_freeze_*` prefix

## Commit Style Guidelines

**CRITICAL: NEVER auto-commit. ONLY commit when the user explicitly says "commit"**

When explicitly asked to commit changes:
- Generate commit messages automatically based on staged changes without additional user confirmation
- Commit all changes in a single commit
- Keep commit messages short - only a few words long
- Do NOT include "Co-Authored-By" or any references to Claude/AI in commit messages
- NEVER commit proactively or automatically - wait for explicit "commit" instruction

### Commit Message Format:
- `[Feature] Add some button` - For new functionality or components
- `[Bug] Fix some bug` - For bug fixes and corrections
- `[Clean] Refactored some code` - For refactoring, cleanup, or code improvements

### Examples:
- `[Feature] Add user dashboard`
- `[Bug] Fix login validation`
- `[Clean] Refactor project manager`
