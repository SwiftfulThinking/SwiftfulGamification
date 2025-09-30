# Streak Implementation Research & Best Practices

## Executive Summary

This document outlines comprehensive research findings for implementing a production-ready, multi-device, timezone-safe streak tracking system for iOS applications. The research covers timezone handling, multi-device synchronization, data modeling, offline-first architecture, conflict resolution, and testing strategies.

---

## 1. Core Timezone Principles

### 1.1 Golden Rules

**CRITICAL RULES:**
1. **ALWAYS store timestamps in UTC (Unix timestamp)** on server/database
2. **ALWAYS perform day calculations in user's local timezone**
3. **ALWAYS use `Calendar.current.startOfDay(for:)` for date comparisons**
4. **NEVER store UTC offset** (it changes with DST)
5. **ALWAYS store timezone identifier** (e.g., "America/Los_Angeles") if needed

### 1.2 Why This Matters

**Real-world example from Duolingo:**
- User in New York (EST) completes activity at 11:30 PM
- User immediately flies to Los Angeles (PST, 3 hours behind)
- It's now 8:30 PM PST on the same calendar day
- If using server UTC time, streak appears broken
- If using local timezone, streak is maintained correctly

**Key insight:** Users think in terms of their local calendar days, not UTC days.

### 1.3 iOS Calendar API Best Practices

```swift
// ✅ CORRECT: Get start of day in user's timezone
let calendar = Calendar.current
let todayStart = calendar.startOfDay(for: Date())

// ✅ CORRECT: Compare dates in user's timezone
let calendar = Calendar.current
let components1 = calendar.dateComponents([.year, .month, .day], from: date1)
let components2 = calendar.dateComponents([.year, .month, .day], from: date2)
let isSameDay = components1 == components2

// ❌ WRONG: Using Date comparison directly
if date1 == date2 { } // Compares exact timestamps, not calendar days

// ❌ WRONG: Creating calendar with fixed timezone
var calendar = Calendar.current
calendar.timeZone = TimeZone(identifier: "UTC")! // Don't do this for streak logic
```

### 1.4 Timezone Change Detection

**iOS provides notifications for timezone changes:**

```swift
// Listen for timezone changes
NotificationCenter.default.addObserver(
    self,
    selector: #selector(timeZoneChanged),
    name: NSNotification.Name.NSSystemTimeZoneDidChange,
    object: nil
)

// Also triggered by applicationSignificantTimeChange(_:) in AppDelegate
```

**When timezone changes:**
1. Recalculate current streak status
2. Update local cache with new timezone-aware values
3. Sync to server with updated calculations

---

## 2. Multi-Device Synchronization Strategy

### 2.1 The Problem

**Scenario:**
- User logs event on iPhone at 11:55 PM (streak count = 5)
- User logs event on iPad at 11:57 PM (streak count = 5)
- Both devices try to sync: which one wins?
- If handled incorrectly, streak could be duplicated or lost

### 2.2 Recommended Conflict Resolution: Last-Write-Wins (LWW) with Dual Calculation Strategy

