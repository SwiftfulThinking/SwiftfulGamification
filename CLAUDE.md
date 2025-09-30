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

Based on analysis of SwiftfulAuthenticating, SwiftfulLogging, and SwiftfulPurchasing packages:

**NOTE: The following gamification-specific code examples (UserStreak, GamificationService, etc.) are SAMPLE TEMPLATES to illustrate the pattern. They are NOT actual existing code. Refer to the "Related Packages" section below for real implementation examples.**

```
SwiftfulGamification/ (THIS PACKAGE - Base)
├── Package.swift (NO external dependencies)
├── Sources/SwiftfulGamification/
│   ├── GamificationManager.swift          # Main public API (@MainActor, @Observable)
│   ├── Services/
│   │   ├── GamificationService.swift      # Protocol definition (Sendable)
│   │   └── MockGamificationService.swift  # Mock implementation (actor or @MainActor class)
│   ├── Models/
│   │   ├── UserStreak.swift               # Codable, Sendable model
│   │   ├── StreakFreeze.swift             # Codable, Sendable model
│   │   └── GamificationLogger.swift       # Logger protocol (optional)
│   └── Extensions/
│       └── (utility extensions as needed)
└── Tests/SwiftfulGamificationTests/

SwiftfulGamificationFirebase/ (SEPARATE SPM - Implementation)
├── Package.swift
│   dependencies: [
│       .package(url: "SwiftfulGamification", "1.0.0"..<"2.0.0"),
│       .package(url: "firebase-ios-sdk", "12.0.0"..<"13.0.0")
│   ]
├── Sources/SwiftfulGamificationFirebase/
│   ├── FirebaseGamificationService.swift   # Implements GamificationService
│   └── Extensions/
│       ├── UserStreak+Firebase.swift       # Conversion extensions
│       └── StreakFreeze+Firebase.swift     # Conversion extensions
└── Tests/
```

### Protocol Definition Pattern

**SAMPLE Service Protocol** (`GamificationService.swift` - NOT YET IMPLEMENTED):
```swift
// EXAMPLE TEMPLATE - Adapt this pattern to your actual gamification requirements
public protocol GamificationService: Sendable {
    func getUserStreak(userId: String) async throws -> UserStreak
    func updateStreak(userId: String, streak: UserStreak) async throws
    func getStreakFreezes(userId: String) async throws -> [StreakFreeze]
    func useStreakFreeze(userId: String, freezeId: String) async throws
    func streamUserStreak(userId: String) -> AsyncStream<UserStreak?>
}
```

**For REAL examples of this pattern, see:**
- `AuthService` in `/Users/nicksarno/Documents/documents/GITHUB/SwiftfulAuthenticating/Sources/SwiftfulAuthenticating/Services/AuthService.swift`
- `LogService` in `/Users/nicksarno/Documents/documents/GITHUB/SwiftfulLogging/Sources/SwiftfulLogging/Services/LogService.swift`
- `PurchaseService` in `/Users/nicksarno/Documents/documents/GITHUB/SwiftfulPurchasing/Sources/SwiftfulPurchasing/Services/PurchaseService.swift`

**Key Requirements:**
- `Sendable` conformance for Swift 6 concurrency
- All methods use `async throws` for async operations
- Return abstract types (UserStreak, StreakFreeze), never provider types
- Use `AsyncStream` for reactive data (not Combine publishers)
- No platform-specific types in signatures

### Model Definition Pattern

**SAMPLE Abstract Data Model** (NOT YET IMPLEMENTED):
```swift
// EXAMPLE TEMPLATE - Adapt this pattern to your actual gamification data models
public struct UserStreak: Codable, Sendable, Identifiable {
    public let id: String            // Usually userId
    public let currentStreak: Int
    public let longestStreak: Int
    public let lastActivityDate: Date?
    public let streakStartDate: Date?

    // Computed properties for business logic
    public var isStreakActive: Bool { /* ... */ }

    // Mock factory for testing
    public static func mock(currentStreak: Int = 5) -> Self { /* ... */ }

    // Analytics parameters
    public var eventParameters: [String: Any] { /* ... */ }

    // Public initializer
    public init(id: String, currentStreak: Int, ...) { /* ... */ }
}
```

