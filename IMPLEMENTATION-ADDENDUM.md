# SwiftfulGamification Implementation Addendum

**Purpose:** Goal-Based Streaks & Server-Side Calculation Updates
**Date:** 2025-09-30
**Scope:** v1.0 feature additions to IMPLEMENTATION-GUIDE.md

---

## Overview

This addendum documents the integration of two major features into v1.0:

1. **Goal-Based Streaks** - Require X events per day to maintain streak
2. **Server-Side Calculation** - Optional Cloud Function for authoritative calculation

Both features are configured via `StreakConfiguration` and work seamlessly with existing architecture.

---

## Updated GamificationManager Initialization

### Previous (Basic Streaks Only):
```swift
public init(
    service: GamificationService,
    leewayHours: Int = 0,
    autoConsumeFreeze: Bool = true,
    logger: GamificationLogger? = nil
)
```

### New (With StreakConfiguration):
```swift
@MainActor
@Observable
public class GamificationManager {
    private let logger: GamificationLogger?
    private let service: GamificationService

    // Configuration now comes from service
    private var configuration: StreakConfiguration {
        service.configuration
    }

    public init(
        service: GamificationService,
        logger: GamificationLogger? = nil
    ) {
        self.service = service
        self.logger = logger

        // Load from cache immediately (synchronous)
        self.currentStreak = service.getCachedStreak()

        // Start listeners
        addListeners()
    }
}
```

**Key Changes:**
- Configuration moved to service (injected once)
- Manager reads configuration from service
- Simpler initialization (fewer parameters)
- Configuration can't change during manager lifetime

---

## Updated Calculation Logic

### Goal-Based Streak Algorithm

**File:** `Sources/SwiftfulGamification/Extensions/GamificationService+Calculations.swift`

```swift
extension GamificationService {

    public func calculateStreak(
        events: [Event],
        configuration: StreakConfiguration,
        currentDate: Date,
        timezone: TimeZone
    ) -> UserStreak {
        guard !events.isEmpty else {
            return UserStreak(
                id: "unknown",
                streakId: streakId,
                currentStreak: 0,
                longestStreak: 0,
                eventsRequiredPerDay: configuration.eventsRequiredPerDay
            )
        }

        var calendar = Calendar.current
        calendar.timeZone = timezone

        // GROUP EVENTS BY DAY
        let eventsByDay = Dictionary(grouping: events) { event in
            calendar.startOfDay(for: event.timestamp)
        }

        // GOAL-BASED MODE: Filter days that met the goal
        let qualifyingDays: [Date]
        if configuration.isGoalBasedStreak {
            qualifyingDays = eventsByDay.filter { _, events in
                events.count >= configuration.eventsRequiredPerDay
            }.keys.sorted()
        } else {
            // BASIC MODE: Any day with at least 1 event qualifies
            qualifyingDays = eventsByDay.keys.sorted()
        }

        // CALCULATE CURRENT STREAK (walk backwards from today)
        var currentStreak = 0
        var expectedDate = calendar.startOfDay(for: currentDate)

        // Apply leeway: Extend "today" window
        if configuration.leewayHours > 0 {
            let components = calendar.dateComponents([.hour], from: expectedDate, to: currentDate)
            let hoursSinceMidnight = components.hour ?? 0

            if hoursSinceMidnight <= configuration.leewayHours {
                expectedDate = calendar.date(byAdding: .day, value: -1, to: expectedDate) ?? expectedDate
            }
        }

        for eventDay in qualifyingDays.reversed() {
            if calendar.isDate(eventDay, inSameDayAs: expectedDate) {
                currentStreak += 1
                expectedDate = calendar.date(byAdding: .day, value: -1, to: expectedDate) ?? expectedDate
            } else if eventDay < expectedDate {
                break  // Gap found
            }
        }

        // CALCULATE LONGEST STREAK
        var longestStreak = 0
        var tempStreak = 0
        var previousDay: Date?

        for eventDay in qualifyingDays {
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
        longestStreak = max(longestStreak, currentStreak)

        // GET TODAY'S EVENT COUNT (for goal progress)
        let todayEventCount = getTodayEventCount(
            events: events,
            timezone: timezone,
            currentDate: currentDate
        )

        // LAST EVENT INFO
        let lastEvent = events.max(by: { $0.timestamp < $1.timestamp })

        return UserStreak(
            id: lastEvent?.id ?? "unknown",
            streakId: streakId,
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            lastEventDate: lastEvent?.timestamp,
            lastEventTimezone: lastEvent?.timezone,
            streakStartDate: qualifyingDays.count >= currentStreak && currentStreak > 0
                ? qualifyingDays[qualifyingDays.count - currentStreak]
                : nil,
            totalEvents: events.count,
            eventsRequiredPerDay: configuration.eventsRequiredPerDay,
            todayEventCount: todayEventCount,
            createdAt: events.first?.timestamp,
            updatedAt: currentDate
        )
    }

    public func getTodayEventCount(
        events: [Event],
        timezone: TimeZone,
        currentDate: Date
    ) -> Int {
        var calendar = Calendar.current
        calendar.timeZone = timezone

        let todayStart = calendar.startOfDay(for: currentDate)

        return events.filter { event in
            calendar.isDate(event.timestamp, inSameDayAs: todayStart)
        }.count
    }
}
```

