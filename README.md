### 🚀 Learn how to build and use this package: https://www.swiftful-thinking.com/offers/REyNLwwH

# Gamification Manager for Swift 6 🎮

A reusable gamification system for Swift applications, built for Swift 6. Includes `@Observable` support.

![Platform: iOS/macOS](https://img.shields.io/badge/platform-iOS%20%7C%20macOS-blue)

Pre-built dependencies*:

- Mock: Included
- Firebase: https://github.com/SwiftfulThinking/SwiftfulGamificationFirebase

\* Created another? Send the url in [issues](https://github.com/SwiftfulThinking/SwiftfulGamification/issues)! 🥳

## Features

- ✅ **Streaks**: Track daily user activity with goals, freezes, and auto-recovery
- ✅ **Experience Points**: Track XP with time windows (today, week, month, year, all-time)
- ✅ **Progress**: Track arbitrary progress values with metadata filtering

## Quick Examples

```swift
// Streaks
Task {
    try await streakManager.addStreakEvent()
    print(streakManager.currentStreakData.currentStreak) // 7 days
}

// Experience Points
Task {
    try await xpManager.addExperiencePoints(points: 100)
    print(xpManager.currentExperiencePointsData.pointsAllTime) // 5000 XP
}

// Progress
Task {
    try await progressManager.addProgress(id: "level_1", value: 0.75)
    print(progressManager.getProgress(id: "level_1")) // 0.75
}
```

## Setup

<details>
<summary> Details (Click to expand) </summary>
<br>

#### Create instances of managers:

```swift
// Streaks
let streakManager = StreakManager(
    services: any StreakServices,
    configuration: StreakConfiguration,
    logger: GamificationLogger?
)

// Experience Points
let xpManager = ExperiencePointsManager(
    services: any ExperiencePointsServices,
    configuration: ExperiencePointsConfiguration,
    logger: GamificationLogger?
)

// Progress
let progressManager = ProgressManager(
    services: any ProgressServices,
    configuration: ProgressConfiguration,
    logger: GamificationLogger?
)
```

#### Development vs Production:

```swift
#if DEBUG
let streakManager = StreakManager(
    services: MockStreakServices(),
    configuration: StreakConfiguration.mockDefault()
)
#else
let streakManager = StreakManager(
    services: FirebaseStreakServices(),
    configuration: StreakConfiguration.myConfig()
)
#endif
```

#### Optionally add to SwiftUI environment as @Observable

```swift
Text("Hello, world!")
    .environment(streakManager)
    .environment(xpManager)
    .environment(progressManager)
```

</details>

## Inject dependencies

<details>
<summary> Details (Click to expand) </summary>
<br>

Each manager is initialized with a `Services` protocol. This is a public protocol you can use to create your own dependency.

`Mock` implementations are included for SwiftUI previews and testing.

```swift
// Mock with blank data
let services = MockStreakServices()

// Mock with custom data
let data = CurrentStreakData.mockActive(currentStreak: 10)
let services = MockStreakServices(data: data)
```

Other services are not directly included, so that the developer can pick-and-choose which dependencies to add to the project.

You can create your own services by conforming to the protocols:

```swift
public protocol StreakServices: Sendable {
    var remote: RemoteStreakService { get }
    var local: LocalStreakPersistence { get }
}

public protocol ExperiencePointsServices: Sendable {
    var remote: RemoteExperiencePointsService { get }
    var local: LocalExperiencePointsPersistence { get }
}

public protocol ProgressServices: Sendable {
    var remote: RemoteProgressService { get }
    var local: LocalProgressPersistence { get }
}
```

</details>

## Streaks

<details>
<summary> Details (Click to expand) </summary>
<br>

### Configuration

```swift
let config = StreakConfiguration(
    streakId: "main",
    eventsRequiredPerDay: 1,          // Number of events needed per day
    useServerCalculation: false,      // Client or server-side calculation
    leewayHours: 4,                   // Grace period around midnight
    autoConsumeFreeze: true           // Auto-use freezes to save streaks
)
```

### Log In / Log Out

```swift
// Log in (starts remote listener and loads cached data)
try await streakManager.logIn(userId: "user_123")

// Log out (stops listeners and clears local data)
streakManager.logOut()
```

### Add Streak Events

```swift
// Add event for today
try await streakManager.addStreakEvent(
    timestamp: Date(),
    metadata: ["action": "completed_workout"]
)

// Get all events
let events = try await streakManager.getAllStreakEvents()

// Delete all events (for testing)
try await streakManager.deleteAllStreakEvents()
```

### Streak Freezes

```swift
// Add a freeze (protects streak for 1 day)
try await streakManager.addStreakFreeze(
    id: UUID().uuidString,
    expiresAt: Date().addingTimeInterval(86400 * 30) // 30 days from now
)

// Manually use freezes to save current streak
try await streakManager.useStreakFreezes()

// Get all freezes
let freezes = try await streakManager.getAllStreakFreezes()
```

### Access Current Streak Data

```swift
let data = streakManager.currentStreakData

// Streak info
data.currentStreak              // Current streak count
data.longestStreak              // All-time longest streak
data.streakStartDate            // When current streak started
data.lastEventDate              // Last event timestamp
data.status                     // active, atRisk, broken, or noEvents

// Goal-based tracking
data.eventsRequiredPerDay       // Events needed per day
data.todayEventCount            // Events logged today
data.isGoalMet                  // Has today's goal been met?
data.goalProgress               // Progress toward today's goal (0.0-1.0)

// Freeze management
data.freezesRemaining           // Available freezes
data.freezesNeededToSaveStreak  // Freezes needed to save streak
data.canStreakBeSaved           // Can freezes save the streak?

// Calendar display
data.getCalendarDaysWithEvents()          // All days with events (last 60 days)
data.getCalendarDaysWithEventsThisWeek()  // Days with events this week
```

### Recalculate Streak

```swift
// Force recalculation (useful after config changes)
streakManager.recalculateStreak()
```

### Streak Status

```swift
switch streakManager.currentStreakData.status {
case .noEvents:
    print("No streak started yet")
case .active(let daysSince):
    print("Active streak! Last event: \(daysSince) days ago")
case .atRisk:
    print("Streak at risk! Log an event today!")
case .broken(let daysSince):
    print("Streak broken. Last event: \(daysSince) days ago")
}
```

</details>

## Experience Points

<details>
<summary> Details (Click to expand) </summary>
<br>

### Configuration

```swift
let config = ExperiencePointsConfiguration(
    experienceKey: "main",
    useServerCalculation: false  // Client or server-side calculation
)
```

### Log In / Log Out

```swift
// Log in (starts remote listener and loads cached data)
try await xpManager.logIn(userId: "user_123")

// Log out (stops listeners and clears local data)
xpManager.logOut()
```

### Add Experience Points

```swift
// Add XP with metadata
try await xpManager.addExperiencePoints(
    points: 100,
    metadata: ["action": "completed_level", "level": 5]
)

// Get all events
let events = try await xpManager.getAllExperiencePointsEvents()

// Get events filtered by metadata
let levelEvents = try await xpManager.getAllExperiencePointsEvents(
    forField: "level",
    equalTo: 5
)

// Delete all events (for testing)
try await xpManager.deleteAllExperiencePointsEvents()
```

### Access Current XP Data

```swift
let data = xpManager.currentExperiencePointsData

// Points by time window
data.pointsAllTime          // Total XP earned (all-time)
data.pointsToday            // Points earned today
data.pointsThisWeek         // Points earned this week (Sunday-today)
data.pointsLast7Days        // Points earned last 7 days (rolling)
data.pointsThisMonth        // Points earned this month (1st-today)
data.pointsLast30Days       // Points earned last 30 days (rolling)
data.pointsThisYear         // Points earned this year (Jan 1-today)
data.pointsLast12Months     // Points earned last 12 months (rolling)

// Event tracking
data.eventsTodayCount       // Number of XP events today
data.lastEventDate          // Last event timestamp

// Timestamps
data.createdAt              // First event ever
data.updatedAt              // Last update timestamp

// Status
data.isDataStale            // Data hasn't updated in 1+ hour
data.daysSinceLastEvent     // Days since last XP event

// Calendar display
data.getCalendarDaysWithEvents()          // All days with events (last 60 days)
data.getCalendarDaysWithEventsThisWeek()  // Days with events this week
```

### Recalculate XP

```swift
// Force recalculation (useful after config changes)
xpManager.recalculateExperiencePoints()
```

</details>

## Progress

<details>
<summary> Details (Click to expand) </summary>
<br>

### Configuration

```swift
let config = ProgressConfiguration(
    progressKey: "main"
)
```

### Log In / Log Out

```swift
// Log in (bulk loads all progress and starts streaming updates)
try await progressManager.logIn(userId: "user_123")

// Log out (stops listeners and clears local data)
await progressManager.logOut()
```

### Add Progress

```swift
// Add or update progress (0.0 to 1.0)
try await progressManager.addProgress(
    id: "level_1",
    value: 0.75,
    metadata: ["world": "forest", "difficulty": "hard"]
)

// Progress NEVER decreases - only increases
// Attempting to set a lower value will be ignored
```

**⚠️ Important: ID Sanitization**

Progress IDs are automatically sanitized before saving to ensure database compatibility:
- Non-alphanumeric characters are replaced with underscores
- IDs are converted to lowercase
- Examples:
  - `"Alpha 123!"` → `"alpha_123"`
  - `"Alpha 123$"` → `"alpha_123"`
  - `"Alpha 123"` → `"alpha_123"`

All three example IDs above would save to the same key `"alpha_123"`, so the last write would overwrite previous values. Choose unique IDs accordingly.

### Get Progress

```swift
// Get single progress value (synchronous)
let progress = progressManager.getProgress(id: "level_1") // 0.75

// Get full progress item (synchronous)
let item = progressManager.getProgressItem(id: "level_1")
print(item?.dateModified) // Last update time

// Get all progress values (synchronous)
let allProgress = progressManager.getAllProgress() // ["level_1": 0.75, "level_2": 0.5]

// Get all progress items (synchronous)
let allItems = progressManager.getAllProgressItems()
```

### Filter by Metadata

```swift
// Get progress items by metadata field
let forestLevels = progressManager.getProgressItems(
    forMetadataField: "world",
    equalTo: "forest"
)

// Get max progress for filtered items
let maxForestProgress = progressManager.getMaxProgress(
    forMetadataField: "world",
    equalTo: "forest"
) // 0.75 (highest progress in forest world)
```

### Delete Progress

```swift
// Delete single item
try await progressManager.deleteProgress(id: "level_1")

// Delete all items
try await progressManager.deleteAllProgress()
```

### Progress Features

- **Synchronous reads**: All get methods are synchronous (read from in-memory cache)
- **Optimistic updates**: UI updates immediately, remote sync happens in background
- **Never decreases**: Progress values only increase, never decrease
- **Conflict resolution**: If local is ahead of remote, local value is pushed to remote
- **Metadata filtering**: Filter and query progress by custom metadata fields
- **Real-time sync**: Automatic streaming of updates from remote

</details>

## Metadata System

<details>
<summary> Details (Click to expand) </summary>
<br>

All events support metadata as `[String: GamificationDictionaryValue]`:

```swift
// Supported types
metadata["string_key"] = "value"
metadata["int_key"] = 42
metadata["double_key"] = 3.14
metadata["bool_key"] = true
metadata["date_key"] = Date()
```

### Use Cases

```swift
// Streak events - track what action triggered the event
try await streakManager.addStreakEvent(
    metadata: ["action": "workout", "duration_minutes": 30]
)

// XP events - track source of XP
try await xpManager.addExperiencePoints(
    points: 100,
    metadata: ["source": "quest", "quest_id": "forest_1", "difficulty": "hard"]
)

// Progress - categorize and filter
try await progressManager.addProgress(
    id: "level_1",
    value: 0.75,
    metadata: ["world": "forest", "difficulty": "hard", "stars": 2]
)

// Filter by metadata
let forestLevels = progressManager.getProgressItems(
    forMetadataField: "world",
    equalTo: "forest"
)
```

</details>

## Analytics Integration

<details>
<summary> Details (Click to expand) </summary>
<br>

All managers support optional analytics logging:

```swift
// Create logger (see SwiftfulLogging package)
let logger = LogManager(services: [
    FirebaseAnalyticsService(),
    MixpanelService()
])

// Inject into managers
let streakManager = StreakManager(
    services: services,
    configuration: config,
    logger: logger
)
```

### Tracked Events

**StreakManager** (15 events):
- `StreakMan_RemoteListener_Start/Success/Fail`
- `StreakMan_SaveLocal_Start/Success/Fail`
- `StreakMan_CalculateStreak_Start/Success/Fail`
- `StreakMan_Freeze_AutoConsumed`
- `StreakMan_AddStreakFreeze_Start/Success/Fail`
- `StreakMan_UseStreakFreeze_Start/Success/Fail`

**ExperiencePointsManager** (12 events):
- `XPMan_RemoteListener_Start/Success/Fail`
- `XPMan_SaveLocal_Start/Success/Fail`
- `XPMan_CalculateXP_Start/Success/Fail`
- `XPMan_AddExperiencePoints_Start/Success/Fail`

**ProgressManager** (13 events):
- `ProgressMan_BulkLoad_Start/Success/Fail`
- `ProgressMan_RemoteListener_Start/Success/Fail`
- `ProgressMan_SaveLocal_Success/Fail`
- `ProgressMan_AddProgress_Start/Success/Fail`
- `ProgressMan_DeleteProgress_Start/Success/Fail`
- `ProgressMan_DeleteAllProgress_Start/Success/Fail`

### Event Parameters

All events include relevant parameters:

```swift
// Streak data
"current_streak_current_streak": 7
"current_streak_longest_streak": 30
"current_streak_today_event_count": 2

// XP data
"current_xp_points_all_time": 5000
"current_xp_points_today": 250
"current_xp_events_today_count": 3

// Progress data
"progress_id": "level_1"
"progress_value": 0.75
```

</details>

## Mock Factories

<details>
<summary> Details (Click to expand) </summary>
<br>

All models include mock factory methods for testing:

### Streaks

```swift
// Blank streak (no events)
CurrentStreakData.blank(streakId: "main")

// Default mock
CurrentStreakData.mock()

// Active streak
CurrentStreakData.mockActive(currentStreak: 10)

// At risk streak
CurrentStreakData.mockAtRisk()

// Goal-based streak
CurrentStreakData.mockGoalBased(
    currentStreak: 5,
    eventsRequiredPerDay: 3,
    todayEventCount: 1
)

// Mock events
StreakEvent.mock(daysAgo: 0) // Event today
StreakEvent.mock(daysAgo: 3) // Event 3 days ago

// Mock freezes
StreakFreeze.mockUnused()
StreakFreeze.mockUsed()
StreakFreeze.mockExpired()
```

### Experience Points

```swift
// Blank XP (zero points)
CurrentExperiencePointsData.blank(experienceKey: "main")

// Default mock
CurrentExperiencePointsData.mock()

// Empty XP (no events)
CurrentExperiencePointsData.mockEmpty()

// Active user
CurrentExperiencePointsData.mockActive(pointsToday: 250)

// With recent events
CurrentExperiencePointsData.mockWithRecentEvents(eventCount: 10)

// Mock events
ExperiencePointsEvent.mock(daysAgo: 0, points: 100)
```

### Progress

```swift
// Mock progress item
ProgressItem.mock(
    id: "level_1",
    value: 0.75,
    metadata: ["world": "forest"]
)
```

</details>

## Architecture

<details>
<summary> Details (Click to expand) </summary>
<br>

SwiftfulGamification follows the **SwiftfulThinking Provider Pattern**:

1. **Base Package** (this package):
   - Zero external dependencies (except IdentifiableByString)
   - Defines all protocols and models
   - Includes Mock implementations
   - All types are `Codable` and `Sendable`

2. **Implementation Packages** (separate SPM):
   - SwiftfulGamificationFirebase: Firebase implementation
   - Implements service protocols
   - Handles provider-specific logic
   - Extension files for model conversions

3. **Manager Classes**:
   - `@MainActor` for UI thread safety
   - `@Observable` for SwiftUI integration
   - Dependency injection via protocols
   - Optional logger for analytics
   - Comprehensive event tracking

### Key Features

- **Swift 6 concurrency**: Full async/await support
- **Thread safety**: `@MainActor` isolation, `Sendable` conformance
- **SwiftUI ready**: `@Observable` support
- **Offline first**: Local persistence with remote sync
- **Optimistic updates**: Immediate UI updates
- **Real-time sync**: AsyncStream-based listeners
- **Type-safe**: Protocol-based architecture
- **Testable**: Mock implementations included

### File Structure

```
SwiftfulGamification/
├── Streaks/
│   ├── StreakManager.swift
│   ├── Services/
│   │   ├── StreakService.swift (protocols)
│   │   ├── Remote/ (remote storage)
│   │   └── Local/ (local persistence)
│   ├── Models/
│   │   ├── CurrentStreakData.swift
│   │   ├── StreakEvent.swift
│   │   ├── StreakFreeze.swift
│   │   └── StreakConfiguration.swift
│   └── Utilities/
│       └── StreakCalculator.swift (pure functions)
├── ExperiencePoints/
│   ├── ExperiencePointsManager.swift
│   ├── Services/
│   ├── Models/
│   └── Utilities/
├── Progress/
│   ├── ProgressManager.swift
│   ├── Services/
│   └── Models/
└── Shared/
    └── Models/ (shared types)
```

</details>

## Requirements

- iOS 17.0+ / macOS 14.0+
- Swift 6.1+
- Xcode 16.0+

## Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/SwiftfulThinking/SwiftfulGamification.git", branch: "main")
]
```

## Contributing

Community contributions are encouraged! Please ensure that your code adheres to the project's existing coding style and structure.

- [Open an issue](https://github.com/SwiftfulThinking/SwiftfulGamification/issues) for issues with the existing codebase.
- [Open a discussion](https://github.com/SwiftfulThinking/SwiftfulGamification/discussions) for new feature requests.
- [Submit a pull request](https://github.com/SwiftfulThinking/SwiftfulGamification/pulls) when the feature is ready.

## Related Packages

- [SwiftfulGamificationFirebase](https://github.com/SwiftfulThinking/SwiftfulGamificationFirebase) - Firebase implementation
- [SwiftfulLogging](https://github.com/SwiftfulThinking/SwiftfulLogging) - Analytics logging
- [SwiftfulStarterProject](https://github.com/SwiftfulThinking/SwiftfulStarterProject) - Full integration example

## License

MIT License. See LICENSE file for details.