**Why Last-Write-Wins:**
- Simple to implement and reason about
- Works well for streak data (user can't be on two devices simultaneously completing the same streak)
- Server maintains source of truth
- Edge cases are rare and acceptable

**Implementation (Hybrid Server/Client):**
1. Each write includes a timestamp
2. Server compares timestamps and accepts newer data
3. **Server recalculates streak based on complete event history (if Cloud Functions deployed)**
4. **Client-side fallback: If server calculation unavailable, client calculates locally**
5. Devices receive authoritative streak count from server (or use local calculation)

**Configuration Flag:**
```swift
struct GamificationConfig {
    let useServerCalculation: Bool  // Enable/disable server-side calculation
    let streakId: String
}

// In Firebase service
if config.useServerCalculation {
    // Trigger Cloud Function to recalculate
    try await callCloudFunction("calculateStreak", data: eventData)
} else {
    // Client-side calculation
    let streak = calculateStreakLocally(events: allEvents)
    try await updateFirestore(streak: streak)
}
```

**Benefits:**
- Flexibility: Works with or without server deployment
- Migration path: Start client-side, move to server when ready
- Testing: Can compare server vs client calculations
- Fallback: If Cloud Function fails, client can calculate

**Alternative Considered - Vector Clocks / CRDTs:**
- More complex (overkill for streaks)
- Useful for collaborative editing, not applicable here
- Counter CRDTs exist but don't solve timezone/day boundary issues
- **Verdict:** Not necessary for streak use case

### 2.3 Sync Strategy

**Push-based synchronization:**
- Device logs event → immediately push to server
- Server processes event → returns updated streak count
- Device updates local cache with server response

**Handling offline:**
- Queue events locally with timestamps
- When connection restored, push all queued events in order
- Server processes all events and returns final streak state
- Local cache updated to match server

**Conflict resolution flow:**
```
Device A (11:55 PM): Log event → Server processes → Returns streak = 6
Device B (11:57 PM): Log event → Server sees duplicate day → Returns streak = 6 (not 7)
```

---

## 3. Data Model Design

### 3.1 Local Storage (Device)

**Must be synchronous and instant on app launch:**

```swift
struct StreakCache: Codable {
    let streakId: String              // e.g., "daily_workout"
    let userId: String
    let currentStreak: Int
    let longestStreak: Int
    let lastEventDate: Date           // UTC timestamp
    let lastEventTimezone: String     // e.g., "America/New_York"
    let lastSyncDate: Date?          // When last synced with server
    let cachedAt: Date               // When this cache was created
}
```

**Storage Strategy:**

**Base Package (SwiftfulGamification):**
```swift
protocol GamificationService: Sendable {
    // Synchronous local cache access
    func getCachedStreak() -> StreakCache?
    func setCachedStreak(_ streak: StreakCache)
}
```

**Firebase Package Implementation:**
```swift
// Uses FileManager for persistent storage
class FirebaseGamificationService: GamificationService {
    private let fileManager = FileManager.default
    private let cacheURL: URL

    init(streakId: String) {
        // Store in Application Support directory
        let appSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        self.cacheURL = appSupport
            .appendingPathComponent("Gamification")
            .appendingPathComponent("\(streakId).json")
    }

    func getCachedStreak() -> StreakCache? {
        guard let data = try? Data(contentsOf: cacheURL) else { return nil }
        return try? JSONDecoder().decode(StreakCache.self, from: data)
    }

    func setCachedStreak(_ streak: StreakCache) {
        let data = try? JSONEncoder().encode(streak)
        try? data?.write(to: cacheURL)
    }
}
```

**Mock Package Implementation:**
```swift
// Uses in-memory storage
class MockGamificationService: GamificationService {
    private var cache: StreakCache?

    func getCachedStreak() -> StreakCache? { cache }
    func setCachedStreak(_ streak: StreakCache) { cache = streak }
}
```

**Why FileManager over UserDefaults:**
- Per-file storage (one file per streak)
- No size limits (UserDefaults has ~4MB total limit)
- Easier to clear individual streak caches
- Better for future event history storage
- Still synchronous access

### 3.2 Firestore Schema

**CRITICAL REQUIREMENT: Top-level collections only (not nested under /users/)**
- Package may be deployed to projects without /users/ collection
- Must work standalone without assuming user collection structure

**Option A: Denormalized with Top-Level Collections (SELECTED)**

```
streaks/{userId}__{streakId}
{
    userId: "user123",
    streakId: "daily_workout",
    currentStreak: 5,
    longestStreak: 10,
    lastEventDate: Timestamp(UTC),
    lastEventTimezone: "America/New_York",
    totalEvents: 42,
    createdAt: Timestamp,
    updatedAt: Timestamp
}

streaks/{userId}__{streakId}/events/{eventId}
{
    eventId: "auto-generated",
    timestamp: Timestamp(UTC),
    timezone: "America/New_York",
    metadata: { ... }  // Optional: additional event data
}
```

**Document ID Pattern:** `{userId}__{streakId}`
- Example: `"abc123__daily_workout"`
- Ensures uniqueness
- Easy to query: `.whereField("userId", isEqualTo: userId)`
- Works without user collection dependency

**Why this structure:**
- ✅ Top-level collection (no /users/ dependency)
- ✅ Fast reads: Single doc read for current streak
- ✅ Scalable writes: Events in subcollection
- ✅ Query flexibility: Can fetch all events if needed
- ✅ Firestore best practice: Denormalize for read performance
- ✅ Supports multiple streaks per user

**Alternative Considered (REJECTED):**

```
// ❌ Nested under /users/ - REJECTED due to dependency requirement
users/{userId}/streaks/{streakId}

// ❌ Separate events collection - More complex, unnecessary
streaks/{userId}__{streakId}
events/{userId}__{streakId}__{eventId}
```

**Index Requirements:**
```
Collection: streaks
Composite Index: (userId ASC, streakId ASC)

Collection: streaks/{docId}/events
Composite Index: (timestamp DESC)
```

### 3.3 Summary of Key Architecture Decisions

**1. Server vs Client Calculation:**
- ✅ Configurable flag: `useServerCalculation: Bool`
- ✅ Client-side fallback if Cloud Functions not deployed
- ✅ Both methods implemented for flexibility

**2. Local Storage:**
- ✅ Protocol method: `getCachedStreak()` (synchronous)
- ✅ Firebase: Uses FileManager (Application Support directory)
- ✅ Mock: Uses in-memory storage
- ✅ Per-streak file: `{streakId}.json`

**3. Firestore Structure:**
- ✅ Top-level collection: `streaks/{userId}__{streakId}`
- ✅ Events subcollection: `streaks/{docId}/events/{eventId}`
- ✅ No dependency on /users/ collection
- ✅ Denormalized for read performance

---

## 4. Streak Calculation Logic

### 4.1 Core Algorithm

```swift
func calculateStreak(events: [Event], timezone: TimeZone) -> Int {
    // 1. Convert all event timestamps to user's timezone calendar days
    let calendar = Calendar.current
    calendar.timeZone = timezone

    let eventDays = events.map { event in
        calendar.startOfDay(for: event.timestamp)
    }.uniqued().sorted()

    // 2. Walk backwards from today to count consecutive days
    var streak = 0
    var expectedDate = calendar.startOfDay(for: Date())

    for eventDay in eventDays.reversed() {
        if calendar.isDate(eventDay, inSameDayAs: expectedDate) {
            streak += 1
            expectedDate = calendar.date(byAdding: .day, value: -1, to: expectedDate)!
        } else if eventDay < expectedDate {
            break  // Gap found, streak broken
        }
    }

    return streak
}
```

### 4.2 Edge Cases to Handle

**Edge Case 1: Multiple events in same day**
- Solution: Deduplicate to unique days only
- One event or ten events on same day = 1 day credit

**Edge Case 2: User travels across timezones**
- Solution: Calculate in user's CURRENT timezone
- Store timezone identifier with each event for historical accuracy

**Edge Case 3: Daylight Saving Time transitions**
- Solution: `Calendar.startOfDay` handles DST automatically
- No special logic needed

**Edge Case 4: User hasn't logged event today yet**
- Solution: Check if last event was yesterday
  - If yesterday: Streak is still active (can be extended today)
  - If 2+ days ago: Streak is broken

**Edge Case 5: Midnight boundary race condition**
- User logs event at 11:59:59 PM
- Server receives at 12:00:01 AM (next day)
- Solution: Use device timestamp, not server timestamp
- Or: Apply grace period (see section 7)

---

## 5. Streak Freeze Implementation

### 5.1 Concept

**Purpose:** Allow users to "freeze" their streak for X days, preventing it from breaking if they miss a day.

**Business Rules:**
- User earns/purchases streak freezes
- When streak would break, auto-consume a freeze
- Freeze "holds" the streak for that day
- Multiple freezes can be used on consecutive days

### 5.2 Data Model Extension

```swift
struct StreakFreeze: Codable, Identifiable {
    let id: String                    // Freeze ID
    let userId: String
    let streakId: String              // Which streak this applies to
    let earnedDate: Date              // When user earned it
    let usedDate: Date?               // When consumed (nil if unused)
    let expiresAt: Date?              // Optional expiration
}
```

**Firestore:**
```
users/{userId}/streaks/{streakId}/freezes/{freezeId}
{
    freezeId: "auto-generated",
    earnedDate: Timestamp,
    usedDate: Timestamp?,
    expiresAt: Timestamp?
}
```

### 5.3 Freeze Consumption Logic

```swift
func shouldConsumeFreeze(lastEventDate: Date, currentDate: Date) -> Bool {
    let calendar = Calendar.current
    let daysSince = calendar.dateComponents(
        [.day],
        from: calendar.startOfDay(for: lastEventDate),
        to: calendar.startOfDay(for: currentDate)
    ).day ?? 0

    // If exactly 2 days gap (missed 1 day), consume freeze
    return daysSince == 2
}
```

**Auto-freeze logic:**
1. User opens app
2. Check if streak would be broken
3. If yes, check for available freezes
4. Consume freeze automatically
5. Show UI notification: "Streak freeze used! 2 remaining"

**Manual freeze logic (alternative):**
1. User knows they'll miss tomorrow
2. User manually activates freeze in advance
3. Freeze marked as "scheduled" for specific date
4. When that date arrives, freeze auto-applies

---

## 6. Goal-Based Streaks

### 6.1 Concept Extension

**Basic Streak:** 1 event per day = streak continues
**Goal Streak:** X events per day = streak continues

**Example:**
- "Workout 3 times per day for 30 days"
- "Drink 8 glasses of water per day"

### 6.2 Data Model

```swift
struct StreakGoal: Codable {
    let streakId: String
    let eventsRequiredPerDay: Int     // e.g., 3
    let currentStreak: Int
    let todayEventCount: Int          // Reset at midnight
}
```

### 6.3 Calculation Logic Modification

```swift
func calculateGoalStreak(
    events: [Event],
    timezone: TimeZone,
    eventsPerDay: Int
) -> Int {
    let calendar = Calendar.current
    calendar.timeZone = timezone

    // Group events by calendar day
    let eventsByDay = Dictionary(grouping: events) { event in
        calendar.startOfDay(for: event.timestamp)
    }

    // Filter to days that met the goal
    let qualifyingDays = eventsByDay.filter { _, events in
        events.count >= eventsPerDay
    }.keys.sorted()

    // Calculate consecutive qualifying days
    var streak = 0
    var expectedDate = calendar.startOfDay(for: Date())

    for day in qualifyingDays.reversed() {
        if calendar.isDate(day, inSameDayAs: expectedDate) {
            streak += 1
            expectedDate = calendar.date(byAdding: .day, value: -1, to: expectedDate)!
        } else if day < expectedDate {
            break
        }
    }

    return streak
}
```

---

## 7. Streak Leeway (Grace Period)

### 7.1 Concept

**Problem:** Strict 24-hour days feel punishing
- User logs at 10 PM on Day 1
- User logs at 2 AM on Day 3 (26 hours later)
- Technically 2 days apart, but feels like 1 missed day

**Solution:** Add X-hour grace period after midnight

### 7.2 Implementation

```swift
func calculateStreakWithLeeway(
    lastEventDate: Date,
    currentDate: Date,
    leewayHours: Int = 3
) -> StreakStatus {
    let calendar = Calendar.current

    let lastEventDay = calendar.startOfDay(for: lastEventDate)
    let currentDay = calendar.startOfDay(for: currentDate)

    let daysDiff = calendar.dateComponents(
        [.day],
        from: lastEventDay,
        to: currentDay
    ).day ?? 0

    if daysDiff == 0 {
        return .alreadyLoggedToday
    } else if daysDiff == 1 {
        return .canExtendStreak
    } else if daysDiff == 2 {
        // Check if within leeway period
        let midnightBetween = calendar.startOfDay(for: currentDate)
        let hoursSinceMidnight = calendar.dateComponents(
            [.hour],
            from: midnightBetween,
            to: currentDate
        ).hour ?? 0

        if hoursSinceMidnight <= leewayHours {
            return .canExtendStreakWithLeeway
        } else {
            return .streakBroken
        }
    } else {
        return .streakBroken
    }
}
```

### 7.3 Configuration

**Leeway should be configurable per streak type:**
- Strict streaks: 0 hours leeway
- Casual streaks: 3-6 hours leeway
- Global setting: Default leeway for all streaks

---

## 8. Multiple Streak Types (Multiple GamificationManagers)

### 8.1 Architecture

**Problem:** App has different streak types:
- Daily workout streak
- Daily reading streak
- Weekly goal streak

**Solution Options:**

**Option 1: One manager per streak type (Recommended)**
```swift
let workoutGamification = GamificationManager(
    service: FirebaseGamificationService(streakId: "workout"),
    logger: logManager
)

let readingGamification = GamificationManager(
    service: FirebaseGamificationService(streakId: "reading"),
    logger: logManager
)
```

**Pros:**
- Clean separation of concerns
- Each manager has focused responsibility
- Easy to configure different rules per streak

**Cons:**
- More memory usage (multiple manager instances)
- More Firestore listeners (one per manager)

**Option 2: Single manager, multiple streaks**
```swift
let gamificationManager = GamificationManager(
    service: FirebaseGamificationService(),
    logger: logManager
)

// Log events with streak ID
gamificationManager.logEvent(streakId: "workout")
gamificationManager.logEvent(streakId: "reading")
```

**Pros:**
- Single source of truth
- Centralized logging
- Shared cache/sync logic

**Cons:**
- More complex internal logic
- Harder to customize per streak
- Could violate single responsibility principle

**Recommendation:** Option 1 (one manager per streak) for v1
- Cleaner architecture
- Easier to test
- Scales better with different rules per streak

### 8.2 Initialization Pattern

```swift
// In Dependencies.swift (SwiftfulStarterProject pattern)

struct StreakManagers {
    let workout: GamificationManager
    let reading: GamificationManager
    let meditation: GamificationManager
}

// Initialize in Dependencies
let streakManagers = StreakManagers(
    workout: GamificationManager(
        service: config.isProduction
            ? FirebaseGamificationService(streakId: "workout")
            : MockGamificationService(streakId: "workout"),
        logger: logManager
    ),
    reading: GamificationManager(
        service: config.isProduction
            ? FirebaseGamificationService(streakId: "reading")
            : MockGamificationService(streakId: "reading"),
        logger: logManager
    ),
    meditation: GamificationManager(
        service: config.isProduction
            ? FirebaseGamificationService(streakId: "meditation")
            : MockGamificationService(streakId: "meditation"),
        logger: logManager
    )
)

container.register(StreakManagers.self, service: streakManagers)
```

---

## 9. Testing Strategy

### 9.1 Testability Requirements

**Mock Date/Time:**
- Inject date provider for deterministic tests
- Mock timezone changes
- Test across different timezones

**Test Coverage Areas:**
1. Timezone edge cases
2. Multi-device sync conflicts
3. Streak freeze logic
4. Goal-based calculations
5. Grace period boundaries
6. DST transitions

### 9.2 Mock Date Injection Pattern

```swift
protocol DateProviding {
    func now() -> Date
    var currentTimezone: TimeZone { get }
}

struct SystemDateProvider: DateProviding {
    func now() -> Date { Date() }
    var currentTimezone: TimeZone { TimeZone.current }
}

struct MockDateProvider: DateProviding {
    var mockedDate: Date
    var mockedTimezone: TimeZone

    func now() -> Date { mockedDate }
    var currentTimezone: TimeZone { mockedTimezone }
}

// In GamificationService protocol
protocol GamificationService: Sendable {
    var dateProvider: DateProviding { get }
    // ... other methods
}
```

### 9.3 Critical Test Cases

**Test 1: Same day, different timezones**
```swift
func testStreakMaintainedWhenTravelingWest() {
    // User in NYC logs at 11 PM EST
    let nycEvent = Event(
        timestamp: createDate(hour: 23, timezone: "America/New_York"),
        timezone: "America/New_York"
    )

    // User flies to LA, logs at 9 PM PST (same calendar day)
    let laEvent = Event(
        timestamp: createDate(hour: 21, timezone: "America/Los_Angeles"),
        timezone: "America/Los_Angeles"
    )

    // Both events on same UTC day but different local days
    let streak = calculateStreak(
        events: [nycEvent, laEvent],
        timezone: TimeZone(identifier: "America/Los_Angeles")!
    )

    XCTAssertEqual(streak, 1) // Should count as 1 day, not 2
}
```

**Test 2: Midnight boundary**
```swift
func testMidnightBoundary() {
    let day1Event = createDate(hour: 23, minute: 59, second: 59)
    let day2Event = createDate(day: +1, hour: 0, minute: 0, second: 1)

    let streak = calculateStreak(events: [day1Event, day2Event])
    XCTAssertEqual(streak, 2) // Consecutive days
}
```

**Test 3: DST transition**
```swift
func testDaylightSavingTimeTransition() {
    // Spring forward: 2 AM -> 3 AM on March 10, 2024
    let beforeDST = createDate(month: 3, day: 9, hour: 23)
    let afterDST = createDate(month: 3, day: 10, hour: 23)

    let streak = calculateStreak(events: [beforeDST, afterDST])
    XCTAssertEqual(streak, 2) // Still consecutive despite time shift
}
```

**Test 4: Multi-device conflict**
```swift
func testLastWriteWinsConflict() async {
    let device1Event = Event(timestamp: Date(), device: "iPhone")
    let device2Event = Event(timestamp: Date().addingTimeInterval(5), device: "iPad")

    // Both try to log on same day
    try await service.logEvent(device1Event)
    try await service.logEvent(device2Event)

    let streak = try await service.getCurrentStreak()
    XCTAssertEqual(streak.currentStreak, 1) // Not duplicated
}
```

**Test 5: Streak freeze consumption**
```swift
func testStreakFreezeAutoConsume() async {
    // User has 2-day streak
    try await service.logEvent(createDate(day: -1))
    try await service.logEvent(createDate(day: 0))

    // User has 1 freeze available
    try await service.addFreeze()

    // User misses day 1, checks on day 2
    mockDate.mockedDate = createDate(day: 2)

    let streak = try await service.getCurrentStreak()
    XCTAssertEqual(streak.currentStreak, 2) // Freeze used
    XCTAssertEqual(streak.freezesRemaining, 0)
}
```

**Test 6: Timezone change mid-streak**
```swift
func testTimezoneChangePreservesStreak() {
    var provider = MockDateProvider()
    provider.mockedTimezone = TimeZone(identifier: "America/New_York")!

    // Log event in NYC timezone
    service.logEvent()

    // User changes timezone to Tokyo
    provider.mockedTimezone = TimeZone(identifier: "Asia/Tokyo")!

    let streak = service.getCurrentStreak()
    XCTAssertEqual(streak.currentStreak, 1) // Streak preserved
}
```

---

## 10. Offline-First Architecture

### 10.1 Strategy

**Local-first approach:**
1. All reads from local cache (instant UI)
2. All writes to local cache first
3. Background sync to Firestore
4. Firestore response updates local cache

### 10.2 Cache Invalidation

**When to invalidate cache:**
- After successful sync from server
- On app launch (check for updates)
- On timezone change
- On explicit user refresh

**Staleness tolerance:**
- Streak data: 5-10 seconds stale is acceptable
- Freeze count: Must be real-time (affects purchases)
- Historical events: Can be minutes stale

### 10.3 Sync Queue

```swift
actor SyncQueue {
    private var pendingEvents: [Event] = []

    func enqueue(_ event: Event) {
        pendingEvents.append(event)
    }

    func processPendingEvents() async throws {
        for event in pendingEvents {
            try await firestore.logEvent(event)
        }
        pendingEvents.removeAll()
    }
}
```

---

## 11. Firestore Considerations

### 11.1 Query Optimization

**Avoid:**
- `whereField("userId", isEqualTo: userId)` on root collection
- Fetching all events every time

**Optimize:**
- Use subcollections: `users/{userId}/streaks/{streakId}/events`
- Limit queries: `.limit(toLast: 30)` for recent events
- Use composite indexes for complex queries

### 11.2 Write Batching

**For event logging:**
```swift
let batch = firestore.batch()

// Update streak document
batch.updateData([
    "currentStreak": newStreak,
    "lastEventDate": FieldValue.serverTimestamp()
], forDocument: streakRef)

// Add event document
batch.setData(eventData, forDocument: eventRef)

try await batch.commit()
```

**Benefits:**
- Atomic operations (all or nothing)
- Reduced network calls
- Better performance

### 11.3 Real-time Listeners

**Listen for changes:**
```swift
streakRef.addSnapshotListener { snapshot, error in
    guard let data = snapshot?.data() else { return }
    let streak = StreakData(firestoreData: data)
    updateLocalCache(streak)
}
```

**Listener strategy:**
- One listener per active streak
- Remove listeners when screen dismissed
- Use `.includeMetadataChanges(true)` for optimistic UI

---

## 12. Architecture Decisions - FINALIZED

All questions have been answered. Here are the confirmed decisions:

### 1. Streak ID Strategy ✅
**Decision: Developer-defined strings**
- Developer passes streakId when initializing GamificationManager
- Example: `GamificationManager(service: service, streakId: "daily_workout")`
- Validation: Only lowercase letters, numbers, and underscores allowed
- Pattern: `^[a-z0-9_]+$`

### 2. Event Metadata ✅
**Decision: Required metadata with constrained types**
```swift
struct Event: Identifiable, Codable, Sendable {
    let id: String                          // Auto-generated UUID (required)
    let timestamp: Date                     // UTC (required)
    let timezone: String                    // e.g., "America/New_York" (required)
    let metadata: [String: EventValue]      // Custom data (required)
}

enum EventValue: Codable, Sendable {
    case string(String)
    case bool(Bool)
    case int(Int)
}
```
- Every Event must have metadata (not optional)
- Supported types: String, Bool, Int only
- All Sendable and Firestore-compatible

### 3. Streak Freeze Rules ✅
**Decision: Developer-controlled, configurable consumption**
- **Expiration:** Never expire
- **Stacking:** Unlimited (developer controls via `addStreakFreeze()`)
- **Consumption:** Developer-configurable setting
```swift
let manager = GamificationManager(
    service: service,
    streakId: "workout",
    autoConsumeFreeze: true  // Toggle auto-consume
)

// Developer adds freezes (controls quantity)
try await manager.addStreakFreeze()

// Manual consumption if autoConsumeFreeze = false
try await manager.consumeStreakFreeze()
```

### 4. Grace Period (Leeway) Configuration ✅
**Decision: Per-streak, bidirectional, default = 0**
```swift
let manager = GamificationManager(
    service: service,
    streakId: "workout",
    leewayHours: 3  // ±3 hours = 6-hour window total
)
// Default is 0 (strict 24-hour days)
```
- Leeway applies ±X hours around midnight
- 3-hour leeway = events 3 hours before OR after midnight count
- Developer can set 24 hours for travel-friendly streaks

### 5. Historical Data Import ✅
**Decision: Yes, supported**
```swift
// Import past events
let historicalEvents: [Event] = [...]
try await gamificationManager.importEvents(historicalEvents)
// Streak automatically recalculated from all events
```

### 6. Event Retention ✅
**Decision: Keep all events forever**
- Complete history preserved
- Can recalculate streaks anytime
- Firestore storage costs acceptable for typical usage

### 7. Firestore Collection Strategy ✅
**Decision: Separate collection per streak type with prefix**
```
gamification_{streakId}/{userId}
{
    userId: "user123",
    streakId: "workout",
    currentStreak: 5,
    longestStreak: 10,
    lastEventDate: Timestamp(UTC),
    lastEventTimezone: "America/New_York",
    totalEvents: 42,
    createdAt: Timestamp,
    updatedAt: Timestamp
}

gamification_{streakId}_events/{userId}__{eventId}
{
    userId: "user123",
    eventId: "abc-123",
    timestamp: Timestamp(UTC),
    timezone: "America/New_York",
    metadata: { reps: 50, type: "cardio" }
}
```
- Examples: `gamification_workout/{userId}`, `gamification_reading_streak/{userId}`
- Events: `gamification_workout_events/{userId}__{eventId}`

### 8. Caching Strategy ✅
**Decision: 5-10 seconds stale acceptable, instant UI**
```swift
@MainActor
@Observable
public class GamificationManager {
    public private(set) var currentStreak: UserStreak?  // Instant from cache
    public private(set) var isSyncInProgress: Bool = false  // Developer can show spinner
}
```
- Load from cache synchronously (instant UI)
- Sync with Firestore in background
- Developer optionally shows loading indicator

### 9. Streak Break Notification ✅
**Decision: Callback closures via configureCallbacks()**
```swift
manager.configureCallbacks(
    onStreakBroken: { previousStreak async in
        await showAlert("Streak of \(previousStreak) days was broken!")
    },
    onFreezeConsumed: { remaining async in
        await analytics.track("freeze_used", properties: ["remaining": remaining])
    },
    onStreakAtRisk: { async in
        await sendNotification("Don't forget your workout today!")
    }
)
```
- All callbacks are async
- Developer handles notification logic

### 10. Multi-device UX ✅
**Decision: Developer handles using isSyncInProgress**
```swift
Text("Streak: \(manager.currentStreak?.count ?? 0)")
if manager.isSyncInProgress {
    ProgressView()  // Optional
}
```
- Show cached value immediately
- Developer chooses whether to show sync indicator

### 11. Longest Streak Reset ✅
**Decision: Persist forever**
- Longest streak never resets when current streak breaks
- Gives users a "high score" to beat
- Only resets on explicit data deletion

### 12. Timezone Change Handling ✅
**Decision: Option B - Only affect new events going forward**
- Event history preserves original timezone (stored with each event)
- Calculations ALWAYS use current device timezone
- All event timestamps converted to current timezone for day comparison
- `leewayHours` provides buffer for timezone transitions
- Developer can set larger leeway (24 hours) for travel-friendly streaks

### 13. Goal Flexibility ✅
**Decision: Changes apply going forward only**
- Past days maintain original goal requirement
- New requirement applies to future days
- Streak continues with new rules
- No retroactive recalculation

### 14. Production Safeguards ✅
**Decision: Client-side validation only (for now)**
```swift
// Validate before sending to Firestore
guard event.timestamp <= Date() else {
    throw GamificationError.futureTimestamp
}
guard event.timestamp > Date().addingTimeInterval(-365 * 24 * 60 * 60) else {
    throw GamificationError.timestampTooOld
}
```
- Server validation can be added later via Cloud Functions

### 15. Data Migration ✅
**Decision: No migrations needed - backwards compatible only**
- All fields must be optional except `id` (required)
- Developers can add new optional fields
- Developers can change existing fields (additive only)
- No breaking changes allowed
- Old data works forever without migration

### 16. Additional Requirements ✅

**Delete and Reset Method:**
```swift
// Delete all events and reset streak to zero
try await gamificationManager.deleteAllEventsAndResetStreak()
```
- Deletes all events from Firestore
- Resets current streak to 0
- Resets longest streak to 0
- Clears local cache
- Irreversible operation (should prompt user confirmation)

---

## 12. Outstanding Questions for User (LEGACY - ANSWERED ABOVE)

### Architecture Decisions

1. **Streak ID Strategy:**
   - Should streak IDs be developer-defined strings (e.g., "daily_workout")?
   - Or auto-generated by the system?
   - Or user-customizable?

2. **Event Metadata:**
   - Do events need additional metadata beyond timestamp?
   - Examples: event value, notes, location, etc.
   - If yes, should this be a generic `[String: Any]` dictionary?

3. **Streak Freeze Rules:**
   - Should freezes expire after X days?
   - Can users stack unlimited freezes?
   - Auto-consume freeze or require user confirmation?
   - Can freezes be purchased, earned, or both?

4. **Grace Period Configuration:**
   - Should leeway hours be configurable per-streak?
   - Or global setting for all streaks?
   - Default leeway value? (recommend 3 hours)

5. **Historical Data:**
   - Do we need to support "importing" historical events?
   - Example: User has workout data from Apple Health, import last 30 days?
   - If yes, how to handle streak recalculation?

### Performance & Scale

6. **Event Retention:**
   - Should old events be deleted after X days?
   - Keep all events forever?
   - Archive to cheaper storage?

7. **Firestore Collection Strategy:**
   - One collection per GamificationManager instance?
   - Or shared collection with streakId field?
   - Expected number of streak types per app?

8. **Caching Strategy:**
   - How long can local cache be stale?
   - Should we use UserDefaults or local SQLite?
   - Cache size limits?

### UI/UX Considerations

9. **Streak Break Notification:**
   - Should user be notified when streak breaks?
   - Should user be notified when streak freeze is auto-consumed?
   - Should user be warned before missing a day?

10. **Multi-device UX:**
    - How to handle when user sees different streak values on different devices?
    - Show "Syncing..." indicator?
    - Optimistic UI updates or wait for server?

### Business Logic

11. **Longest Streak Reset:**
    - Should longest streak persist even after current streak breaks?
    - Or reset on account deletion only?

12. **Timezone Change Handling:**
    - When user changes timezone, recalculate entire streak?
    - Or only affect new events going forward?
    - Should we detect "fake" timezone changes (VPN, manual setting)?

13. **Goal Flexibility:**
    - Can goal requirements change mid-streak?
    - Example: Change from "3 events/day" to "5 events/day"
    - How to handle partial day progress?

### Testing & Validation

14. **Production Safeguards:**
    - Should we add server-side validation for impossible timestamps?
    - Example: Event timestamp in the future
    - Rate limiting on event logging?

15. **Data Migration:**
    - If schema changes, how to migrate existing users?
    - Backwards compatibility requirements?

---

## 13. Recommended Implementation Phases

### Phase 1: Core Streak (v1.0)
- ✅ Basic streak tracking (1 event/day)
- ✅ Timezone-aware calculations
- ✅ Local cache with UserDefaults
- ✅ Firestore sync with Last-Write-Wins
- ✅ Mock service for testing
- ✅ Multi-device support

### Phase 2: Streak Freezes (v1.1)
- ✅ Freeze earning/purchasing
- ✅ Auto-consume on missed day
- ✅ Freeze expiration (optional)
- ✅ Freeze count UI

### Phase 3: Goals (v1.2)
- ✅ Configurable events per day
- ✅ Progress tracking within day
- ✅ Goal completion logic

### Phase 4: Advanced Features (v2.0)
- ✅ Grace period/leeway
- ✅ Historical event import
- ✅ Analytics & insights
- ✅ Streak milestones/achievements

---

## 14. Key Takeaways

### Critical Success Factors

1. **Timezone handling is paramount**
   - Store UTC, calculate in local time
   - Use Calendar.startOfDay consistently
   - Test across timezone changes

2. **Multi-device sync must be robust**
   - Last-Write-Wins with server authority
   - Offline queue for reliability
   - Clear conflict resolution strategy

3. **Local cache is non-negotiable**
   - Users expect instant UI
   - Sync in background
   - Handle stale data gracefully

4. **Testing is essential**
   - Mock dates/timezones
   - Test edge cases extensively
   - Automated regression tests

5. **Keep it simple for v1**
   - Start with basic streaks
   - Add complexity incrementally
   - Validate with real users before adding features

### Risks to Mitigate

- **Timezone bugs:** Most common source of streak complaints
- **Multi-device conflicts:** Can cause lost progress
- **Cache inconsistency:** Users see wrong data
- **Firestore costs:** Unlimited listeners can be expensive
- **Breaking changes:** Schema evolution needs migration plan

---

## 15. References & Resources

### Research Sources
- Duolingo Help Center: Timezone handling documentation
- Stack Overflow: Streak implementation discussions
- Firebase Documentation: Best practices for Firestore
- Apple Developer: Calendar and timezone APIs
- Medium/Dev.to: Offline-first architecture articles

### Recommended Reading
- "Implementing a Daily Streak System: A Practical Guide" (tigerabrodi.blog)
- "Designing a Robust Data Synchronization System" (Medium)
- "Firestore Best Practices" (Firebase Docs)
- "Time Traveling in Swift Unit Tests" (Swift by Sundell)

### Similar Implementations
- Duolingo: Streak system with freezes
- Snapchat: Snapstreak with fire emoji
- GitHub: Contribution streak graph
- Streaks app: iOS task tracking with streaks

---

**Document Status:** Ready for Review
**Last Updated:** 2025-09-30
**Next Steps:** Answer outstanding questions, finalize architecture, begin implementation