**Key Differences from Basic Mode:**
- Groups events by day
- Filters days based on `eventsRequiredPerDay`
- Tracks `todayEventCount` for goal progress
- Returns goal-specific fields in UserStreak

---

## Server-Side Calculation Integration

### Firebase Package Implementation

**File:** `SwiftfulGamificationFirebase/FirebaseGamificationService.swift`

```swift
import SwiftfulGamification
import FirebaseFirestore
import FirebaseFunctions

public struct FirebaseGamificationService: GamificationService {
    public let streakId: String
    public let configuration: StreakConfiguration

    private var collection: CollectionReference {
        Firestore.firestore().collection("gamification_\(streakId)")
    }

    public init(streakId: String, configuration: StreakConfiguration) {
        self.streakId = streakId
        self.configuration = configuration
    }

    public func logEvent(userId: String, event: Event) async throws -> UserStreak {
        // CLIENT-SIDE: Always log event to Firestore
        let eventRef = Firestore.firestore()
            .collection("gamification_\(streakId)_events")
            .document("\(userId)__\(event.id)")

        try await eventRef.setData([
            "user_id": userId,
            "event_id": event.id,
            "timestamp": Timestamp(date: event.timestamp),
            "timezone": event.timezone,
            "metadata": event.metadata.mapValues { $0.firestoreValue }
        ])

        // SERVER-SIDE CALCULATION (if enabled)
        if configuration.useServerCalculation {
            return try await calculateStreakViaCloudFunction(userId: userId)
        } else {
            // CLIENT-SIDE CALCULATION
            let allEvents = try await getEvents(userId: userId, limit: nil)
            let timezone = TimeZone(identifier: event.timezone) ?? .current

            let updatedStreak = calculateStreak(
                events: allEvents,
                configuration: configuration,
                currentDate: Date(),
                timezone: timezone
            )

            // Save calculated streak to Firestore
            try await updateStreak(userId: userId, streak: updatedStreak)

            return updatedStreak
        }
    }

    private func calculateStreakViaCloudFunction(userId: String) async throws -> UserStreak {
        let functions = Functions.functions()
        let callable = functions.httpsCallable("calculateStreak")

        let data: [String: Any] = [
            "user_id": userId,
            "streak_id": streakId,
            "events_required_per_day": configuration.eventsRequiredPerDay,
            "leeway_hours": configuration.leewayHours
        ]

        let result = try await callable.call(data)

        guard let responseData = result.data as? [String: Any] else {
            throw GamificationError.decodingFailed(URLError(.cannotDecodeContentData))
        }

        return UserStreak(firestoreData: responseData)
    }

    // ... rest of protocol implementation
}
```

### Cloud Function Template (Copy-Paste for Deployment)

**File:** `SwiftfulGamificationFirebase/CloudFunctions/calculateStreak.js`

**Note:** This file is included in the Firebase package but does NOT run. Developer must copy and deploy manually.

