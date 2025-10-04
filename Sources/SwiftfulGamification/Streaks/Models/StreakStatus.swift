//
//  StreakStatus.swift
//  SwiftfulGamification
//
//  Created by Nick Sarno on 2025-09-30.
//

import Foundation

/// Represents the current status of a streak
public enum StreakStatus: Sendable, Equatable {
    /// User has never logged any events
    case noEvents

    /// Streak is active (0 or 1 days since last event)
    case active(daysSinceLastEvent: Int)

    /// Streak is at risk (last event was yesterday, today not logged yet)
    case atRisk

    /// Streak is broken (2+ days since last event)
    case broken(daysSinceLastEvent: Int)

    /// Within leeway window (can still extend streak)
    case canExtendWithLeeway

    // MARK: - Computed Properties

    /// Is the streak currently active?
    public var isActive: Bool {
        switch self {
        case .active, .atRisk, .canExtendWithLeeway:
            return true
        case .noEvents, .broken:
            return false
        }
    }

    /// Does the user need to take action to maintain the streak?
    public var needsAction: Bool {
        switch self {
        case .atRisk, .canExtendWithLeeway:
            return true
        case .active, .noEvents, .broken:
            return false
        }
    }

    /// Is the streak broken?
    public var isBroken: Bool {
        if case .broken = self {
            return true
        }
        return false
    }

    /// Days since last event (if applicable)
    public var daysSinceLastEvent: Int? {
        switch self {
        case .active(let days):
            return days
        case .broken(let days):
            return days
        case .noEvents, .atRisk, .canExtendWithLeeway:
            return nil
        }
    }

    // MARK: - Helper Methods

    /// User-friendly description
    public var description: String {
        switch self {
        case .noEvents:
            return "No events logged yet"
        case .active(let days) where days == 0:
            return "Active - logged today"
        case .active(let days) where days == 1:
            return "Active - logged yesterday"
        case .active(let days):
            return "Active - \(days) days since last event"
        case .atRisk:
            return "At risk - log today to maintain streak"
        case .broken(let days):
            return "Broken - \(days) days since last event"
        case .canExtendWithLeeway:
            return "Within grace period - can still extend"
        }
    }
}
