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

    /// When the freeze was earned
    public let dateEarned: Date?

    /// When the freeze was consumed (nil if unused)
    public let dateUsed: Date?

    /// When the freeze expires (nil = never expires per Decision #3A)
    public let dateExpires: Date?

    // MARK: - Initialization

    public init(
        id: String,
        dateEarned: Date? = nil,
        dateUsed: Date? = nil,
        dateExpires: Date? = nil
    ) {
        self.id = id
        self.dateEarned = dateEarned
        self.dateUsed = dateUsed
        self.dateExpires = dateExpires
    }

    // MARK: - Codable

    public enum CodingKeys: String, CodingKey {
        case id
        case dateEarned = "date_earned"
        case dateUsed = "date_used"
        case dateExpires = "date_expires"
    }

    // MARK: - Computed Properties

    /// Has this freeze been used?
    public var isUsed: Bool {
        dateUsed != nil
    }

    /// Has this freeze expired?
    public var isExpired: Bool {
        // Always false per Decision #3A (freezes never expire)
        // But keep logic for future flexibility
        guard let dateExpires = dateExpires else { return false }
        return Date() > dateExpires
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
        if let earned = dateEarned, let used = dateUsed {
            if used < earned { return false }
        }

        // expiresAt must be > earnedDate if both present
        if let earned = dateEarned, let expires = dateExpires {
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
            "streak_freeze_is_available": isAvailable
        ]

        if let dateEarned = dateEarned {
            params["streak_freeze_earned_date"] = dateEarned.timeIntervalSince1970
        }
        if let dateUsed = dateUsed {
            params["streak_freeze_used_date"] = dateUsed.timeIntervalSince1970
        }

        return params
    }

    // MARK: - Mock Factory

    public static func mock(
        id: String = UUID().uuidString,
        dateEarned: Date = Date(),
        dateUsed: Date? = nil,
        dateExpires: Date? = nil
    ) -> Self {
        StreakFreeze(
            id: id,
            dateEarned: dateEarned,
            dateUsed: dateUsed,
            dateExpires: dateExpires
        )
    }

    /// Mock unused freeze
    public static func mockUnused(
        id: String = UUID().uuidString
    ) -> Self {
        StreakFreeze(
            id: id,
            dateEarned: Calendar.current.date(byAdding: .day, value: -7, to: Date()),
            dateUsed: nil,
            dateExpires: nil
        )
    }

    /// Mock used freeze
    public static func mockUsed(
        id: String = UUID().uuidString
    ) -> Self {
        let dateEarned = Calendar.current.date(byAdding: .day, value: -10, to: Date()) ?? Date()
        let dateUsed = Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date()

        return StreakFreeze(
            id: id,
            dateEarned: dateEarned,
            dateUsed: dateUsed,
            dateExpires: nil
        )
    }

    /// Mock expired freeze (for future flexibility)
    public static func mockExpired(
        id: String = UUID().uuidString
    ) -> Self {
        let dateEarned = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let dateExpires = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()

        return StreakFreeze(
            id: id,
            dateEarned: dateEarned,
            dateUsed: nil,
            dateExpires: dateExpires
        )
    }
}