```javascript
/**
 * SwiftfulGamification Cloud Function: Calculate Streak
 *
 * DEPLOYMENT INSTRUCTIONS:
 * 1. Copy this entire file to your Firebase Functions directory
 * 2. Update firebaseConfig if needed
 * 3. Deploy: firebase deploy --only functions:calculateStreak
 * 4. Set useServerCalculation = true in your StreakConfiguration
 *
 * DEPENDENCIES: firebase-functions, firebase-admin
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

exports.calculateStreak = functions.https.onCall(async (data, context) => {
  // Verify authentication (optional but recommended)
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated'
    );
  }

  const { user_id, streak_id, events_required_per_day, leeway_hours } = data;

  // Validate inputs
  if (!user_id || !streak_id) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Missing required fields: user_id, streak_id'
    );
  }

  const eventsPerDay = events_required_per_day || 1;
  const leeway = leeway_hours || 0;

  try {
    // FETCH ALL EVENTS FOR USER
    const eventsSnapshot = await db
      .collection(`gamification_${streak_id}_events`)
      .where('user_id', '==', user_id)
      .orderBy('timestamp', 'asc')
      .get();

    if (eventsSnapshot.empty) {
      // No events - return zero streak
      const emptyStreak = {
        id: user_id,
        streak_id: streak_id,
        current_streak: 0,
        longest_streak: 0,
        total_events: 0,
        events_required_per_day: eventsPerDay,
        today_event_count: 0,
        updated_at: admin.firestore.FieldValue.serverTimestamp()
      };

      await db.collection(`gamification_${streak_id}`).doc(user_id).set(emptyStreak);

      return emptyStreak;
    }

    // GROUP EVENTS BY DAY (UTC, convert to user's timezone later if needed)
    const events = [];
    eventsSnapshot.forEach(doc => {
      const data = doc.data();
      events.push({
        id: data.event_id,
        timestamp: data.timestamp.toDate(),
        timezone: data.timezone,
        metadata: data.metadata
      });
    });

    // CALCULATE STREAK USING SAME LOGIC AS CLIENT
    // (For simplicity, using UTC here - production should use user's timezone)
    const eventsByDay = {};
    events.forEach(event => {
      const dayKey = event.timestamp.toISOString().split('T')[0]; // YYYY-MM-DD
      if (!eventsByDay[dayKey]) {
        eventsByDay[dayKey] = [];
      }
      eventsByDay[dayKey].push(event);
    });

    // Filter days that met the goal
    const qualifyingDays = Object.keys(eventsByDay)
      .filter(day => eventsByDay[day].length >= eventsPerDay)
      .sort();

    // Calculate current streak (walk backwards from today)
    const today = new Date().toISOString().split('T')[0];
    let currentStreak = 0;
    let expectedDate = new Date(today);

    for (let i = qualifyingDays.length - 1; i >= 0; i--) {
      const eventDay = new Date(qualifyingDays[i]);
      const expectedDateStr = expectedDate.toISOString().split('T')[0];

      if (qualifyingDays[i] === expectedDateStr) {
        currentStreak++;
        expectedDate.setDate(expectedDate.getDate() - 1);
      } else if (eventDay < expectedDate) {
        break; // Gap found
      }
    }

    // Calculate longest streak
    let longestStreak = 0;
    let tempStreak = 0;
    let previousDay = null;

    qualifyingDays.forEach((day, index) => {
      if (previousDay) {
        const dayDiff = Math.floor(
          (new Date(day) - new Date(previousDay)) / (1000 * 60 * 60 * 24)
        );
        if (dayDiff === 1) {
          tempStreak++;
        } else {
          longestStreak = Math.max(longestStreak, tempStreak);
          tempStreak = 1;
        }
      } else {
        tempStreak = 1;
      }
      previousDay = day;
    });
    longestStreak = Math.max(longestStreak, tempStreak, currentStreak);

    // Get today's event count
    const todayEventCount = eventsByDay[today] ? eventsByDay[today].length : 0;

    // Get last event
    const lastEvent = events[events.length - 1];

    // BUILD RESULT
    const calculatedStreak = {
      id: user_id,
      streak_id: streak_id,
      current_streak: currentStreak,
      longest_streak: longestStreak,
      last_event_date: admin.firestore.Timestamp.fromDate(lastEvent.timestamp),
      last_event_timezone: lastEvent.timezone,
      streak_start_date: qualifyingDays.length >= currentStreak && currentStreak > 0
        ? admin.firestore.Timestamp.fromDate(new Date(qualifyingDays[qualifyingDays.length - currentStreak]))
        : null,
      total_events: events.length,
      events_required_per_day: eventsPerDay,
      today_event_count: todayEventCount,
      created_at: admin.firestore.Timestamp.fromDate(events[0].timestamp),
      updated_at: admin.firestore.FieldValue.serverTimestamp()
    };

    // SAVE TO FIRESTORE
    await db.collection(`gamification_${streak_id}`).doc(user_id).set(calculatedStreak);

    return calculatedStreak;

  } catch (error) {
    console.error('Error calculating streak:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});
```

**Usage Instructions (in README for Firebase package):**

```markdown
## Server-Side Calculation (Optional)

SwiftfulGamificationFirebase includes a Cloud Function template for server-side streak calculation. This is **optional** but provides:

- ✅ Authoritative calculation (prevents client manipulation)
- ✅ Consistent results across devices
- ✅ Single source of truth

### Setup Steps:

1. **Enable Cloud Functions in Firebase Console**
2. **Copy the Cloud Function template:**
   ```bash
   cp CloudFunctions/calculateStreak.js YOUR_FIREBASE_FUNCTIONS_DIRECTORY/
   ```
3. **Deploy the function:**
   ```bash
   firebase deploy --only functions:calculateStreak
   ```
4. **Enable server calculation in your app:**
   ```swift
   let config = StreakConfiguration(
       eventsRequiredPerDay: 1,
       useServerCalculation: true,  // Enable server-side
       leewayHours: 3,
       autoConsumeFreeze: true
   )

   let service = FirebaseGamificationService(
       streakId: "workout",
       configuration: config
   )
   ```

### Client-Side Fallback:

If `useServerCalculation = false` (default), all calculation happens on the client using the same algorithm. This works without any server deployment.
```