**For REAL examples of this pattern, see:**
- `UserAuthInfo` in `/Users/nicksarno/Documents/documents/GITHUB/SwiftfulAuthenticating/Sources/SwiftfulAuthenticating/Models/UserAuthInfo.swift`
- `AnyProduct` in `/Users/nicksarno/Documents/documents/GITHUB/SwiftfulPurchasing/Sources/SwiftfulPurchasing/Models/AnyProduct.swift`
- `PurchasedEntitlement` in `/Users/nicksarno/Documents/documents/GITHUB/SwiftfulPurchasing/Sources/SwiftfulPurchasing/Models/PurchasedEntitlement.swift`

**Key Requirements:**
- All properties public with explicit types
- `Codable` for serialization
- `Sendable` for concurrency safety
- Public initializer with all parameters
- Mock factory method: `static func mock() -> Self`
- Event parameters for analytics integration
- CodingKeys with snake_case for API compatibility

### Manager Pattern

**SAMPLE Manager Implementation** (NOT YET IMPLEMENTED):
```swift
// EXAMPLE TEMPLATE - Adapt this pattern to your actual GamificationManager
@MainActor
@Observable
public class GamificationManager {
    private let logger: GamificationLogger?
    private let service: GamificationService  // Protocol injection

    public private(set) var currentStreak: UserStreak?
    private var listener: Task<Void, Error>?

    public init(service: GamificationService, logger: GamificationLogger? = nil) {
        self.service = service
        self.logger = logger
    }

    // Public API methods delegate to service
    public func getUserStreak(userId: String) async throws -> UserStreak {
        logger?.trackEvent(event: Event.getStreakStart)
        do {
            let streak = try await service.getUserStreak(userId: userId)
            logger?.trackEvent(event: Event.getStreakSuccess(streak: streak))
            return streak
        } catch {
            logger?.trackEvent(event: Event.getStreakFail(error: error))
            throw error
        }
    }

    // Event tracking enum
    enum Event: GamificationLogEvent {
        case getStreakStart
        case getStreakSuccess(streak: UserStreak)
        case getStreakFail(error: Error)

        var eventName: String { /* ... */ }
        var parameters: [String: Any]? { /* ... */ }
        var type: GamificationLogType { /* ... */ }
    }
}
```

**For REAL examples of this pattern, see:**
- `AuthManager` in `/Users/nicksarno/Documents/documents/GITHUB/SwiftfulAuthenticating/Sources/SwiftfulAuthenticating/AuthManager.swift`
- `LogManager` in `/Users/nicksarno/Documents/documents/GITHUB/SwiftfulLogging/Sources/SwiftfulLogging/LogManager.swift`
- `PurchaseManager` in `/Users/nicksarno/Documents/documents/GITHUB/SwiftfulPurchasing/Sources/SwiftfulPurchasing/PurchaseManager.swift`

**Key Requirements:**
- `@MainActor` isolation for UI safety
- `@Observable` for SwiftUI integration
- Dependency injection via initializer
- Optional logger for analytics
- Event enum conforming to logger protocol
- Comprehensive event tracking (start, success, fail)

### Mock Implementation Pattern

**SAMPLE Mock Service** (NOT YET IMPLEMENTED):
```swift
// EXAMPLE TEMPLATE - Adapt this pattern to your actual MockGamificationService
@MainActor
public class MockGamificationService: GamificationService {
    @Published private(set) var currentStreak: UserStreak?

    public init(streak: UserStreak? = nil) {
        self.currentStreak = streak
    }

    public func getUserStreak(userId: String) async throws -> UserStreak {
        guard let streak = currentStreak else {
            throw URLError(.badURL)
        }
        return streak
    }

    public func streamUserStreak(userId: String) -> AsyncStream<UserStreak?> {
        AsyncStream { continuation in
            Task {
                for await value in $currentStreak.values {
                    continuation.yield(value)
                }
            }
        }
    }

    public func updateStreak(userId: String, streak: UserStreak) async throws {
        currentStreak = streak
    }
}
```

**For REAL examples of this pattern, see:**
- `MockAuthService` in `/Users/nicksarno/Documents/documents/GITHUB/SwiftfulAuthenticating/Sources/SwiftfulAuthenticating/Services/MockAuthService.swift`
- `MockPurchaseService` in `/Users/nicksarno/Documents/documents/GITHUB/SwiftfulPurchasing/Sources/SwiftfulPurchasing/Services/MockPurchaseService.swift`

