# SwiftfulGamification Implementation Guide

**Status:** Ready for Step-by-Step Implementation
**Created:** 2025-09-30
**Architecture Pattern:** SwiftfulThinking Provider Pattern
**Estimated Phases:** 5 major phases with 83 checkpoints

**📖 See Also:** `IMPLEMENTATION-ADDENDUM.md` for detailed Goal-Based Streaks & Server-Side Calculation updates

---

## Table of Contents

1. [Overview](#overview)
2. [Implementation Phases](#implementation-phases)
3. [Phase 1: Foundation Models](#phase-1-foundation-models)
4. [Phase 2: Core Service Protocol](#phase-2-core-service-protocol)
5. [Phase 3: Manager Implementation](#phase-3-manager-implementation)
6. [Phase 4: Mock Service](#phase-4-mock-service)
7. [Phase 5: Testing & Validation](#phase-5-testing--validation)
8. [Critical Edge Cases Checklist](#critical-edge-cases-checklist)
9. [Implementation Dependencies](#implementation-dependencies)

---

## Overview

This guide provides a step-by-step implementation plan for SwiftfulGamification SPM package. The implementation is broken into sequential phases that MUST be completed in order due to dependencies.

### Why This Order?

1. **Models First:** All types must be defined before they can be used in protocols
2. **Protocol Second:** Service protocol defines the contract before implementation
3. **Manager Third:** Manager depends on models and protocol
4. **Mock Fourth:** Mock implementation tests the entire contract
5. **Testing Last:** Full integration testing ensures everything works together

### Key Constraints

- ✅ Zero external dependencies (base package)
- ✅ All types Codable and Sendable
- ✅ All async operations use async/await
- ✅ AsyncStream for reactive data (not Combine in protocols)
- ✅ FileManager for local storage (protocol-based)
- ✅ Support for offline-first architecture
- ✅ Timezone-safe calculations using Calendar API
- ✅ Mock factory methods for all models
- ✅ Goal-based streaks (eventsRequiredPerDay) in v1.0
- ✅ Server-side calculation config (client-side implementation with toggle)

---

## Implementation Phases

### Phase Overview

| Phase | Description | Files Created/Modified | Checkpoints |
|-------|-------------|------------------------|-------------|
| 1 | Foundation Models | 7 new model files | 25 |
| 2 | Service Protocol | 1 protocol file | 12 |
| 3 | Manager Implementation | 1 manager file | 18 |
| 4 | Mock Service | 1 mock service file | 10 |
| 5 | Testing & Validation | Test files + utilities | 18 |

**Total Checkpoints:** 83

---

## Phase 1: Foundation Models

**Goal:** Create all data models with complete Codable, Sendable, mock support

### Files to Create/Modify

```
Sources/SwiftfulGamification/Models/
├── GamificationLogger.swift (✅ EXISTS - verify completeness)
├── Event.swift (NEW)
├── EventValue.swift (NEW)
├── UserStreak.swift (NEW)
├── StreakFreeze.swift (NEW)
├── StreakStatus.swift (NEW)
├── GamificationError.swift (NEW)
└── StreakConfiguration.swift (NEW) - Goal-based + server calculation config
```

---

### 1.1 EventValue Enum ✅

**File:** `Sources/SwiftfulGamification/Models/EventValue.swift`

**Requirements:**
- ✅ Codable conformance
- ✅ Sendable conformance
- ✅ Equatable conformance (for testing)
- ✅ Support String, Bool, Int only (Firestore-compatible)
- ✅ Custom CodingKeys for type discrimination

**Critical Details:**
```swift
public enum EventValue: Codable, Sendable, Equatable {
    case string(String)
    case bool(Bool)
    case int(Int)

    // MUST implement custom encoding/decoding for type discrimination
    // Firebase needs to store: { "type": "string", "value": "hello" }
}
```

**Edge Cases:**
- ❗ Decoding invalid type should throw
- ❗ Empty strings are valid
- ❗ Bool values must preserve true/false exactly

**Checkpoints:**
1. ☐ Define enum cases (string, bool, int)
2. ☐ Add Codable conformance with type discrimination
3. ☐ Add Sendable conformance
4. ☐ Add Equatable conformance
5. ☐ Test encoding/decoding roundtrip

---

### 1.2 Event Model ✅

**File:** `Sources/SwiftfulGamification/Models/Event.swift`

**Requirements:**
- ✅ Identifiable conformance (id: String)
- ✅ Codable conformance
- ✅ Sendable conformance
- ✅ All fields required (no optionals)
- ✅ Mock factory method
- ✅ Event parameters for analytics

**Critical Details:**
```swift
public struct Event: Identifiable, Codable, Sendable, Equatable {
    public let id: String                          // Auto-generated UUID
    public let timestamp: Date                     // UTC timestamp
    public let timezone: String                    // TimeZone identifier (e.g., "America/New_York")
    public let metadata: [String: EventValue]      // Custom data (REQUIRED, not optional)

    public init(
        id: String = UUID().uuidString,            // Default to UUID
        timestamp: Date = Date(),                  // Default to now
        timezone: String = TimeZone.current.identifier,  // Default to current
        metadata: [String: EventValue]
    ) { ... }

    public enum CodingKeys: String, CodingKey {
        case id = "id"
        case timestamp = "timestamp"
        case timezone = "timezone"
        case metadata = "metadata"
    }

    public static func mock(...) -> Self { ... }
    public var eventParameters: [String: Any] { ... }
}
```

**Edge Cases:**
- ❗ ID validation: Must be non-empty
- ❗ Timestamp validation: Cannot be in future, not older than 1 year (in client validation)
- ❗ Timezone validation: Must be valid TimeZone identifier
- ❗ Metadata validation: Can be empty dict, but not nil
- ❗ Metadata keys: Validate no special characters (safe for Firestore field names)

**Checkpoints:**
6. ☐ Define struct with all required fields
7. ☐ Add public initializer with defaults
8. ☐ Add CodingKeys (snake_case for Firestore)
9. ☐ Implement mock factory method (multiple variations)
10. ☐ Implement eventParameters for analytics
11. ☐ Add validation helpers (isTimestampValid, isTimezoneValid)
12. ☐ Test encoding/decoding with complex metadata

---

### 1.3 UserStreak Model ✅

**File:** `Sources/SwiftfulGamification/Models/UserStreak.swift`

**Requirements:**
- ✅ Identifiable conformance (id = userId)
- ✅ Codable conformance
- ✅ Sendable conformance
- ✅ All fields except id are optional (migration-safe per Decision #15)
- ✅ Computed properties for business logic
- ✅ Mock factory method
- ✅ Event parameters for analytics

**Critical Details:**
```swift
public struct UserStreak: Identifiable, Codable, Sendable, Equatable {
    public let id: String                          // userId (REQUIRED)
    public let streakId: String?                   // e.g., "workout" (optional for migration)
    public let currentStreak: Int?                 // Current streak count (optional)
    public let longestStreak: Int?                 // All-time best (optional)
    public let lastEventDate: Date?                // Last event timestamp UTC (optional)
    public let lastEventTimezone: String?          // Last event timezone (optional)
    public let streakStartDate: Date?              // When current streak started (optional)
    public let totalEvents: Int?                   // Total events logged (optional)
    public let freezesRemaining: Int?              // Available freezes (optional)
    public let createdAt: Date?                    // First ever event (optional)
    public let updatedAt: Date?                    // Last modified (optional)
    public let eventsRequiredPerDay: Int?          // Goal-based: events needed per day (optional, default 1)
    public let todayEventCount: Int?               // Goal-based: events logged today (optional)

    // COMPUTED PROPERTIES (not stored)
    public var isStreakActive: Bool { ... }        // Is streak still alive?
    public var isStreakAtRisk: Bool { ... }        // Last event was yesterday?
    public var daysSinceLastEvent: Int? { ... }    // Days since last event
    public var isGoalMet: Bool { ... }             // Goal-based: today's goal met?
    public var goalProgress: Double { ... }        // Goal-based: progress toward today's goal (0.0-1.0)

    public init(id: String, ...) { ... }           // All params except id optional
    public enum CodingKeys: String, CodingKey { ... }  // snake_case
    public static func mock(...) -> Self { ... }
    public var eventParameters: [String: Any] { ... }
}
```

**Edge Cases:**
- ❗ currentStreak can be 0 (valid)
- ❗ longestStreak >= currentStreak always
- ❗ lastEventDate can be nil (no events yet)
- ❗ All Int values must be >= 0
- ❗ eventsRequiredPerDay defaults to 1 (basic streak)
- ❗ eventsRequiredPerDay > 1 enables goal-based mode
- ❗ todayEventCount resets at midnight (timezone-aware)
- ❗ isGoalMet logic: todayEventCount >= eventsRequiredPerDay
- ❗ goalProgress: min(todayEventCount / eventsRequiredPerDay, 1.0)
- ❗ isStreakActive logic: Check leeway hours (requires additional context)
- ❗ Handle timezone conversion for daysSinceLastEvent

**Checkpoints:**
13. ☐ Define struct with all optional fields (except id)
14. ☐ Add public initializer (all params except id optional)
15. ☐ Add CodingKeys with snake_case
16. ☐ Implement computed property: isStreakActive
17. ☐ Implement computed property: isStreakAtRisk
18. ☐ Implement computed property: daysSinceLastEvent
19. ☐ Implement computed property: isGoalMet
20. ☐ Implement computed property: goalProgress
21. ☐ Implement mock factory with multiple variations
22. ☐ Implement eventParameters for analytics
23. ☐ Add validation helpers (validateIntegrity)

---

### 1.4 StreakConfiguration Model ✅

**File:** `Sources/SwiftfulGamification/Models/StreakConfiguration.swift`

**Requirements:**
- ✅ Codable conformance
- ✅ Sendable conformance
- ✅ Equatable conformance
- ✅ Contains all streak behavior configuration
- ✅ Mock factory method

**Critical Details:**
```swift
public struct StreakConfiguration: Codable, Sendable, Equatable {
    // MARK: - Goal-Based Configuration
    public let eventsRequiredPerDay: Int           // Default: 1 (basic streak), >1 enables goal mode

    // MARK: - Server-Side Calculation Configuration
    public let useServerCalculation: Bool          // Default: false (client-side)

    // MARK: - Grace Period Configuration
    public let leewayHours: Int                    // Default: 0 (strict), ±X hours around midnight

    // MARK: - Freeze Configuration
    public let autoConsumeFreeze: Bool             // Default: true (auto-consume on break)

    public init(
        eventsRequiredPerDay: Int = 1,
        useServerCalculation: Bool = false,
        leewayHours: Int = 0,
        autoConsumeFreeze: Bool = true
    ) {
        // Validation
        precondition(eventsRequiredPerDay >= 1, "eventsRequiredPerDay must be >= 1")
        precondition(leewayHours >= 0, "leewayHours must be >= 0")
        precondition(leewayHours <= 24, "leewayHours must be <= 24")

        self.eventsRequiredPerDay = eventsRequiredPerDay
        self.useServerCalculation = useServerCalculation
        self.leewayHours = leewayHours
        self.autoConsumeFreeze = autoConsumeFreeze
    }

    public enum CodingKeys: String, CodingKey {
        case eventsRequiredPerDay = "events_required_per_day"
        case useServerCalculation = "use_server_calculation"
        case leewayHours = "leeway_hours"
        case autoConsumeFreeze = "auto_consume_freeze"
    }

    public static func mock(
        eventsRequiredPerDay: Int = 1,
        useServerCalculation: Bool = false,
        leewayHours: Int = 0,
        autoConsumeFreeze: Bool = true
    ) -> Self {
        StreakConfiguration(
            eventsRequiredPerDay: eventsRequiredPerDay,
            useServerCalculation: useServerCalculation,
            leewayHours: leewayHours,
            autoConsumeFreeze: autoConsumeFreeze
        )
    }

    // MARK: - Computed Properties
    public var isGoalBasedStreak: Bool {
        eventsRequiredPerDay > 1
    }

    public var isStrictMode: Bool {
        leewayHours == 0
    }

    public var isTravelFriendly: Bool {
        leewayHours >= 12
    }
}
```

**Edge Cases:**
- ❗ eventsRequiredPerDay = 1 is basic streak mode
- ❗ eventsRequiredPerDay > 1 enables goal-based mode
- ❗ eventsRequiredPerDay must be >= 1 (validated)
- ❗ leewayHours valid range: 0-24 (validated)
- ❗ useServerCalculation = false means client-side only
- ❗ useServerCalculation = true requires Firebase Cloud Function deployed

**Checkpoints:**
24. ☐ Define struct with all configuration fields
25. ☐ Add public initializer with defaults
26. ☐ Add validation in initializer (preconditions)
27. ☐ Add CodingKeys with snake_case
28. ☐ Implement computed properties (isGoalBasedStreak, isStrictMode, isTravelFriendly)
29. ☐ Implement mock factory
30. ☐ Test validation (invalid values throw)

---

### 1.5 StreakFreeze Model ✅

**File:** `Sources/SwiftfulGamification/Models/StreakFreeze.swift`

**Requirements:**
- ✅ Identifiable conformance
- ✅ Codable conformance
- ✅ Sendable conformance
- ✅ All fields except id optional (migration-safe)
- ✅ Mock factory method
- ✅ Event parameters for analytics

**Critical Details:**
```swift
public struct StreakFreeze: Identifiable, Codable, Sendable, Equatable {
    public let id: String                          // Freeze ID (REQUIRED)
    public let userId: String?                     // Owner (optional)
    public let streakId: String?                   // Which streak (optional)
    public let earnedDate: Date?                   // When earned (optional)
    public let usedDate: Date?                     // When consumed (nil if unused)
    public let expiresAt: Date?                    // Never expires per Decision #3A

    // COMPUTED
    public var isUsed: Bool { usedDate != nil }
    public var isExpired: Bool {
        // Always false per Decision #3A (never expire)
        // But keep logic for future flexibility
        false
    }

    public init(id: String, ...) { ... }
    public enum CodingKeys: String, CodingKey { ... }
    public static func mock(...) -> Self { ... }
    public var eventParameters: [String: Any] { ... }
}
```

**Edge Cases:**
- ❗ usedDate must be > earnedDate if both present
- ❗ expiresAt must be > earnedDate if present
- ❗ Freeze can be earned but never used (valid state)

**Checkpoints:**
31. ☐ Define struct with all fields (only id required)
32. ☐ Add public initializer
33. ☐ Add CodingKeys
34. ☐ Implement computed properties (isUsed, isExpired)
35. ☐ Implement mock factory
36. ☐ Implement eventParameters
37. ☐ Add validation helpers

---

### 1.6 StreakStatus Enum ✅

**File:** `Sources/SwiftfulGamification/Models/StreakStatus.swift`

**Requirements:**
- ✅ Sendable conformance
- ✅ Equatable conformance
- ✅ Represents current streak state
- ✅ Used in calculation logic

**Critical Details:**
```swift
public enum StreakStatus: Sendable, Equatable {
    case noEvents                                  // Never logged an event
    case active(daysSinceLastEvent: Int)          // Streak alive (0 or 1 day)
    case atRisk                                    // Last event yesterday, today not logged
    case broken(daysSinceLastEvent: Int)          // Streak broken (2+ days)
    case canExtendWithLeeway                       // Within leeway window
}
```

**Edge Cases:**
- ❗ active(0) means event logged today
- ❗ active(1) means last event yesterday (can still extend)
- ❗ atRisk is special case of active(1) when approaching midnight
- ❗ canExtendWithLeeway requires leeway hours context

**Checkpoints:**
38. ☐ Define enum cases
39. ☐ Add Sendable conformance
40. ☐ Add Equatable conformance
41. ☐ Add helper methods (isActive, needsAction, etc.)

---

### 1.7 GamificationError Enum ✅

**File:** `Sources/SwiftfulGamification/Models/GamificationError.swift`

**Requirements:**
- ✅ Error conformance
- ✅ LocalizedError conformance (user-facing messages)
- ✅ Sendable conformance
- ✅ Covers all error scenarios

**Critical Details:**
```swift
public enum GamificationError: Error, LocalizedError, Sendable {
    // Validation errors
    case invalidStreakId(String)                   // Regex validation failed
    case invalidTimestamp(Date)                    // Future or too old
    case invalidTimezone(String)                   // Not a valid identifier
    case invalidMetadata(reason: String)           // Invalid metadata keys/values

    // Business logic errors
    case noEventsRecorded                          // Can't calculate streak without events
    case noStreakFound                             // userId+streakId not found
    case freezeNotAvailable                        // No freezes remaining
    case freezeAlreadyUsed(freezeId: String)      // Freeze already consumed

    // System errors
    case cachingFailed(Error)                      // FileManager error
    case decodingFailed(Error)                     // JSON decode error

    public var errorDescription: String? { ... }   // User-facing messages
    public var failureReason: String? { ... }
    public var recoverySuggestion: String? { ... }
}
```

**Edge Cases:**
- ❗ All errors should have clear user-facing messages
- ❗ Include underlying error in wrapped cases
- ❗ Distinguish between user errors and system errors

**Checkpoints:**
42. ☐ Define all error cases
43. ☐ Implement LocalizedError conformance
44. ☐ Add Sendable conformance
45. ☐ Write clear error messages
46. ☐ Add helper methods (isRecoverable, etc.)

---

### 1.8 Verify GamificationLogger ✅

**File:** `Sources/SwiftfulGamification/Models/GamificationLogger.swift` (EXISTS)

**Verify:**
- ✅ GamificationLogger protocol (@MainActor)
- ✅ GamificationLogEvent protocol
- ✅ GamificationLogType enum
- ✅ All Sendable where required

**Checkpoints:**
47. ☐ Verify logger protocol is complete
48. ☐ Ensure consistent with AuthLogger pattern

---

## Phase 2: Core Service Protocol

**Goal:** Define the complete service contract that both Mock and Firebase will implement

### Files to Create/Modify

```
Sources/SwiftfulGamification/Services/
└── GamificationService.swift (EXISTS - needs complete API)
```

---

### 2.1 Complete GamificationService Protocol ✅

**File:** `Sources/SwiftfulGamification/Services/GamificationService.swift`

**Requirements:**
- ✅ Sendable conformance (@MainActor NOT allowed on protocol - implementations choose)
- ✅ All methods async throws
- ✅ AsyncStream for reactive data
- ✅ Return abstract types only (no Firebase types)
- ✅ Support offline-first with cache methods
- ✅ All CRUD operations for streaks, events, freezes

**Critical API Methods:**

```swift
public protocol GamificationService: Sendable {

    // MARK: - Configuration
    var streakId: String { get }                   // Which streak this service handles
    var configuration: StreakConfiguration { get } // Behavior configuration (goal-based, server calc, leeway, etc.)

    // MARK: - Cache (Synchronous - FileManager based)
    func getCachedStreak() -> UserStreak?
    func setCachedStreak(_ streak: UserStreak)
    func clearCache()

    // MARK: - Streak Operations
    func getStreak(userId: String) async throws -> UserStreak
    func updateStreak(userId: String, streak: UserStreak) async throws
    func deleteAllEventsAndResetStreak(userId: String) async throws  // Decision #16

    // MARK: - Event Operations
    func logEvent(userId: String, event: Event) async throws -> UserStreak  // Returns updated streak
    func getEvents(userId: String, limit: Int?) async throws -> [Event]
    func getRecentEvents(userId: String, days: Int) async throws -> [Event]
    func importEvents(userId: String, events: [Event]) async throws  // Decision #5
    func deleteEvent(userId: String, eventId: String) async throws

    // MARK: - Freeze Operations
    func getFreezesRemaining(userId: String) async throws -> Int
    func addStreakFreeze(userId: String) async throws                // Decision #3B
    func consumeStreakFreeze(userId: String) async throws -> Int     // Returns remaining, Decision #3C
    func getFreezesHistory(userId: String) async throws -> [StreakFreeze]

    // MARK: - Reactive Streams (AsyncStream)
    func streamStreak(userId: String) -> AsyncStream<UserStreak?>
    func streamEvents(userId: String) -> AsyncStream<[Event]>

    // MARK: - Calculation Helpers (may be overridden by server calculation)
    func calculateStreak(
        events: [Event],
        configuration: StreakConfiguration,
        currentDate: Date,
        timezone: TimeZone
    ) -> UserStreak

    func getStreakStatus(
        streak: UserStreak,
        configuration: StreakConfiguration,
        currentDate: Date
    ) -> StreakStatus

    // MARK: - Goal-Based Helpers
    func getTodayEventCount(events: [Event], timezone: TimeZone, currentDate: Date) -> Int
}
```

**Edge Cases to Document:**
- ❗ logEvent: What if event already exists for that day?
- ❗ logEvent: Goal-based mode - increment todayEventCount
- ❗ getEvents: If limit is nil, return ALL events (could be large)
- ❗ importEvents: Must maintain event ordering by timestamp
- ❗ consumeStreakFreeze: Throws if no freezes available
- ❗ streamStreak: Must emit nil when streak doesn't exist yet
- ❗ calculateStreak: Must handle empty events array
- ❗ calculateStreak: Goal-based mode uses eventsRequiredPerDay
- ❗ calculateStreak: Server calculation (if enabled) via Cloud Function
- ❗ getTodayEventCount: Timezone-aware day boundaries
- ❗ Cache methods: Thread-safe (FileManager operations)

**Checkpoints:**
49. ☐ Define protocol with Sendable conformance
50. ☐ Add streakId and configuration properties
51. ☐ Add cache methods (synchronous)
52. ☐ Add streak CRUD methods
53. ☐ Add event methods (log, get, import, delete)
54. ☐ Add freeze methods
55. ☐ Add AsyncStream methods
56. ☐ Add calculation helper methods (with configuration)
57. ☐ Add goal-based helper methods
58. ☐ Document all edge cases in comments
59. ☐ Verify no Firebase types in signatures

---

## Phase 3: Manager Implementation

**Goal:** Implement the public-facing GamificationManager with full business logic

### Files to Modify

```
Sources/SwiftfulGamification/
└── GamificationManager.swift (EXISTS - needs complete implementation)
```

---

### 3.1 GamificationManager Core ✅

**File:** `Sources/SwiftfulGamification/GamificationManager.swift`

**Requirements:**
- ✅ @MainActor isolation
- ✅ @Observable macro
- ✅ Dependency injection (service + logger)
- ✅ Public cached state properties
- ✅ Private listener management
- ✅ Comprehensive event tracking

**Critical Structure:**

```swift
@MainActor
@Observable
public class GamificationManager {
    // MARK: - Dependencies
    private let logger: GamificationLogger?
    private let service: GamificationService
    private let leewayHours: Int                   // Decision #4
    private let autoConsumeFreeze: Bool            // Decision #3C

    // MARK: - Published State (Observable)
    public private(set) var currentStreak: UserStreak?
    public private(set) var recentEvents: [Event] = []
    public private(set) var freezesRemaining: Int = 0
    public private(set) var isSyncInProgress: Bool = false  // Decision #8

    // MARK: - Private State
    private var streakListener: Task<Void, Error>?
    private var eventsListener: Task<Void, Error>?
    private var callbacks: Callbacks?

    // MARK: - Initialization
    public init(
        service: GamificationService,
        leewayHours: Int = 0,                      // Default 0 (strict)
        autoConsumeFreeze: Bool = true,            // Default auto-consume
        logger: GamificationLogger? = nil
    ) {
        self.service = service
        self.leewayHours = leewayHours
        self.autoConsumeFreeze = autoConsumeFreeze
        self.logger = logger

        // Load from cache immediately (synchronous)
        self.currentStreak = service.getCachedStreak()

        // Start listeners
        addListeners()
    }

    // MARK: - Public API (all methods implemented in Phase 3.2-3.6)
    // ... see sections below
}
```

**Edge Cases:**
- ❗ Init must be synchronous (load cache instantly)
- ❗ Listeners must be cancelled on deinit
- ❗ All public methods must track events (start, success, fail)
- ❗ isSyncInProgress must be thread-safe

**Checkpoints:**
50. ☐ Define class with @MainActor and @Observable
51. ☐ Add all dependencies (service, logger, config)
52. ☐ Add all published state properties
53. ☐ Implement initializer (load cache, start listeners)
54. ☐ Add deinit to cancel listeners

---

### 3.2 Callbacks Configuration ✅

**Decision #9:** Developer configures async callbacks

```swift
// MARK: - Callbacks
public struct Callbacks {
    public let onStreakBroken: ((Int) async -> Void)?           // previousStreak
    public let onFreezeConsumed: ((Int) async -> Void)?         // remaining
    public let onStreakAtRisk: (() async -> Void)?

    public init(
        onStreakBroken: ((Int) async -> Void)? = nil,
        onFreezeConsumed: ((Int) async -> Void)? = nil,
        onStreakAtRisk: (() async -> Void)? = nil
    ) { ... }
}

public func configureCallbacks(
    onStreakBroken: ((Int) async -> Void)? = nil,
    onFreezeConsumed: ((Int) async -> Void)? = nil,
    onStreakAtRisk: (() async -> Void)? = nil
) {
    self.callbacks = Callbacks(
        onStreakBroken: onStreakBroken,
        onFreezeConsumed: onFreezeConsumed,
        onStreakAtRisk: onStreakAtRisk
    )
}
```

**Checkpoints:**
55. ☐ Define Callbacks struct
56. ☐ Implement configureCallbacks method
57. ☐ Add callback invocation helpers

---

### 3.3 Listener Management ✅

```swift
private func addListeners() {
    // Streak listener
    streakListener?.cancel()
    streakListener = Task {
        for await value in service.streamStreak(userId: getUserId()) {
            handleStreakUpdate(value)
        }
    }

    // Events listener (optional, for UI)
    eventsListener?.cancel()
    eventsListener = Task {
        for await value in service.streamEvents(userId: getUserId()) {
            handleEventsUpdate(value)
        }
    }
}

private func handleStreakUpdate(_ streak: UserStreak?) {
    let previous = currentStreak
    currentStreak = streak

    // Update cache
    if let streak {
        service.setCachedStreak(streak)
    }

    // Check for streak break
    if let prev = previous, let curr = streak {
        if curr.currentStreak ?? 0 < prev.currentStreak ?? 0 {
            Task {
                await callbacks?.onStreakBroken?(prev.currentStreak ?? 0)
            }
        }
    }

    // Log event
    logger?.trackEvent(event: Event.streakUpdated(streak: streak))
}
```

**Edge Cases:**
- ❗ Listeners must restart on userId change
- ❗ Handle nil streak gracefully (not created yet)
- ❗ Detect streak breaks vs. streak extends
- ❗ Callbacks must be async-safe

**Checkpoints:**
58. ☐ Implement addListeners()
59. ☐ Implement handleStreakUpdate()
60. ☐ Implement handleEventsUpdate()
61. ☐ Add listener cancellation logic

---

### 3.4 Public Event Logging API ✅

```swift
public func logEvent(
    userId: String,
    metadata: [String: EventValue],
    timestamp: Date = Date(),
    timezone: String = TimeZone.current.identifier
) async throws -> UserStreak {
    logger?.trackEvent(event: Event.logEventStart)
    isSyncInProgress = true
    defer { isSyncInProgress = false }

    do {
        // Create event
        let event = Event(
            timestamp: timestamp,
            timezone: timezone,
            metadata: metadata
        )

        // Validate
        try validateEvent(event)

        // Validate streakId
        try validateStreakId(service.streakId)

        // Log via service
        let updatedStreak = try await service.logEvent(userId: userId, event: event)

        // Update cache
        service.setCachedStreak(updatedStreak)

        // Check for freeze consumption
        if autoConsumeFreeze {
            try await checkAndConsumeFreeze(userId: userId)
        }

        logger?.trackEvent(event: Event.logEventSuccess(streak: updatedStreak))
        return updatedStreak
    } catch {
        logger?.trackEvent(event: Event.logEventFail(error: error))
        throw error
    }
}

private func validateEvent(_ event: Event) throws {
    // Timestamp validation
    guard event.timestamp <= Date() else {
        throw GamificationError.invalidTimestamp(event.timestamp)
    }

    let oneYearAgo = Date().addingTimeInterval(-365 * 24 * 60 * 60)
    guard event.timestamp > oneYearAgo else {
        throw GamificationError.invalidTimestamp(event.timestamp)
    }

    // Timezone validation
    guard TimeZone(identifier: event.timezone) != nil else {
        throw GamificationError.invalidTimezone(event.timezone)
    }
}

private func validateStreakId(_ streakId: String) throws {
    let pattern = "^[a-z0-9_]+$"  // Decision #1
    let regex = try NSRegularExpression(pattern: pattern)
    let range = NSRange(streakId.startIndex..., in: streakId)

    guard regex.firstMatch(in: streakId, range: range) != nil else {
        throw GamificationError.invalidStreakId(streakId)
    }
}
```

**Edge Cases:**
- ❗ Timestamp validation (future, too old)
- ❗ Timezone validation (must be valid identifier)
- ❗ Metadata validation (Firestore-safe keys)
- ❗ StreakId validation (regex pattern)
- ❗ Auto-consume freeze logic
- ❗ Handle duplicate events for same day

**Checkpoints:**
62. ☐ Implement logEvent() method
63. ☐ Implement validateEvent() helper
64. ☐ Implement validateStreakId() helper
65. ☐ Add auto-consume freeze logic

---

### 3.5 Freeze Management API ✅

```swift
public func addStreakFreeze(userId: String) async throws {
    logger?.trackEvent(event: Event.addFreezeStart)

    do {
        try await service.addStreakFreeze(userId: userId)
        freezesRemaining = try await service.getFreezesRemaining(userId: userId)
        logger?.trackEvent(event: Event.addFreezeSuccess(remaining: freezesRemaining))
    } catch {
        logger?.trackEvent(event: Event.addFreezeFail(error: error))
        throw error
    }
}

public func consumeStreakFreeze(userId: String) async throws -> Int {
    logger?.trackEvent(event: Event.consumeFreezeStart)

    do {
        let remaining = try await service.consumeStreakFreeze(userId: userId)
        freezesRemaining = remaining

        // Callback
        await callbacks?.onFreezeConsumed?(remaining)

        logger?.trackEvent(event: Event.consumeFreezeSuccess(remaining: remaining))
        return remaining
    } catch {
        logger?.trackEvent(event: Event.consumeFreezeFail(error: error))
        throw error
    }
}

private func checkAndConsumeFreeze(userId: String) async throws {
    guard let streak = currentStreak else { return }

    let status = service.getStreakStatus(
        streak: streak,
        leewayHours: leewayHours,
        currentDate: Date()
    )

    if case .broken = status {
        // Streak would break - try to consume freeze
        let remaining = try? await service.getFreezesRemaining(userId: userId)
        if (remaining ?? 0) > 0 {
            try await consumeStreakFreeze(userId: userId)
        }
    }
}
```

**Edge Cases:**
- ❗ Adding freeze when unlimited already (ok, just increment)
- ❗ Consuming when none available (throw error)
- ❗ Auto-consume only when streak actually breaks
- ❗ Callback must fire after consumption

**Checkpoints:**
66. ☐ Implement addStreakFreeze()
67. ☐ Implement consumeStreakFreeze()
68. ☐ Implement checkAndConsumeFreeze()

---

### 3.6 Additional Public API ✅

```swift
public func getStreak(userId: String) async throws -> UserStreak {
    try await service.getStreak(userId: userId)
}

public func getRecentEvents(userId: String, days: Int = 30) async throws -> [Event] {
    try await service.getRecentEvents(userId: userId, days: days)
}

public func importEvents(userId: String, events: [Event]) async throws {
    logger?.trackEvent(event: Event.importEventsStart(count: events.count))

    do {
        try await service.importEvents(userId: userId, events: events)
        logger?.trackEvent(event: Event.importEventsSuccess(count: events.count))
    } catch {
        logger?.trackEvent(event: Event.importEventsFail(error: error))
        throw error
    }
}

public func deleteAllEventsAndResetStreak(userId: String) async throws {
    logger?.trackEvent(event: Event.deleteAllStart)

    do {
        try await service.deleteAllEventsAndResetStreak(userId: userId)
        currentStreak = nil
        service.clearCache()
        logger?.trackEvent(event: Event.deleteAllSuccess)
    } catch {
        logger?.trackEvent(event: Event.deleteAllFail(error: error))
        throw error
    }
}
```

**Checkpoints:**
69. ☐ Implement getStreak()
70. ☐ Implement getRecentEvents()
71. ☐ Implement importEvents()
72. ☐ Implement deleteAllEventsAndResetStreak()

---

### 3.7 Event Tracking Enum ✅

```swift
extension GamificationManager {
    enum Event: GamificationLogEvent {
        case streakUpdated(streak: UserStreak?)
        case logEventStart
        case logEventSuccess(streak: UserStreak)
        case logEventFail(error: Error)
        case addFreezeStart
        case addFreezeSuccess(remaining: Int)
        case addFreezeFail(error: Error)
        case consumeFreezeStart
        case consumeFreezeSuccess(remaining: Int)
        case consumeFreezeFail(error: Error)
        case importEventsStart(count: Int)
        case importEventsSuccess(count: Int)
        case importEventsFail(error: Error)
        case deleteAllStart
        case deleteAllSuccess
        case deleteAllFail(error: Error)

        var eventName: String {
            switch self {
            case .streakUpdated: return "Gamification_Streak_Updated"
            case .logEventStart: return "Gamification_LogEvent_Start"
            case .logEventSuccess: return "Gamification_LogEvent_Success"
            case .logEventFail: return "Gamification_LogEvent_Fail"
            // ... all cases
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .streakUpdated(streak: let streak):
                return streak?.eventParameters
            case .logEventSuccess(streak: let streak):
                return streak.eventParameters
            case .addFreezeSuccess(remaining: let remaining):
                return ["freezes_remaining": remaining]
            // ... all cases
            }
        }

        var type: GamificationLogType {
            switch self {
            case .logEventFail, .addFreezeFail, .consumeFreezeFail, .importEventsFail, .deleteAllFail:
                return .severe
            default:
                return .info
            }
        }
    }
}
```

**Checkpoints:**
73. ☐ Define all event cases
74. ☐ Implement eventName for all cases
75. ☐ Implement parameters for all cases
76. ☐ Implement type classification
77. ☐ Verify naming convention (Gamification_*)

---

## Phase 4: Mock Service

**Goal:** Implement fully functional MockGamificationService for testing

### Files to Modify

```
Sources/SwiftfulGamification/Services/
└── MockGamificationService.swift (EXISTS - needs complete implementation)
```

---

### 4.1 MockGamificationService Implementation ✅

**File:** `Sources/SwiftfulGamification/Services/MockGamificationService.swift`

**Requirements:**
- ✅ @MainActor isolation (for @Published)
- ✅ Conforms to GamificationService
- ✅ Uses @Published for reactive state
- ✅ In-memory storage (no FileManager)
- ✅ Maintains state across calls
- ✅ Always succeeds (no throwing)

**Critical Implementation:**

```swift
import Foundation
import Combine

@MainActor
public class MockGamificationService: GamificationService {

    // MARK: - Configuration
    public let streakId: String

    // MARK: - Published State (for testing)
    @Published public private(set) var currentStreak: UserStreak?
    @Published public private(set) var allEvents: [Event] = []
    @Published public private(set) var freezes: [StreakFreeze] = []

    // MARK: - Private Cache (in-memory)
    private var cache: UserStreak?

    public init(
        streakId: String = "mock_streak",
        initialStreak: UserStreak? = nil,
        initialEvents: [Event] = [],
        initialFreezes: [StreakFreeze] = []
    ) {
        self.streakId = streakId
        self.currentStreak = initialStreak
        self.cache = initialStreak
        self.allEvents = initialEvents
        self.freezes = initialFreezes
    }

    // MARK: - Cache
    public func getCachedStreak() -> UserStreak? {
        cache
    }

    public func setCachedStreak(_ streak: UserStreak) {
        cache = streak
    }

    public func clearCache() {
        cache = nil
    }

    // MARK: - Streak Operations
    public func getStreak(userId: String) async throws -> UserStreak {
        if let streak = currentStreak {
            return streak
        }

        // Create default streak if none exists
        let newStreak = UserStreak(
            id: userId,
            streakId: streakId,
            currentStreak: 0,
            longestStreak: 0
        )
        currentStreak = newStreak
        return newStreak
    }

    public func updateStreak(userId: String, streak: UserStreak) async throws {
        currentStreak = streak
        cache = streak
    }

    public func deleteAllEventsAndResetStreak(userId: String) async throws {
        allEvents.removeAll()
        currentStreak = UserStreak(
            id: userId,
            streakId: streakId,
            currentStreak: 0,
            longestStreak: 0
        )
        cache = currentStreak
    }

    // MARK: - Event Operations
    public func logEvent(userId: String, event: Event) async throws -> UserStreak {
        // Add event
        allEvents.append(event)
        allEvents.sort { $0.timestamp < $1.timestamp }

        // Recalculate streak
        let timezone = TimeZone(identifier: event.timezone) ?? .current
        let newStreak = calculateStreak(
            events: allEvents,
            leewayHours: 0,
            currentDate: Date(),
            timezone: timezone
        )

        currentStreak = newStreak
        cache = newStreak
        return newStreak
    }

    public func getEvents(userId: String, limit: Int?) async throws -> [Event] {
        if let limit {
            return Array(allEvents.suffix(limit))
        }
        return allEvents
    }

    public func getRecentEvents(userId: String, days: Int) async throws -> [Event] {
        let cutoff = Date().addingTimeInterval(-Double(days) * 24 * 60 * 60)
        return allEvents.filter { $0.timestamp >= cutoff }
    }

    public func importEvents(userId: String, events: [Event]) async throws {
        allEvents.append(contentsOf: events)
        allEvents.sort { $0.timestamp < $1.timestamp }

        // Recalculate
        if let lastEvent = allEvents.last {
            let timezone = TimeZone(identifier: lastEvent.timezone) ?? .current
            let newStreak = calculateStreak(
                events: allEvents,
                leewayHours: 0,
                currentDate: Date(),
                timezone: timezone
            )
            currentStreak = newStreak
            cache = newStreak
        }
    }

    public func deleteEvent(userId: String, eventId: String) async throws {
        allEvents.removeAll { $0.id == eventId }
    }

    // MARK: - Freeze Operations
    public func getFreezesRemaining(userId: String) async throws -> Int {
        freezes.filter { $0.usedDate == nil }.count
    }

    public func addStreakFreeze(userId: String) async throws {
        let freeze = StreakFreeze(
            id: UUID().uuidString,
            userId: userId,
            streakId: streakId,
            earnedDate: Date()
        )
        freezes.append(freeze)
    }

    public func consumeStreakFreeze(userId: String) async throws -> Int {
        guard let index = freezes.firstIndex(where: { $0.usedDate == nil }) else {
            throw GamificationError.freezeNotAvailable
        }

        var freeze = freezes[index]
        freeze = StreakFreeze(
            id: freeze.id,
            userId: freeze.userId,
            streakId: freeze.streakId,
            earnedDate: freeze.earnedDate,
            usedDate: Date()
        )
        freezes[index] = freeze

        return try await getFreezesRemaining(userId: userId)
    }

    public func getFreezesHistory(userId: String) async throws -> [StreakFreeze] {
        freezes
    }

    // MARK: - Reactive Streams
    public func streamStreak(userId: String) -> AsyncStream<UserStreak?> {
        AsyncStream { continuation in
            let task = Task {
                for await value in $currentStreak.values {
                    continuation.yield(value)
                }
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    public func streamEvents(userId: String) -> AsyncStream<[Event]> {
        AsyncStream { continuation in
            let task = Task {
                for await value in $allEvents.values {
                    continuation.yield(value)
                }
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    // MARK: - Calculation (reuse shared logic - see Phase 4.2)
    public func calculateStreak(events: [Event], leewayHours: Int, currentDate: Date, timezone: TimeZone) -> UserStreak {
        // Implementation in Phase 4.2
    }

    public func getStreakStatus(streak: UserStreak, leewayHours: Int, currentDate: Date) -> StreakStatus {
        // Implementation in Phase 4.2
    }
}
```

**Edge Cases:**
- ❗ Must maintain sorted events by timestamp
- ❗ Streak calculation must match algorithm from RESEARCH.md
- ❗ AsyncStream must properly cancel on termination
- ❗ All operations succeed (useful for UI testing)

**Checkpoints:**
78. ☐ Define class with @MainActor
79. ☐ Add @Published state properties
80. ☐ Implement all cache methods
81. ☐ Implement all streak methods
82. ☐ Implement all event methods (with sorting)
83. ☐ Implement all freeze methods
84. ☐ Implement AsyncStream methods (from @Published)
85. ☐ Verify state persists across calls

---

### 4.2 Shared Calculation Logic ✅

**Challenge:** calculateStreak() and getStreakStatus() must be implemented in BOTH MockGamificationService and (later) FirebaseGamificationService. To avoid duplication, we need shared utility.

**Options:**
1. Extension on GamificationService (protocol extension) ✅ RECOMMENDED
2. Separate StreakCalculator utility class
3. Duplicate in both implementations

**Solution: Protocol Extension**

**File:** `Sources/SwiftfulGamification/Extensions/GamificationService+Calculations.swift` (NEW)

```swift
import Foundation

extension GamificationService {

    /// Calculate streak from events using timezone-aware day comparison
    public func calculateStreak(
        events: [Event],
        leewayHours: Int,
        currentDate: Date,
        timezone: TimeZone
    ) -> UserStreak {
        guard !events.isEmpty else {
            return UserStreak(
                id: "unknown",
                streakId: streakId,
                currentStreak: 0,
                longestStreak: 0
            )
        }

        var calendar = Calendar.current
        calendar.timeZone = timezone

        // Get unique days (multiple events on same day = 1 day)
        let uniqueDays = Set(events.map { event in
            calendar.startOfDay(for: event.timestamp)
        }).sorted()

        // Calculate current streak (walk backwards from today)
        var currentStreak = 0
        var expectedDate = calendar.startOfDay(for: currentDate)

        // Apply leeway: Extend "today" window
        if leewayHours > 0 {
            let components = calendar.dateComponents([.hour], from: expectedDate, to: currentDate)
            let hoursSinceMidnight = components.hour ?? 0

            // If we're within leeway hours AFTER midnight, also count yesterday
            if hoursSinceMidnight <= leewayHours {
                expectedDate = calendar.date(byAdding: .day, value: -1, to: expectedDate) ?? expectedDate
            }
        }

        for eventDay in uniqueDays.reversed() {
            if calendar.isDate(eventDay, inSameDayAs: expectedDate) {
                currentStreak += 1
                expectedDate = calendar.date(byAdding: .day, value: -1, to: expectedDate) ?? expectedDate
            } else if eventDay < expectedDate {
                // Gap found - streak broken
                break
            }
        }

        // Calculate longest streak (walk through all days)
        var longestStreak = 0
        var tempStreak = 0
        var previousDay: Date?

        for eventDay in uniqueDays {
            if let prev = previousDay {
                let dayDiff = calendar.dateComponents([.day], from: prev, to: eventDay).day ?? 0
                if dayDiff == 1 {
                    tempStreak += 1
                } else {
                    longestStreak = max(longestStreak, tempStreak)
                    tempStreak = 1
                }
            } else {
                tempStreak = 1
            }
            previousDay = eventDay
        }
        longestStreak = max(longestStreak, tempStreak)
        longestStreak = max(longestStreak, currentStreak)  // Current could be longest

        // Get last event info
        let lastEvent = events.max(by: { $0.timestamp < $1.timestamp })

        return UserStreak(
            id: lastEvent?.id ?? "unknown",
            streakId: streakId,
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            lastEventDate: lastEvent?.timestamp,
            lastEventTimezone: lastEvent?.timezone,
            streakStartDate: uniqueDays.count >= currentStreak && currentStreak > 0
                ? uniqueDays[uniqueDays.count - currentStreak]
                : nil,
            totalEvents: events.count,
            createdAt: events.first?.timestamp,
            updatedAt: currentDate
        )
    }

    /// Get current status of streak
    public func getStreakStatus(
        streak: UserStreak,
        leewayHours: Int,
        currentDate: Date
    ) -> StreakStatus {
        guard let lastEventDate = streak.lastEventDate,
              let lastEventTimezone = streak.lastEventTimezone,
              let timezone = TimeZone(identifier: lastEventTimezone) else {
            return .noEvents
        }

        var calendar = Calendar.current
        calendar.timeZone = timezone

        let lastEventDay = calendar.startOfDay(for: lastEventDate)
        let currentDay = calendar.startOfDay(for: currentDate)

        let daysDiff = calendar.dateComponents([.day], from: lastEventDay, to: currentDay).day ?? 0

        switch daysDiff {
        case 0:
            return .active(daysSinceLastEvent: 0)
        case 1:
            // Check if within leeway
            let hoursSinceMidnight = calendar.dateComponents([.hour], from: currentDay, to: currentDate).hour ?? 0
            if hoursSinceMidnight <= leewayHours {
                return .canExtendWithLeeway
            }
            return .atRisk
        case 2:
            // Might be within leeway window
            let hoursSinceMidnight = calendar.dateComponents([.hour], from: currentDay, to: currentDate).hour ?? 0
            if hoursSinceMidnight <= leewayHours {
                return .canExtendWithLeeway
            }
            return .broken(daysSinceLastEvent: daysDiff)
        default:
            return .broken(daysSinceLastEvent: daysDiff)
        }
    }
}
```

**Edge Cases Covered:**
- ✅ Empty events array
- ✅ Multiple events same day (deduplicated)
- ✅ Leeway hours applied correctly (±X hours around midnight)
- ✅ Timezone changes handled (each event has timezone)
- ✅ DST transitions (Calendar.startOfDay handles it)
- ✅ Longest streak calculation includes current streak
- ✅ Streak start date computed correctly

**Checkpoints:**
86. ☐ Create GamificationService+Calculations.swift
87. ☐ Implement calculateStreak() with full algorithm
88. ☐ Implement getStreakStatus()
89. ☐ Add extensive inline documentation
90. ☐ Verify leeway logic (±X hours)
91. ☐ Test with RESEARCH.md examples

---

## Phase 5: Testing & Validation

**Goal:** Comprehensive tests covering all edge cases

### Files to Create/Modify

```
Tests/SwiftfulGamificationTests/
├── SwiftfulGamificationTests.swift (EXISTS - expand)
├── Models/
│   ├── EventTests.swift (NEW)
│   ├── UserStreakTests.swift (NEW)
│   ├── StreakFreezeTests.swift (NEW)
│   └── EventValueTests.swift (NEW)
├── Services/
│   ├── MockGamificationServiceTests.swift (NEW)
│   └── CalculationTests.swift (NEW)
├── Manager/
│   └── GamificationManagerTests.swift (NEW)
└── Utilities/
    ├── MockDateProvider.swift (NEW)
    └── TestHelpers.swift (NEW)
```

---

### 5.1 Test Utilities ✅

**File:** `Tests/SwiftfulGamificationTests/Utilities/TestHelpers.swift`

```swift
import Foundation
@testable import SwiftfulGamification

// Mock Date Provider
struct MockDateProvider {
    var mockedDate: Date
    var mockedTimezone: TimeZone

    static func create(
        year: Int = 2024,
        month: Int = 1,
        day: Int = 1,
        hour: Int = 12,
        minute: Int = 0,
        timezone: String = "America/New_York"
    ) -> Date {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: timezone)!
        let components = DateComponents(
            year: year, month: month, day: day,
            hour: hour, minute: minute
        )
        return calendar.date(from: components)!
    }
}

// Test Data Factories
extension Event {
    static func testEvent(
        daysAgo: Int = 0,
        timezone: String = "America/New_York",
        metadata: [String: EventValue] = ["type": .string("test")]
    ) -> Event {
        let date = Date().addingTimeInterval(-Double(daysAgo) * 24 * 60 * 60)
        return Event(timestamp: date, timezone: timezone, metadata: metadata)
    }
}

extension UserStreak {
    static func testStreak(currentStreak: Int = 5) -> UserStreak {
        UserStreak(
            id: "test_user",
            streakId: "test_streak",
            currentStreak: currentStreak,
            longestStreak: currentStreak + 2,
            lastEventDate: Date(),
            lastEventTimezone: "America/New_York"
        )
    }
}
```

**Checkpoints:**
92. ☐ Create TestHelpers.swift
93. ☐ Add MockDateProvider
94. ☐ Add test data factories
95. ☐ Add assertion helpers

---

### 5.2 Critical Test Cases ✅

**File:** `Tests/SwiftfulGamificationTests/Services/CalculationTests.swift`

Based on RESEARCH.md Section 9.3, implement these critical tests:

```swift
import Testing
import Foundation
@testable import SwiftfulGamification

@Suite("Streak Calculation Tests")
struct CalculationTests {

    @Test("Same day in different timezones counts as one day")
    func testTimezoneTravelWest() async throws {
        let service = MockGamificationService(streakId: "test")

        // NYC at 11 PM EST
        let nycEvent = Event.testEvent(
            daysAgo: 0,
            timezone: "America/New_York",
            metadata: ["location": .string("NYC")]
        )

        // LA at 9 PM PST (same UTC day, different local day)
        let laEvent = Event.testEvent(
            daysAgo: 0,
            timezone: "America/Los_Angeles",
            metadata: ["location": .string("LA")]
        )

        let streak = service.calculateStreak(
            events: [nycEvent, laEvent],
            leewayHours: 0,
            currentDate: Date(),
            timezone: TimeZone(identifier: "America/Los_Angeles")!
        )

        #expect(streak.currentStreak == 1)
    }

    @Test("Midnight boundary preserves streak")
    func testMidnightBoundary() async throws {
        // Test from RESEARCH.md: 11:59:59 PM + 12:00:01 AM = 2 days
        let service = MockGamificationService(streakId: "test")

        let day1 = MockDateProvider.create(
            day: 1, hour: 23, minute: 59
        )
        let day2 = MockDateProvider.create(
            day: 2, hour: 0, minute: 0
        )

        let events = [
            Event(timestamp: day1, timezone: "America/New_York", metadata: ["day": .int(1)]),
            Event(timestamp: day2, timezone: "America/New_York", metadata: ["day": .int(2)])
        ]

        let streak = service.calculateStreak(
            events: events,
            leewayHours: 0,
            currentDate: day2,
            timezone: TimeZone(identifier: "America/New_York")!
        )

        #expect(streak.currentStreak == 2)
    }

    @Test("Leeway hours allow grace period")
    func testLeewayHours() async throws {
        let service = MockGamificationService(streakId: "test")

        // Last event 2 days ago
        let lastEvent = Event.testEvent(daysAgo: 2)

        // Current time: 2 AM (within 3-hour leeway)
        let currentDate = MockDateProvider.create(hour: 2)

        let streak = service.calculateStreak(
            events: [lastEvent],
            leewayHours: 3,
            currentDate: currentDate,
            timezone: .current
        )

        let status = service.getStreakStatus(
            streak: streak,
            leewayHours: 3,
            currentDate: currentDate
        )

        #expect(status == .canExtendWithLeeway)
    }

    @Test("DST transition preserves streak")
    func testDSTTransition() async throws {
        // Spring forward: March 10, 2024 (2 AM -> 3 AM)
        let service = MockGamificationService(streakId: "test")

        let beforeDST = MockDateProvider.create(
            month: 3, day: 9, hour: 23
        )
        let afterDST = MockDateProvider.create(
            month: 3, day: 10, hour: 23
        )

        let events = [
            Event(timestamp: beforeDST, timezone: "America/New_York", metadata: ["day": .int(9)]),
            Event(timestamp: afterDST, timezone: "America/New_York", metadata: ["day": .int(10)])
        ]

        let streak = service.calculateStreak(
            events: events,
            leewayHours: 0,
            currentDate: afterDST,
            timezone: TimeZone(identifier: "America/New_York")!
        )

        #expect(streak.currentStreak == 2)
    }

    @Test("Empty events returns zero streak")
    func testEmptyEvents() async throws {
        let service = MockGamificationService(streakId: "test")

        let streak = service.calculateStreak(
            events: [],
            leewayHours: 0,
            currentDate: Date(),
            timezone: .current
        )

        #expect(streak.currentStreak == 0)
        #expect(streak.longestStreak == 0)
    }

    @Test("Multiple events same day count as one")
    func testMultipleEventsOneDay() async throws {
        let service = MockGamificationService(streakId: "test")

        let today = Date()
        let events = [
            Event(timestamp: today.addingTimeInterval(-3600), timezone: "America/New_York", metadata: ["id": .int(1)]),
            Event(timestamp: today.addingTimeInterval(-1800), timezone: "America/New_York", metadata: ["id": .int(2)]),
            Event(timestamp: today, timezone: "America/New_York", metadata: ["id": .int(3)])
        ]

        let streak = service.calculateStreak(
            events: events,
            leewayHours: 0,
            currentDate: today,
            timezone: .current
        )

        #expect(streak.currentStreak == 1)
        #expect(streak.totalEvents == 3)
    }

    @Test("Longest streak calculated correctly")
    func testLongestStreak() async throws {
        let service = MockGamificationService(streakId: "test")

        // Create pattern: 5 days, gap, 3 days, gap, 7 days (current)
        var events: [Event] = []

        // First streak: 5 days (20 days ago)
        for i in 0..<5 {
            events.append(Event.testEvent(daysAgo: 20 - i))
        }

        // Gap of 2 days

        // Second streak: 3 days (12 days ago)
        for i in 0..<3 {
            events.append(Event.testEvent(daysAgo: 12 - i))
        }

        // Gap of 2 days

        // Current streak: 7 days
        for i in 0..<7 {
            events.append(Event.testEvent(daysAgo: 7 - i))
        }

        let streak = service.calculateStreak(
            events: events,
            leewayHours: 0,
            currentDate: Date(),
            timezone: .current
        )

        #expect(streak.currentStreak == 7)
        #expect(streak.longestStreak == 7)  // Current is longest
    }
}
```

**Additional Test Suites Needed:**
- Model encoding/decoding tests
- Manager integration tests
- Freeze consumption logic tests
- Validation error tests
- AsyncStream tests
- Event import tests

**Checkpoints:**
96. ☐ Create CalculationTests.swift with all 7 critical tests
97. ☐ Create EventTests.swift (Codable, validation)
98. ☐ Create UserStreakTests.swift (computed properties)
99. ☐ Create StreakFreezeTests.swift
100. ☐ Create MockGamificationServiceTests.swift
101. ☐ Create GamificationManagerTests.swift
102. ☐ Verify all tests pass with `swift test`

---

## Critical Edge Cases Checklist

This checklist MUST be reviewed before considering implementation complete:

### Timezone Edge Cases ✅
- ☐ User logs event in NYC, flies to LA same day (should count as 1 day)
- ☐ User changes timezone mid-streak (recalculate in new timezone)
- ☐ DST transition (spring forward, fall back)
- ☐ Midnight boundary (11:59 PM → 12:01 AM counts as consecutive)
- ☐ Invalid timezone identifier handling

### Leeway Edge Cases ✅
- ☐ Event at 11 PM day 1, log at 2 AM day 3 with 3-hour leeway (should extend)
- ☐ Event at 11 PM day 1, log at 4 AM day 3 with 3-hour leeway (should break)
- ☐ Leeway = 0 (strict mode)
- ☐ Leeway = 24 hours (48-hour window for travel)

### Multi-Event Edge Cases ✅
- ☐ 10 events same day (count as 1 day)
- ☐ Events out of order (sort by timestamp)
- ☐ Duplicate event IDs (should be prevented)
- ☐ Event timestamp in future (should throw)
- ☐ Event timestamp > 1 year old (should throw)

### Freeze Edge Cases ✅
- ☐ Auto-consume when streak breaks
- ☐ No freezes available (should not consume, streak breaks)
- ☐ Multiple freezes on consecutive days
- ☐ Manual consumption (autoConsume = false)
- ☐ Freeze count synchronization across devices

### Streak Calculation Edge Cases ✅
- ☐ Empty events array (0 streak)
- ☐ Single event (streak = 1)
- ☐ Gap of exactly 1 day (streak breaks)
- ☐ Longest streak > current streak
- ☐ Longest streak = current streak
- ☐ Historical import recalculates correctly

### Cache Edge Cases ✅
- ☐ FileManager directory doesn't exist (create it)
- ☐ Cache file corrupted (handle gracefully)
- ☐ Cache cleared while app running (reload from server)
- ☐ Multiple managers same streakId (separate files)

### Manager Lifecycle Edge Cases ✅
- ☐ Manager deinit cancels listeners
- ☐ Multiple managers same userId (ok, different streakIds)
- ☐ Callbacks fire on correct thread (@MainActor)
- ☐ isSyncInProgress thread-safe

### Validation Edge Cases ✅
- ☐ StreakId with uppercase (should fail regex)
- ☐ StreakId with spaces (should fail)
- ☐ StreakId with special chars (should fail)
- ☐ Metadata with Firestore-unsafe keys (validate)
- ☐ Metadata with unsupported types (should fail)

### AsyncStream Edge Cases ✅
- ☐ Stream cancelled mid-iteration
- ☐ Stream started before any data (should emit nil or empty)
- ☐ Stream receives rapid updates (should not drop)
- ☐ Multiple listeners same stream (should all receive)

### Error Handling Edge Cases ✅
- ☐ Network timeout (graceful degradation)
- ☐ Invalid user ID (clear error message)
- ☐ Concurrent writes (Last-Write-Wins)
- ☐ Service throws mid-operation (cleanup state)

---

## Implementation Dependencies

### Internal Dependencies (Must Implement in Order)

```
EventValue (Phase 1.1)
    ↓
Event (Phase 1.2) - depends on EventValue
    ↓
UserStreak (Phase 1.3) - independent
StreakFreeze (Phase 1.4) - independent
StreakStatus (Phase 1.5) - independent
GamificationError (Phase 1.6) - independent
    ↓
GamificationService (Phase 2.1) - depends on Event, UserStreak, StreakFreeze, StreakStatus
    ↓
GamificationService+Calculations (Phase 4.2) - extends GamificationService
    ↓
GamificationManager (Phase 3) - depends on GamificationService, all models
    ↓
MockGamificationService (Phase 4.1) - implements GamificationService
    ↓
Tests (Phase 5) - depends on everything
```

### External Dependencies (Reference Only)

- SwiftfulAuthenticating (reference for patterns)
- SwiftfulLogging (reference for logger integration)
- SwiftfulPurchasing (reference for service pattern)

---

## Comprehensive Test Suite

**Purpose:** Complete test coverage for external test package
**Total Test Cases:** 150+ tests across 12 test suites
**Framework:** Swift Testing (@Test syntax)

This section provides a complete test manifest that should be implemented in a separate test package to ensure all functionality, edge cases, and business logic work correctly.

---

### Test Suite 1: EventValue Tests (10 tests)

**File:** `EventValueTests.swift`

```swift
@Suite("EventValue Model Tests")
struct EventValueTests {

    @Test("String case encodes and decodes correctly")
    func testStringCodable() async throws

    @Test("Bool case encodes and decodes correctly")
    func testBoolCodable() async throws

    @Test("Int case encodes and decodes correctly")
    func testIntCodable() async throws

    @Test("Empty string is valid")
    func testEmptyString() async throws

    @Test("Large int values handled correctly")
    func testLargeInt() async throws

    @Test("Bool true and false preserved exactly")
    func testBoolPreservation() async throws

    @Test("Equatable works for same type same value")
    func testEqualitySameValue() async throws

    @Test("Equatable fails for different types")
    func testEqualityDifferentTypes() async throws

    @Test("JSON encoding includes type discrimination")
    func testTypeDiscriminationInJSON() async throws

    @Test("Decoding invalid type throws error")
    func testInvalidTypeThrows() async throws
}
```

---

### Test Suite 2: Event Model Tests (20 tests)

**File:** `EventTests.swift`

```swift
@Suite("Event Model Tests")
struct EventTests {

    // MARK: - Initialization
    @Test("Default initializer generates UUID")
    func testDefaultUUID() async throws

    @Test("Default timestamp is current date")
    func testDefaultTimestamp() async throws

    @Test("Default timezone is current")
    func testDefaultTimezone() async throws

    @Test("Custom values override defaults")
    func testCustomValues() async throws

    // MARK: - Codable
    @Test("Encodes to snake_case keys")
    func testSnakeCaseEncoding() async throws

    @Test("Decodes from snake_case keys")
    func testSnakeCaseDecoding() async throws

    @Test("Roundtrip encoding preserves data")
    func testRoundtripCodable() async throws

    @Test("Metadata with all value types encodes")
    func testComplexMetadataEncoding() async throws

    @Test("Empty metadata is valid")
    func testEmptyMetadata() async throws

    // MARK: - Validation
    @Test("Future timestamp validation fails")
    func testFutureTimestampInvalid() async throws

    @Test("Timestamp older than 1 year fails")
    func testOldTimestampInvalid() async throws

    @Test("Invalid timezone identifier validation fails")
    func testInvalidTimezoneIdentifier() async throws

    @Test("Valid timezone identifiers pass")
    func testValidTimezoneIdentifiers() async throws

    @Test("Metadata keys with special characters")
    func testMetadataKeyValidation() async throws

    // MARK: - Mock Factory
    @Test("Mock factory creates valid event")
    func testMockFactory() async throws

    @Test("Mock factory with custom metadata")
    func testMockFactoryCustomMetadata() async throws

    // MARK: - Event Parameters
    @Test("Event parameters includes all fields")
    func testEventParameters() async throws

    @Test("Event parameters converts metadata correctly")
    func testEventParametersMetadata() async throws

    // MARK: - Equatable
    @Test("Same events are equal")
    func testEquality() async throws

    @Test("Different IDs make events unequal")
    func testInequalityDifferentID() async throws
}
```

---

### Test Suite 3: UserStreak Model Tests (25 tests)

**File:** `UserStreakTests.swift`

```swift
@Suite("UserStreak Model Tests")
struct UserStreakTests {

    // MARK: - Initialization
    @Test("Init with only required id field")
    func testMinimalInit() async throws

    @Test("Init with all fields")
    func testFullInit() async throws

    @Test("All fields except id are optional")
    func testOptionalFields() async throws

    // MARK: - Codable
    @Test("Encodes with snake_case keys")
    func testSnakeCaseEncoding() async throws

    @Test("Decodes from snake_case keys")
    func testSnakeCaseDecoding() async throws

    @Test("Roundtrip preserves all data")
    func testRoundtripCodable() async throws

    @Test("Decodes with missing optional fields")
    func testDecodeMissingFields() async throws

    @Test("Backwards compatible with old data")
    func testBackwardsCompatibility() async throws

    // MARK: - Computed Properties
    @Test("isStreakActive when event today")
    func testIsStreakActiveToday() async throws

    @Test("isStreakActive when event yesterday")
    func testIsStreakActiveYesterday() async throws

    @Test("isStreakActive false when 2 days ago")
    func testIsStreakActiveFalse() async throws

    @Test("isStreakActive false when no events")
    func testIsStreakActiveNoEvents() async throws

    @Test("isStreakAtRisk when event yesterday")
    func testIsStreakAtRiskYesterday() async throws

    @Test("isStreakAtRisk false when event today")
    func testIsStreakAtRiskFalseToday() async throws

    @Test("daysSinceLastEvent returns correct value")
    func testDaysSinceLastEvent() async throws

    @Test("daysSinceLastEvent handles timezone correctly")
    func testDaysSinceLastEventTimezone() async throws

    // MARK: - Business Logic
    @Test("currentStreak of 0 is valid")
    func testZeroStreak() async throws

    @Test("longestStreak >= currentStreak always")
    func testLongestGreaterOrEqual() async throws

    @Test("Negative values rejected")
    func testNoNegativeValues() async throws

    // MARK: - Mock Factory
    @Test("Mock factory creates valid streak")
    func testMockFactory() async throws

    @Test("Mock factory with custom values")
    func testMockFactoryCustom() async throws

    // MARK: - Event Parameters
    @Test("Event parameters includes all non-nil fields")
    func testEventParameters() async throws

    @Test("Event parameters excludes nil fields")
    func testEventParametersNils() async throws

    // MARK: - Validation
    @Test("Validate integrity catches invalid state")
    func testValidateIntegrity() async throws

    @Test("Validate integrity passes valid state")
    func testValidateIntegrityValid() async throws
}
```

---

### Test Suite 4: StreakFreeze Model Tests (15 tests)

**File:** `StreakFreezeTests.swift`

```swift
@Suite("StreakFreeze Model Tests")
struct StreakFreezeTests {

    // MARK: - Initialization
    @Test("Init with only required id")
    func testMinimalInit() async throws

    @Test("Init with all fields")
    func testFullInit() async throws

    // MARK: - Codable
    @Test("Encodes with snake_case")
    func testSnakeCaseEncoding() async throws

    @Test("Roundtrip preserves data")
    func testRoundtripCodable() async throws

    @Test("Decodes with missing optionals")
    func testDecodeMissingFields() async throws

    // MARK: - Computed Properties
    @Test("isUsed true when usedDate present")
    func testIsUsedTrue() async throws

    @Test("isUsed false when usedDate nil")
    func testIsUsedFalse() async throws

    @Test("isExpired always false (never expire)")
    func testIsExpiredAlwaysFalse() async throws

    // MARK: - Business Logic
    @Test("usedDate after earnedDate")
    func testUsedAfterEarned() async throws

    @Test("expiresAt after earnedDate")
    func testExpiresAfterEarned() async throws

    @Test("Unused freeze is valid state")
    func testUnusedValid() async throws

    // MARK: - Mock Factory
    @Test("Mock factory creates unused freeze")
    func testMockFactoryUnused() async throws

    @Test("Mock factory creates used freeze")
    func testMockFactoryUsed() async throws

    // MARK: - Event Parameters
    @Test("Event parameters includes all fields")
    func testEventParameters() async throws

    @Test("Event parameters handles nil values")
    func testEventParametersNils() async throws
}
```

---

### Test Suite 5: Streak Calculation Algorithm Tests (30 tests)

**File:** `StreakCalculationTests.swift`

```swift
@Suite("Streak Calculation Algorithm Tests")
struct StreakCalculationTests {

    // MARK: - Basic Calculation
    @Test("Empty events returns zero streak")
    func testEmptyEvents() async throws

    @Test("Single event returns streak of 1")
    func testSingleEvent() async throws

    @Test("Two consecutive days returns 2")
    func testConsecutiveDays() async throws

    @Test("Three consecutive days returns 3")
    func testThreeConsecutiveDays() async throws

    @Test("Gap of 1 day breaks streak")
    func testGapBreaksStreak() async throws

    @Test("Multiple events same day count as 1")
    func testMultipleEventsSameDay() async throws

    // MARK: - Timezone Handling
    @Test("Same UTC day, different timezones counts as 1")
    func testTimezoneTravelWest() async throws

    @Test("Calculate in current timezone")
    func testCalculateInCurrentTimezone() async throws

    @Test("Events stored with different timezones")
    func testMixedTimezones() async throws

    @Test("Invalid timezone falls back gracefully")
    func testInvalidTimezoneFallback() async throws

    // MARK: - Midnight Boundary
    @Test("11:59 PM + 12:01 AM = 2 days")
    func testMidnightBoundary() async throws

    @Test("Events exactly at midnight")
    func testExactMidnight() async throws

    @Test("Events seconds before midnight")
    func testSecondsBeforeMidnight() async throws

    // MARK: - DST Transitions
    @Test("Spring forward preserves streak")
    func testSpringForward() async throws

    @Test("Fall back preserves streak")
    func testFallBack() async throws

    @Test("DST transition at midnight")
    func testDSTAtMidnight() async throws

    // MARK: - Leeway/Grace Period
    @Test("Leeway 0 hours (strict mode)")
    func testLeewayZero() async throws

    @Test("Leeway 3 hours allows extension")
    func testLeewayThreeHours() async throws

    @Test("Leeway 24 hours (travel mode)")
    func testLeeway24Hours() async throws

    @Test("Outside leeway window breaks streak")
    func testOutsideLeeway() async throws

    @Test("Leeway applies bidirectionally")
    func testLeewayBidirectional() async throws

    // MARK: - Longest Streak
    @Test("Longest streak calculated correctly")
    func testLongestStreak() async throws

    @Test("Current streak is longest")
    func testCurrentIsLongest() async throws

    @Test("Past streak was longest")
    func testPastStreakLongest() async throws

    @Test("Multiple streak periods")
    func testMultipleStreakPeriods() async throws

    // MARK: - Edge Cases
    @Test("Events out of chronological order")
    func testEventsOutOfOrder() async throws

    @Test("Duplicate timestamps")
    func testDuplicateTimestamps() async throws

    @Test("Very long streak (365+ days)")
    func testVeryLongStreak() async throws

    @Test("Streak started in different timezone")
    func testStreakStartedDifferentTimezone() async throws

    @Test("All events on same day")
    func testAllEventsSameDay() async throws
}
```

---

### Test Suite 6: Streak Status Tests (12 tests)

**File:** `StreakStatusTests.swift`

```swift
@Suite("Streak Status Tests")
struct StreakStatusTests {

    @Test("Status noEvents when no lastEventDate")
    func testNoEvents() async throws

    @Test("Status active(0) when event today")
    func testActiveToday() async throws

    @Test("Status active(1) when event yesterday")
    func testActiveYesterday() async throws

    @Test("Status atRisk when event yesterday, approaching midnight")
    func testAtRisk() async throws

    @Test("Status broken when 2+ days ago")
    func testBrokenTwoDays() async throws

    @Test("Status canExtendWithLeeway within window")
    func testCanExtendWithLeeway() async throws

    @Test("Status broken outside leeway window")
    func testBrokenOutsideLeeway() async throws

    @Test("Leeway 0 never returns canExtendWithLeeway")
    func testLeewayZeroNoExtension() async throws

    @Test("Invalid timezone handled gracefully")
    func testInvalidTimezone() async throws

    @Test("Missing lastEventTimezone handled")
    func testMissingTimezone() async throws

    @Test("Status changes based on current time")
    func testStatusChangesOverTime() async throws

    @Test("Status with different timezone identifiers")
    func testDifferentTimezones() async throws
}
```

---

### Test Suite 7: GamificationService Protocol Tests (25 tests)

**File:** `GamificationServiceTests.swift`

**Note:** These tests use MockGamificationService

```swift
@Suite("GamificationService Protocol Tests")
struct GamificationServiceTests {

    // MARK: - Cache Operations
    @Test("getCachedStreak returns nil when empty")
    func testGetCachedEmpty() async throws

    @Test("setCachedStreak persists data")
    func testSetCached() async throws

    @Test("clearCache removes data")
    func testClearCache() async throws

    @Test("Cache persists across service calls")
    func testCachePersistence() async throws

    // MARK: - Streak Operations
    @Test("getStreak returns existing streak")
    func testGetStreak() async throws

    @Test("getStreak creates default when none exists")
    func testGetStreakCreatesDefault() async throws

    @Test("updateStreak modifies existing")
    func testUpdateStreak() async throws

    @Test("deleteAllEventsAndResetStreak clears everything")
    func testDeleteAllAndReset() async throws

    // MARK: - Event Operations
    @Test("logEvent adds event and recalculates")
    func testLogEvent() async throws

    @Test("logEvent on same day doesn't duplicate")
    func testLogEventSameDay() async throws

    @Test("logEvent maintains sort order")
    func testLogEventSortOrder() async throws

    @Test("getEvents with limit returns subset")
    func testGetEventsWithLimit() async throws

    @Test("getEvents without limit returns all")
    func testGetEventsNoLimit() async throws

    @Test("getRecentEvents filters by days")
    func testGetRecentEvents() async throws

    @Test("importEvents adds multiple events")
    func testImportEvents() async throws

    @Test("importEvents recalculates streak")
    func testImportEventsRecalculates() async throws

    @Test("deleteEvent removes specific event")
    func testDeleteEvent() async throws

    // MARK: - Freeze Operations
    @Test("getFreezesRemaining returns count")
    func testGetFreezesRemaining() async throws

    @Test("addStreakFreeze increments count")
    func testAddStreakFreeze() async throws

    @Test("consumeStreakFreeze decrements count")
    func testConsumeStreakFreeze() async throws

    @Test("consumeStreakFreeze throws when none available")
    func testConsumeFreezeNoAvailable() async throws

    @Test("getFreezesHistory returns all freezes")
    func testGetFreezesHistory() async throws

    // MARK: - Reactive Streams
    @Test("streamStreak emits updates")
    func testStreamStreak() async throws

    @Test("streamEvents emits updates")
    func testStreamEvents() async throws

    @Test("Stream cancellation stops emissions")
    func testStreamCancellation() async throws
}
```

---

### Test Suite 8: GamificationManager Tests (30 tests)

**File:** `GamificationManagerTests.swift`

```swift
@Suite("GamificationManager Tests")
struct GamificationManagerTests {

    // MARK: - Initialization
    @Test("Init loads cache immediately")
    func testInitLoadsCache() async throws

    @Test("Init starts listeners")
    func testInitStartsListeners() async throws

    @Test("Init with custom leeway hours")
    func testInitCustomLeeway() async throws

    @Test("Init with autoConsumeFreeze disabled")
    func testInitNoAutoConsume() async throws

    // MARK: - Event Logging
    @Test("logEvent validates timestamp")
    func testLogEventValidation() async throws

    @Test("logEvent validates timezone")
    func testLogEventTimezoneValidation() async throws

    @Test("logEvent validates streakId")
    func testLogEventStreakIdValidation() async throws

    @Test("logEvent updates isSyncInProgress")
    func testLogEventSyncFlag() async throws

    @Test("logEvent triggers logger events")
    func testLogEventLogging() async throws

    @Test("logEvent auto-consumes freeze when enabled")
    func testLogEventAutoConsumeFreeze() async throws

    @Test("logEvent doesn't auto-consume when disabled")
    func testLogEventNoAutoConsume() async throws

    @Test("logEvent with future timestamp throws")
    func testLogEventFutureThrows() async throws

    @Test("logEvent with old timestamp throws")
    func testLogEventOldThrows() async throws

    // MARK: - Freeze Management
    @Test("addStreakFreeze increments count")
    func testAddFreeze() async throws

    @Test("consumeStreakFreeze calls callback")
    func testConsumeFreezeCallback() async throws

    @Test("checkAndConsumeFreeze when streak broken")
    func testCheckAndConsumeWhenBroken() async throws

    @Test("checkAndConsumeFreeze skips when active")
    func testCheckAndConsumeWhenActive() async throws

    @Test("checkAndConsumeFreeze with no freezes available")
    func testCheckAndConsumeNoFreezes() async throws

    // MARK: - Callbacks
    @Test("configureCallbacks sets callbacks")
    func testConfigureCallbacks() async throws

    @Test("onStreakBroken fires when streak breaks")
    func testOnStreakBroken() async throws

    @Test("onFreezeConsumed fires when freeze used")
    func testOnFreezeConsumed() async throws

    @Test("onStreakAtRisk fires when at risk")
    func testOnStreakAtRisk() async throws

    @Test("Callbacks are async safe")
    func testCallbacksAsync() async throws

    // MARK: - Listeners
    @Test("Listener updates currentStreak")
    func testListenerUpdatesStreak() async throws

    @Test("Listener updates cache")
    func testListenerUpdatesCache() async throws

    @Test("Listener detects streak break")
    func testListenerDetectsBreak() async throws

    @Test("Multiple listeners all receive updates")
    func testMultipleListeners() async throws

    // MARK: - Additional Methods
    @Test("getStreak fetches from service")
    func testGetStreak() async throws

    @Test("getRecentEvents filters correctly")
    func testGetRecentEvents() async throws

    @Test("importEvents logs events")
    func testImportEvents() async throws

    @Test("deleteAllEventsAndResetStreak clears state")
    func testDeleteAll() async throws
}
```

---

### Test Suite 9: Validation Tests (15 tests)

**File:** `ValidationTests.swift`

```swift
@Suite("Validation Tests")
struct ValidationTests {

    // MARK: - Streak ID Validation
    @Test("Valid streakId: lowercase letters")
    func testValidStreakIdLowercase() async throws

    @Test("Valid streakId: numbers")
    func testValidStreakIdNumbers() async throws

    @Test("Valid streakId: underscores")
    func testValidStreakIdUnderscores() async throws

    @Test("Invalid streakId: uppercase letters")
    func testInvalidStreakIdUppercase() async throws

    @Test("Invalid streakId: spaces")
    func testInvalidStreakIdSpaces() async throws

    @Test("Invalid streakId: special characters")
    func testInvalidStreakIdSpecialChars() async throws

    @Test("Invalid streakId: empty string")
    func testInvalidStreakIdEmpty() async throws

    // MARK: - Timestamp Validation
    @Test("Valid timestamp: current time")
    func testValidTimestampNow() async throws

    @Test("Valid timestamp: 1 day ago")
    func testValidTimestampPast() async throws

    @Test("Invalid timestamp: future")
    func testInvalidTimestampFuture() async throws

    @Test("Invalid timestamp: >1 year old")
    func testInvalidTimestampTooOld() async throws

    // MARK: - Timezone Validation
    @Test("Valid timezone: America/New_York")
    func testValidTimezoneNY() async throws

    @Test("Valid timezone: UTC")
    func testValidTimezoneUTC() async throws

    @Test("Invalid timezone: fake identifier")
    func testInvalidTimezoneFake() async throws

    @Test("Invalid timezone: empty string")
    func testInvalidTimezoneEmpty() async throws
}
```

---

### Test Suite 10: Freeze Behavior Tests (18 tests)

**File:** `FreezeBehaviorTests.swift`

```swift
@Suite("Freeze Behavior Tests")
struct FreezeBehaviorTests {

    // MARK: - Auto-Consume
    @Test("Auto-consume when streak breaks")
    func testAutoConsumeOnBreak() async throws

    @Test("Auto-consume uses oldest freeze first")
    func testAutoConsumeOldestFirst() async throws

    @Test("Auto-consume doesn't trigger when active")
    func testAutoConsumeSkipsActive() async throws

    @Test("Auto-consume throws when none available")
    func testAutoConsumeThrowsNone() async throws

    // MARK: - Manual Consume
    @Test("Manual consume when autoConsume disabled")
    func testManualConsume() async throws

    @Test("Manual consume fires callback")
    func testManualConsumeCallback() async throws

    @Test("Manual consume returns remaining count")
    func testManualConsumeReturnsCount() async throws

    // MARK: - Multiple Freezes
    @Test("Multiple freezes stack")
    func testMultipleFreezes() async throws

    @Test("Consume multiple freezes on consecutive days")
    func testConsecutiveFreezes() async throws

    @Test("Unlimited freezes via developer control")
    func testUnlimitedFreezes() async throws

    // MARK: - Freeze History
    @Test("History shows all freezes")
    func testFreezeHistory() async throws

    @Test("History shows used and unused")
    func testFreezeHistoryMixed() async throws

    @Test("History sorted by earnedDate")
    func testFreezeHistorySorted() async throws

    // MARK: - Edge Cases
    @Test("Freeze never expires")
    func testFreezeNeverExpires() async throws

    @Test("Add freeze during active streak")
    func testAddFreezeActiveStreak() async throws

    @Test("Freeze persists across app restarts")
    func testFreezePersistence() async throws

    @Test("Freeze consumption updates cache")
    func testFreezeConsumptionCache() async throws

    @Test("Already-used freeze cannot be consumed again")
    func testAlreadyUsedFreeze() async throws
}
```

---

### Test Suite 11: AsyncStream Tests (12 tests)

**File:** `AsyncStreamTests.swift`

```swift
@Suite("AsyncStream Tests")
struct AsyncStreamTests {

    // MARK: - Stream Streak
    @Test("streamStreak emits initial value")
    func testStreamStreakInitial() async throws

    @Test("streamStreak emits on update")
    func testStreamStreakUpdate() async throws

    @Test("streamStreak emits nil when deleted")
    func testStreamStreakNil() async throws

    @Test("Multiple listeners receive same updates")
    func testMultipleStreakListeners() async throws

    @Test("Stream cancellation stops emissions")
    func testStreakStreamCancellation() async throws

    // MARK: - Stream Events
    @Test("streamEvents emits initial array")
    func testStreamEventsInitial() async throws

    @Test("streamEvents emits on new event")
    func testStreamEventsNewEvent() async throws

    @Test("streamEvents emits empty array when deleted")
    func testStreamEventsEmpty() async throws

    @Test("Events stream maintains sort order")
    func testStreamEventsSorted() async throws

    // MARK: - Stream Lifecycle
    @Test("Stream starts before any data emits nil/empty")
    func testStreamBeforeData() async throws

    @Test("Stream receives rapid updates without dropping")
    func testStreamRapidUpdates() async throws

    @Test("Stream cleanup on termination")
    func testStreamCleanup() async throws
}
```

---

### Test Suite 12: Integration & Error Handling Tests (20 tests)

**File:** `IntegrationTests.swift`

```swift
@Suite("Integration & Error Handling Tests")
struct IntegrationTests {

    // MARK: - Full Workflow
    @Test("Complete workflow: signup -> log events -> build streak")
    func testCompleteWorkflow() async throws

    @Test("User logs event daily for 30 days")
    func test30DayStreak() async throws

    @Test("User breaks streak, uses freeze, continues")
    func testBreakAndFreeze() async throws

    @Test("Historical import recalculates correctly")
    func testHistoricalImport() async throws

    @Test("Multiple managers for different streaks")
    func testMultipleManagers() async throws

    // MARK: - Error Handling
    @Test("GamificationError.invalidStreakId message")
    func testErrorMessageInvalidStreakId() async throws

    @Test("GamificationError.invalidTimestamp message")
    func testErrorMessageInvalidTimestamp() async throws

    @Test("GamificationError.freezeNotAvailable thrown")
    func testErrorFreezeNotAvailable() async throws

    @Test("GamificationError.noEventsRecorded thrown")
    func testErrorNoEvents() async throws

    @Test("Error recovery suggestions provided")
    func testErrorRecoverySuggestions() async throws

    // MARK: - Concurrent Operations
    @Test("Concurrent logEvent calls handled")
    func testConcurrentLogEvents() async throws

    @Test("Concurrent freeze consumption")
    func testConcurrentFreezeConsume() async throws

    @Test("Cache thread safety")
    func testCacheThreadSafety() async throws

    // MARK: - Manager Lifecycle
    @Test("Manager deinit cancels listeners")
    func testManagerDeinit() async throws

    @Test("Manager restart reconnects listeners")
    func testManagerRestart() async throws

    // MARK: - Logger Integration
    @Test("All manager events tracked")
    func testAllEventsTracked() async throws

    @Test("Logger receives correct event types")
    func testLoggerEventTypes() async throws

    @Test("Logger parameters include streak data")
    func testLoggerParameters() async throws

    // MARK: - Cache Corruption
    @Test("Corrupted cache file handled gracefully")
    func testCorruptedCache() async throws

    @Test("Missing cache directory created")
    func testMissingCacheDirectory() async throws
}
```

---

## Test Coverage Summary

| Test Suite | Test Count | Coverage Area |
|------------|------------|---------------|
| EventValue | 10 | Enum cases, Codable, validation |
| Event | 20 | Model, validation, encoding |
| UserStreak | 25 | Model, computed properties, business logic |
| StreakFreeze | 15 | Model, state management |
| Streak Calculation | 30 | Core algorithm, timezones, edge cases |
| Streak Status | 12 | State determination, leeway |
| GamificationService | 25 | Protocol contract, CRUD operations |
| GamificationManager | 30 | Manager API, listeners, callbacks |
| Validation | 15 | Input validation, error handling |
| Freeze Behavior | 18 | Auto/manual consume, history |
| AsyncStream | 12 | Reactive updates, lifecycle |
| Integration | 20 | End-to-end, errors, concurrency |
| Goal-Based Streaks | 25 | eventsRequiredPerDay, goal progress |
| Server Calculation | 10 | Cloud Function integration |
| **TOTAL** | **267 tests** | **Complete coverage** |

---

## Test Organization Strategy

### Priority Levels

**P0 - Critical (Run on every commit):**
- Streak calculation algorithm (30 tests)
- Validation tests (15 tests)
- GamificationManager core (15 tests)
- Total: ~60 tests

**P1 - High (Run before merge):**
- Model tests (70 tests)
- Service protocol (25 tests)
- Freeze behavior (18 tests)
- Total: ~113 tests

**P2 - Medium (Run nightly):**
- Integration tests (20 tests)
- AsyncStream tests (12 tests)
- Error handling (included in integration)
- Total: ~32 tests

**P3 - Low (Run weekly):**
- Edge cases and stress tests
- Performance benchmarks
- Concurrency stress tests

### Test Data Fixtures

Create shared test fixtures in `TestHelpers.swift`:

```swift
enum TestFixtures {
    // Users
    static let testUserId = "test_user_123"
    static let testUserId2 = "test_user_456"

    // Streak IDs
    static let workoutStreakId = "workout"
    static let readingStreakId = "reading"
    static let invalidStreakId = "Invalid-Streak!"

    // Timezones
    static let nyTimezone = "America/New_York"
    static let laTimezone = "America/Los_Angeles"
    static let tokyoTimezone = "Asia/Tokyo"

    // Dates
    static func date(year: Int = 2024, month: Int = 1, day: Int = 1,
                     hour: Int = 12, timezone: String = nyTimezone) -> Date

    // Events
    static func events(count: Int, startingDaysAgo: Int = 0) -> [Event]
    static func eventsWithGap(beforeGap: Int, afterGap: Int, gapDays: Int) -> [Event]

    // Streaks
    static let activeStreak = UserStreak(...)
    static let brokenStreak = UserStreak(...)
    static let atRiskStreak = UserStreak(...)

    // Freezes
    static let unusedFreeze = StreakFreeze(...)
    static let usedFreeze = StreakFreeze(...)
}
```

### Mock Logger for Testing

```swift
@MainActor
class MockLogger: GamificationLogger {
    var events: [GamificationLogEvent] = []
    var userProperties: [[String: Any]] = []

    func trackEvent(event: GamificationLogEvent) {
        events.append(event)
    }

    func addUserProperties(dict: [String: Any], isHighPriority: Bool) {
        userProperties.append(dict)
    }

    func reset() {
        events.removeAll()
        userProperties.removeAll()
    }
}
```

### Test Execution Commands

```bash
# Run all tests
swift test

# Run specific test suite
swift test --filter EventValueTests

# Run specific test
swift test --filter "EventValueTests.testStringCodable"

# Run with coverage
swift test --enable-code-coverage

# Run P0 critical tests only
swift test --filter "StreakCalculationTests|ValidationTests|GamificationManagerTests"

# Run parallel (faster)
swift test --parallel
```

---

## Test Maintenance Guidelines

1. **Add test for every bug fix** - Prevent regressions
2. **Update tests when adding features** - Keep coverage high
3. **Remove obsolete tests** - When features are removed
4. **Keep test names descriptive** - Explain what is being tested
5. **Use arrange-act-assert pattern** - Consistent structure
6. **Mock external dependencies** - Tests should be isolated
7. **Test both success and failure paths** - Error cases matter
8. **Avoid test interdependencies** - Each test standalone
9. **Use fixtures for common data** - DRY principle
10. **Document complex test scenarios** - Help future maintainers

---

## Phase Completion Checklist

### Phase 1: Foundation Models ✅
- ☐ All 6 model files created
- ☐ All models Codable, Sendable, Equatable
- ☐ All models have mock() factory
- ☐ All models have eventParameters
- ☐ All CodingKeys use snake_case
- ☐ Build succeeds: `swift build`

### Phase 2: Service Protocol ✅
- ☐ GamificationService.swift complete
- ☐ All 18 methods defined
- ☐ All edge cases documented in comments
- ☐ No Firebase types in signatures
- ☐ Build succeeds: `swift build`

### Phase 3: Manager Implementation ✅
- ☐ GamificationManager.swift complete
- ☐ All public API methods implemented
- ☐ Listener management working
- ☐ Callbacks configuration working
- ☐ Event enum complete (18+ events)
- ☐ Build succeeds: `swift build`

### Phase 4: Mock Service ✅
- ☐ MockGamificationService.swift complete
- ☐ All protocol methods implemented
- ☐ @Published state working
- ☐ AsyncStream from @Published working
- ☐ Calculation extension working
- ☐ Build succeeds: `swift build`

### Phase 5: Testing ✅
- ☐ All 7 critical tests passing
- ☐ Model tests passing
- ☐ Service tests passing
- ☐ Manager tests passing
- ☐ All edge cases covered
- ☐ Tests succeed: `swift test`

---

## Final Validation Before Release

- ☐ All 102 checkpoints completed
- ☐ All critical edge cases tested
- ☐ Documentation complete (inline comments)
- ☐ CLAUDE.md up to date
- ☐ RESEARCH.md reflects implementation
- ☐ No external dependencies (verify Package.swift)
- ☐ All public APIs have examples in comments
- ☐ Build succeeds in Release mode
- ☐ All tests pass
- ☐ README.md created (if needed)

---

## Next Steps After Base Package

1. Create SwiftfulGamificationFirebase package (separate repo)
2. Implement FirebaseGamificationService
3. Add Firestore conversion extensions
4. Test integration with SwiftfulStarterProject
5. Deploy Cloud Functions for server-side calculation (optional)
6. Publish to Swift Package Index

---

**Document Status:** Ready for Implementation
**Total Checkpoints:** 102
**Estimated Time:** 8-12 hours for experienced Swift developer
**Last Updated:** 2025-09-30
