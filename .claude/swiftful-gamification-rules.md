# SwiftfulGamification

Domain-specific gamification managers for Swift. Three independent modules — Streaks, Experience Points, and Progress — each with client/server calculation, offline persistence, and real-time sync. iOS only.

## When to Use

This package is for apps that need **gamification mechanics** — streak tracking, XP accumulation, or item completion progress. Most apps will NOT need all three modules. Many apps won't need any. Evaluate each module independently based on the app's requirements.

IMPORTANT: Not every app needs gamification. Only add a manager when the feature genuinely benefits the user experience. One module is the most common use case. Using all three is rare.

## Modules Overview

- **StreakManager** — "Did the user show up today?" Tracks consecutive-day engagement with configurable goals, freezes, and leeway
- **ExperiencePointsManager** — "How much did the user do?" Accumulates points over time windows (today, week, month, year, all-time, rolling periods)
- **ProgressManager** — "How far along is this specific thing?" Tracks 0.0–1.0 completion per item with offline sync and metadata

Each manager is `@Observable` `@MainActor` — safe for SwiftUI observation. Each requires a `Services` conformance (remote + local) and a `Configuration`.

## Initialization

All three managers follow the same init pattern: `services` + `configuration` + optional `logger`.

### StreakManager

```swift
let streakManager = StreakManager(
    services: ProdStreakServices(),     // or MockStreakServices()
    configuration: StreakConfiguration(
        streakKey: "daily",             // REQUIRED — unique identifier for this streak
        eventsRequiredPerDay: 1,        // default 1, set >1 for goal-based streaks
        useServerCalculation: false,    // default false
        leewayHours: 0,                // default 0, grace period hours around midnight
        freezeBehavior: .manuallyConsumeFreezes  // default, also: .autoConsumeFreezes, .noFreezes
    ),
    logger: logManager                  // optional GamificationLogger
)
```

### ExperiencePointsManager

```swift
let xpManager = ExperiencePointsManager(
    services: ProdExperiencePointsServices(),  // or MockExperiencePointsServices()
    configuration: ExperiencePointsConfiguration(
        experienceKey: "general",       // REQUIRED — unique identifier for this XP type
        useServerCalculation: false     // default false
    ),
    logger: logManager                  // optional GamificationLogger
)
```

### ProgressManager

```swift
let progressManager = ProgressManager(
    services: ProdProgressServices(),   // or MockProgressServices()
    configuration: ProgressConfiguration(
        progressKey: "lessons"          // REQUIRED — unique identifier for this progress group
    ),
    logger: logManager                  // optional GamificationLogger
)
```

IMPORTANT: All keys (`streakKey`, `experienceKey`, `progressKey`) must be sanitized — no whitespace or special characters. The init will crash via `precondition` if the key is invalid.

## Multiple Instances

Each manager can be instantiated **multiple times** with different keys for different purposes:

```swift
// Two different streaks
let dailyStreakManager = StreakManager(services: ..., configuration: StreakConfiguration(streakKey: "daily"))
let workoutStreakManager = StreakManager(services: ..., configuration: StreakConfiguration(streakKey: "workout", eventsRequiredPerDay: 3))

// Two different XP types
let generalXPManager = ExperiencePointsManager(services: ..., configuration: ExperiencePointsConfiguration(experienceKey: "general"))
let battleXPManager = ExperiencePointsManager(services: ..., configuration: ExperiencePointsConfiguration(experienceKey: "battle"))

// Two different progress groups
let lessonProgressManager = ProgressManager(services: ..., configuration: ProgressConfiguration(progressKey: "lessons"))
let achievementProgressManager = ProgressManager(services: ..., configuration: ProgressConfiguration(progressKey: "achievements"))
```

Alternatively, XP and Progress can handle multiple types within a **single manager** using metadata and filtering:

```swift
// Single XP manager — filter by metadata
try await xpManager.addExperiencePoints(points: 50, metadata: ["category": .string("battle")])
let battleEvents = try await xpManager.getAllExperiencePointsEvents(forField: "category", equalTo: .string("battle"))

// Single Progress manager — filter by metadata
try await progressManager.addProgress(id: "lesson_1", value: 0.5, metadata: ["course": .string("swift")])
let swiftItems = progressManager.getProgressItems(forMetadataField: "course", equalTo: .string("swift"))
```

When deciding between multiple managers vs. one manager with metadata: use **multiple managers** when each type needs its own remote collection or independent lifecycle. Use **one manager with metadata** when types share a collection and lifecycle.

## ProgressManager as a Completion Tracker