**Key Requirements:**
- Use `@Published` for reactive state
- AsyncStream from Combine publisher for listeners
- Maintain stateful behavior (updates persist)
- No external dependencies
- Always succeeds (useful for UI testing)

### Firebase Implementation Pattern (in separate package)

**SAMPLE Firebase Service** (FOR SwiftfulGamificationFirebase PACKAGE - NOT YET IMPLEMENTED):
```swift
// EXAMPLE TEMPLATE - This will go in the separate SwiftfulGamificationFirebase package
import SwiftfulGamification
import FirebaseFirestore

public struct FirebaseGamificationService: GamificationService {
    private var collection: CollectionReference {
        Firestore.firestore().collection("user_streaks")
    }

    public init() { }

    public func getUserStreak(userId: String) async throws -> UserStreak {
        let docRef = collection.document(userId)
        let snapshot = try await docRef.getDocument()

        guard let data = snapshot.data() else {
            throw URLError(.badServerResponse)
        }

        return UserStreak(firestoreData: data)  // Extension initializer
    }

    public func streamUserStreak(userId: String) -> AsyncStream<UserStreak?> {
        AsyncStream { continuation in
            let listener = collection.document(userId).addSnapshotListener { snapshot, error in
                if let data = snapshot?.data() {
                    continuation.yield(UserStreak(firestoreData: data))
                } else {
                    continuation.yield(nil)
                }
            }

            continuation.onTermination = { @Sendable _ in
                listener.remove()
            }
        }
    }
}
```

**SAMPLE Conversion Extension** (FOR SwiftfulGamificationFirebase PACKAGE - NOT YET IMPLEMENTED):
```swift
// EXAMPLE TEMPLATE - This extension would be in the Firebase package
extension UserStreak {
    init(firestoreData: [String: Any]) {
        self.init(
            id: firestoreData["id"] as? String ?? "",
            currentStreak: firestoreData["current_streak"] as? Int ?? 0,
            longestStreak: firestoreData["longest_streak"] as? Int ?? 0,
            lastActivityDate: (firestoreData["last_activity_date"] as? Timestamp)?.dateValue(),
            streakStartDate: (firestoreData["streak_start_date"] as? Timestamp)?.dateValue()
        )
    }

    var firestoreData: [String: Any] {
        [
            "id": id,
            "current_streak": currentStreak,
            "longest_streak": longestStreak,
            "last_activity_date": lastActivityDate.map { Timestamp(date: $0) },
            "streak_start_date": streakStartDate.map { Timestamp(date: $0) }
        ].compactMapValues { $0 }
    }
}
```

**For REAL examples of this pattern, see:**
- `FirebaseAuthService` in `/Users/nicksarno/Documents/documents/GITHUB/SwiftfulAuthenticatingFirebase/Sources/SwiftfulAuthenticatingFirebase/FirebaseAuthService.swift`
- `UserAuthInfo+Firebase.swift` in `/Users/nicksarno/Documents/documents/GITHUB/SwiftfulAuthenticatingFirebase/Sources/SwiftfulAuthenticatingFirebase/UserAuthInfo+Firebase.swift`
- `FirebaseAnalyticsService` in `/Users/nicksarno/Documents/documents/GITHUB/SwiftfulLoggingFirebaseAnalytics/Sources/SwiftfulLoggingFirebaseAnalytics/FirebaseAnalyticsService.swift`
- `RevenueCatPurchaseService` in `/Users/nicksarno/Documents/documents/GITHUB/SwiftfulPurchasingRevenueCat/Sources/SwiftfulPurchasingRevenueCat/RevenueCatPurchaseService.swift`

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

### Logger Protocol Pattern (Optional but Recommended)

**SAMPLE Logger Protocols** (NOT YET IMPLEMENTED):
```swift
// EXAMPLE TEMPLATE - Adapt this pattern if you want analytics integration
@MainActor
public protocol GamificationLogger {
    func trackEvent(event: GamificationLogEvent)
    func addUserProperties(dict: [String: Any], isHighPriority: Bool)
}

public protocol GamificationLogEvent {
    var eventName: String { get }
    var parameters: [String: Any]? { get }
    var type: GamificationLogType { get }
}

public enum GamificationLogType: Int, CaseIterable, Sendable {
    case info = 0
    case analytic = 1
    case warning = 2
    case severe = 3
}
```

