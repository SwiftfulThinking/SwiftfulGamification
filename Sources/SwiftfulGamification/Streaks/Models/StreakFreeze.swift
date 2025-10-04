//
//  StreakFreeze.swift
//  SwiftfulGamification
//
//  Created by Nick Sarno on 2025-09-30.
//

import Foundation
import IdentifiableByString

/// Represents a streak freeze that can prevent a streak from breaking
public struct StreakFreeze: StringIdentifiable, Codable, Sendable, Equatable {
    /// Unique identifier for the freeze
    public let id: String

    /// Which streak this freeze applies to
    public let streakId: String

    /// When the freeze was earned
    public let earnedDate: Date?

    /// When the freeze was consumed (nil if unused)
    public let usedDate: Date?

    /// When the freeze expires (nil = never expires per Decision #3A)
    public let expiresAt: Date?

    // MARK: - Initialization

    public init(
        id: String,
        streakId: String,
        earnedDate: Date? = nil,
        usedDate: Date? = nil,
        expiresAt: Date? = nil
    ) {
        self.id = id
        self.streakId = streakId
        self.earnedDate = earnedDate
        self.usedDate = usedDate
        self.expiresAt = expiresAt
    }

    // MARK: - Codable

    public enum CodingKeys: String, CodingKey {
        case id
        case streakId = "streak_id"
        case earnedDate = "earned_date"
        case usedDate = "used_date"
        case expiresAt = "expires_at"
    }

    // MARK: - Computed Properties

    /// Has this freeze been used?
    public var isUsed: Bool {
        usedDate != nil
    }

    /// Has this freeze expired?
    public var isExpired: Bool {
        // Always false per Decision #3A (freezes never expire)
        // But keep logic for future flexibility
        guard let expiresAt = expiresAt else { return false }
        return Date() > expiresAt
    }

    /// Is this freeze available to use?
    public var isAvailable: Bool {
        !isUsed && !isExpired
    }

    // MARK: - Validation

    /// Validates data integrity
    public var isValid: Bool {
        // ID must not be empty
        if id.isEmpty { return false }

        // usedDate must be > earnedDate if both present
        if let earned = earnedDate, let used = usedDate {
            if used < earned { return false }
        }

        // expiresAt must be > earnedDate if both present
        if let earned = earnedDate, let expires = expiresAt {
            if expires < earned { return false }
        }

        return true
    }

    // MARK: - Analytics

    /// Event parameters for analytics logging
    public var eventParameters: [String: Any] {
        var params: [String: Any] = [
            "streak_freeze_id": id,
            "streak_freeze_is_used": isUsed,
            "streak_freeze_is_expired": isExpired,
            "streak_freeze_is_available": isAvailable,
            "streak_freeze_streak_id": streakId
        ]

        if let earnedDate = earnedDate {
            params["streak_freeze_earned_date"] = earnedDate.timeIntervalSince1970
        }
        if let usedDate = usedDate {
            params["streak_freeze_used_date"] = usedDate.timeIntervalSince1970
        }

        return params
    }

    // MARK: - Mock Factory

    public static func mock(
        id: String = UUID().uuidString,
        streakId: String = "workout",
        earnedDate: Date = Date(),
        usedDate: Date? = nil,
        expiresAt: Date? = nil
    ) -> Self {
        StreakFreeze(
            id: id,
            streakId: streakId,
            earnedDate: earnedDate,
            usedDate: usedDate,
            expiresAt: expiresAt
        )
    }

    /// Mock unused freeze
    public static func mockUnused(
        id: String = UUID().uuidString,
        streakId: String = "workout"
    ) -> Self {
        StreakFreeze(
            id: id,
            streakId: streakId,
            earnedDate: Calendar.current.date(byAdding: .day, value: -7, to: Date()),
            usedDate: nil,
            expiresAt: nil
        )
    }

    /// Mock used freeze
    public static func mockUsed(
        id: String = UUID().uuidString,
        streakId: String = "workout"
    ) -> Self {
        let earnedDate = Calendar.current.date(byAdding: .day, value: -10, to: Date()) ?? Date()
        let usedDate = Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date()

        return StreakFreeze(
            id: id,
            streakId: streakId,
            earnedDate: earnedDate,
            usedDate: usedDate,
            expiresAt: nil
        )
    }

    /// Mock expired freeze (for future flexibility)
    public static func mockExpired(
        id: String = UUID().uuidString,
        streakId: String = "workout"
    ) -> Self {
        let earnedDate = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let expiresAt = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()

        return StreakFreeze(
            id: id,
            streakId: streakId,
            earnedDate: earnedDate,
            usedDate: nil,
            expiresAt: expiresAt
        )
    }
}