---

## Updated Test Requirements

### Additional Goal-Based Tests (25 new tests)

**File:** `StreakCalculationTests.swift` additions

```swift
// MARK: - Goal-Based Streaks
@Test("Goal-based: 1 event when 3 required breaks streak")
func testGoalNotMetBreaksStreak() async throws

@Test("Goal-based: Exactly required events continues streak")
func testGoalMetContinuesStreak() async throws

@Test("Goal-based: More than required events counts as 1 day")
func testGoalExceededCountsAsOneDay() async throws

@Test("Goal-based: Partial progress doesn't count")
func testGoalPartialProgressDoesntCount() async throws

@Test("Goal-based: 5 events/day for 30 days")
func testGoalStreakLongTerm() async throws

@Test("Goal change mid-streak applies going forward")
func testGoalChangeAppliesForward() async throws

@Test("Today's event count updates correctly")
func testTodayEventCountUpdates() async throws

@Test("Today's event count resets at midnight")
func testTodayEventCountResetsAtMidnight() async throws

@Test("isGoalMet computed property correct")
func testIsGoalMetProperty() async throws

@Test("goalProgress computed property correct")
func testGoalProgressProperty() async throws

// ... 15 more goal-based tests
```

### Server Calculation Tests (10 new tests)

**File:** `ServerCalculationTests.swift` (new)

```swift
@Suite("Server-Side Calculation Tests")
struct ServerCalculationTests {

    @Test("Server calculation flag enables Cloud Function call")
    func testServerCalcEnabled() async throws

    @Test("Server calculation returns same result as client")
    func testServerClientParity() async throws

    @Test("Server calculation handles errors gracefully")
    func testServerCalcErrorHandling() async throws

    @Test("Client fallback when server unavailable")
    func testClientFallback() async throws

    // ... 6 more server calc tests
}
```

---

## Migration Guide (for existing implementations)

### If you're already using basic streaks:

**Before:**
```swift
let manager = GamificationManager(
    service: service,
    leewayHours: 3,
    autoConsumeFreeze: true,
    logger: logger
)
```

**After:**
```swift
let config = StreakConfiguration(
    eventsRequiredPerDay: 1,        // Default (basic mode)
    useServerCalculation: false,    // Default (client-side)
    leewayHours: 3,                 // Same as before
    autoConsumeFreeze: true         // Same as before
)

let service = MockGamificationService(
    streakId: "workout",
    configuration: config
)

let manager = GamificationManager(
    service: service,
    logger: logger
)
```

**Benefits:**
- Cleaner separation of configuration vs. runtime logic
- Configuration lives with service (can be persisted)
- Easy to swap configurations for different streaks

---

## Summary of Changes

### Models Added:
- ✅ `StreakConfiguration` - Centralized behavior config

### Models Updated:
- ✅ `UserStreak` - Added `eventsRequiredPerDay`, `todayEventCount`, `isGoalMet`, `goalProgress`

### Service Protocol Updated:
- ✅ Added `configuration` property
- ✅ Updated `calculateStreak()` signature (takes configuration)
- ✅ Updated `getStreakStatus()` signature (takes configuration)
- ✅ Added `getTodayEventCount()` helper

### Manager Updated:
- ✅ Simplified init (reads config from service)
- ✅ Uses `configuration.eventsRequiredPerDay` for goal logic
- ✅ Uses `configuration.useServerCalculation` for calc routing

### Firebase Package:
- ✅ `FirebaseGamificationService` implements server calculation
- ✅ Includes `calculateStreak.js` Cloud Function template
- ✅ README with deployment instructions

### Tests Added:
- ✅ 25 goal-based streak tests
- ✅ 10 server calculation tests
- ✅ Configuration validation tests

---

## Implementation Checklist

- ☐ Phase 1.4: Implement StreakConfiguration model
- ☐ Phase 1.3: Update UserStreak with goal fields
- ☐ Phase 2: Update service protocol signatures
- ☐ Phase 3: Update manager to use configuration
- ☐ Phase 4.2: Update calculation logic for goal mode
- ☐ Phase 4.2: Add getTodayEventCount helper
- ☐ Phase 5: Add goal-based tests (25 tests)
- ☐ Phase 5: Add server calculation tests (10 tests)
- ☐ Firebase Package: Implement server calculation
- ☐ Firebase Package: Include Cloud Function template
- ☐ Firebase Package: Write deployment docs

---

**Document Status:** Complete
**Total New Checkpoints:** +20 (updated in IMPLEMENTATION-GUIDE.md)
**Total New Tests:** +35