The ProgressManager can be used as a **binary completion tracker** (0 or 1 only) instead of fractional progress. This is useful for tracking whether a user has completed an item without needing intermediate values:

```swift
// Mark item as completed
try await progressManager.addProgress(id: "onboarding_step_1", value: 1.0)

// Check if completed
let isComplete = progressManager.getProgress(id: "onboarding_step_1") >= 1.0
```

Progress values never decrease — once an item reaches 1.0, it stays complete.

## Services Pattern

Each manager takes a `Services` protocol that combines a `remote` service and a `local` persistence. The consuming app creates its own conformance:

```swift
@MainActor
struct ProdStreakServices: StreakServices {
    let remote: RemoteStreakService
    let local: LocalStreakPersistence

    init() {
        self.remote = FirebaseRemoteStreakService(rootCollectionName: "streaks")  // from SwiftfulGamificationFirebase
        self.local = FileManagerStreakPersistence()
    }
}
```

Local persistence options:
- **Streaks:** `FileManagerStreakPersistence()` (production) or `MockLocalStreakPersistence()` (mocks)
- **Experience Points:** `FileManagerExperiencePointsPersistence()` (production) or `MockLocalExperiencePointsPersistence()` (mocks)
- **Progress:** `SwiftDataProgressPersistence()` (production) or `MockLocalProgressPersistence()` (mocks)

Remote services are NOT included in this package — they come from a companion package like `SwiftfulGamificationFirebase`. For mocks, use `MockStreakServices()`, `MockExperiencePointsServices()`, `MockProgressServices()`.

## Lifecycle

All three managers follow the same lifecycle: `logIn(userId:)` → use APIs → `logOut()`.

```swift
// On sign in — call logIn on each manager
try await streakManager.logIn(userId: userId)
try await xpManager.logIn(userId: userId)
try await progressManager.logIn(userId: userId)

// On sign out — call logOut on each manager
streakManager.logOut()
xpManager.logOut()
await progressManager.logOut()  // Note: only ProgressManager.logOut() is async
```

IMPORTANT: `logIn` must be called before any data operations. It attaches remote listeners and syncs data. Calling APIs before `logIn` will throw `notLoggedIn` errors.

## Metadata

All event types support metadata via `[String: GamificationDictionaryValue]`. Supported value types: `.string`, `.bool`, `.int`, `.double`, `.float`, `.cgFloat`. Date is NOT a supported value type — store dates as ISO 8601 strings or timestamps.

## Integration

Conform your logger to `GamificationLogger` to receive internal events:

```swift
extension YourLogManager: @retroactive GamificationLogger {
    public func trackEvent(event: any GamificationLogEvent) {
        trackEvent(eventName: event.eventName, parameters: event.parameters, type: event.type)
    }
    public func addUserProperties(dict: [String: Any], isHighPriority: Bool) {
        // forward to your analytics
    }
}
```

## Mocks

```swift
// Mock with default empty state
let streakManager = StreakManager(services: MockStreakServices(), configuration: .mockDefault())
let xpManager = ExperiencePointsManager(services: MockExperiencePointsServices(), configuration: .mockDefault())
let progressManager = ProgressManager(services: MockProgressServices(), configuration: .mockDefault())

// Mock with pre-populated data
let streakManager = StreakManager(services: MockStreakServices(streak: CurrentStreakData.mock()), configuration: .mockDefault())
let xpManager = ExperiencePointsManager(services: MockExperiencePointsServices(data: CurrentExperiencePointsData.mock()), configuration: .mockDefault())
let progressManager = ProgressManager(services: MockProgressServices(items: [ProgressItem.mock()]), configuration: .mockDefault())
```

## VIPER Integration

IMPORTANT: Views and Presenters should NEVER import or reference `SwiftfulGamification` directly. This package belongs exclusively in the manager/interactor layer.

Managers are created in the **Dependencies** layer with a configuration and registered by key (since multiple instances may exist):

```swift
// Dependencies — create managers
static let streakConfiguration = StreakConfiguration(streakKey: "daily", eventsRequiredPerDay: 1)
let streakManager = StreakManager(services: ProdStreakServices(), configuration: Dependencies.streakConfiguration, logger: logManager)
container.register(StreakManager.self, key: Dependencies.streakConfiguration.streakKey, service: streakManager)

// Interactor — resolves by key
let streakManager = container.resolve(StreakManager.self, key: Dependencies.streakConfiguration.streakKey)!
```

The Interactor wraps manager calls and exposes them to Presenters. Presenters call interactor methods — never managers directly.