**For REAL examples of this pattern, see:**
- `AuthLogger`, `AuthLogEvent`, `AuthLogType` in `/Users/nicksarno/Documents/documents/GITHUB/SwiftfulAuthenticating/Sources/SwiftfulAuthenticating/Models/PurchaseLogger.swift`
- `PurchaseLogger`, `PurchaseLogEvent`, `PurchaseLogType` in `/Users/nicksarno/Documents/documents/GITHUB/SwiftfulPurchasing/Sources/SwiftfulPurchasing/Models/PurchaseLogger.swift`

### Integration in SwiftfulStarterProject

**SAMPLE Integration Examples** (NOT YET IMPLEMENTED - These show how you would integrate once the package is built):

**1. Add to Dependencies.swift**:
```swift
// EXAMPLE TEMPLATE - This is how you would integrate in SwiftfulStarterProject
// In Dependencies.init(config:)
let gamificationManager: GamificationManager

switch config {
case .mock(isSignedIn: let isSignedIn):
    gamificationManager = GamificationManager(
        service: MockGamificationService(streak: .mock()),
        logger: logManager
    )

case .dev, .prod:
    gamificationManager = GamificationManager(
        service: FirebaseGamificationService(),
        logger: logManager
    )
}

container.register(GamificationManager.self, service: gamificationManager)
```

**2. Add to CoreInteractor**:
```swift
// EXAMPLE TEMPLATE - This is how you would add to CoreInteractor
@MainActor
struct CoreInteractor: GlobalInteractor {
    private let gamificationManager: GamificationManager

    init(container: DependencyContainer) {
        self.gamificationManager = container.resolve(GamificationManager.self)!
    }

    var currentStreak: UserStreak? {
        gamificationManager.currentStreak
    }

    func updateUserStreak(userId: String) async throws {
        try await gamificationManager.checkAndUpdateStreak(userId: userId)
    }
}
```

**3. Create type alias**:
```swift
// EXAMPLE TEMPLATE - SwiftfulGamification+Alias.swift in SwiftfulStarterProject
import SwiftfulGamification
import SwiftfulGamificationFirebase

typealias UserStreak = SwiftfulGamification.UserStreak
typealias GamificationManager = SwiftfulGamification.GamificationManager
typealias MockGamificationService = SwiftfulGamification.MockGamificationService
typealias FirebaseGamificationService = SwiftfulGamificationFirebase.FirebaseGamificationService

// Conform LogManager to GamificationLogger
extension LogManager: @retroactive GamificationLogger {
    public func trackEvent(event: any GamificationLogEvent) {
        trackEvent(eventName: event.eventName, parameters: event.parameters, type: event.type.type)
    }
}
```

**For REAL examples of integration, see:**
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

- `Package.swift` - SPM manifest with NO external dependencies
- `Sources/SwiftfulGamification/` - Main library code
  - `GamificationManager.swift` - Public API manager class
  - `Services/` - Protocol definitions and mock implementations
  - `Models/` - Codable, Sendable data models
  - `Extensions/` - Utility extensions
- `Tests/SwiftfulGamificationTests/` - Test suite using Swift Testing framework

## Architecture Notes

- Uses Swift 6.1 toolchain
- Tests use Swift Testing framework (not XCTest) - `@Test` attribute and `#expect()` assertions
- All async operations use async/await (not callbacks or Combine)
- Thread safety via @MainActor and Sendable conformance
- SwiftUI integration via @Observable macro

## Commit Style Guidelines

**Note: Only apply these rules when explicitly asked to "commit"**

When explicitly asked to commit changes:
- Generate commit messages automatically based on staged changes without additional user confirmation
- Commit all changes in a single commit
- Keep commit messages short - only a few words long
- Do NOT include "Co-Authored-By" or any references to Claude/AI in commit messages

### Commit Message Format:
- `[Feature] Add some button` - For new functionality or components
- `[Bug] Fix some bug` - For bug fixes and corrections
- `[Clean] Refactored some code` - For refactoring, cleanup, or code improvements

### Examples:
- `[Feature] Add user dashboard`
- `[Bug] Fix login validation`
- `[Clean] Refactor project manager`
