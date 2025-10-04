//
//  GamificationError.swift
//  SwiftfulGamification
//
//  Created by Nick Sarno on 2025-09-30.
//

import Foundation

/// Errors that can occur in the gamification system
public enum GamificationError: Error, LocalizedError, Sendable {
    // MARK: - Validation Errors

    /// Streak ID failed regex validation (must be lowercase letters, numbers, underscores only)
    case invalidStreakId(String)

    /// Event timestamp is in the future or too old
    case invalidTimestamp(Date)

    /// Timezone identifier is not valid
    case invalidTimezone(String)

    /// Metadata contains invalid keys or values
    case invalidMetadata(reason: String)

    // MARK: - Business Logic Errors

    /// Cannot calculate streak without any events
    case noEventsRecorded

    /// Streak not found for given userId + streakId
    case noStreakFound

    /// No freezes available to consume
    case freezeNotAvailable

    /// Freeze has already been used
    case freezeAlreadyUsed(freezeId: String)

    // MARK: - System Errors

    /// Failed to read/write cache
    case cachingFailed(Error)

    /// Failed to decode data
    case decodingFailed(Error)

    /// Failed to encode data
    case encodingFailed(Error)

    /// Network or server error
    case networkError(Error)

    // MARK: - LocalizedError Conformance

    public var errorDescription: String? {
        switch self {
        case .invalidStreakId(let id):
            return "Invalid streak ID: '\(id)'"
        case .invalidTimestamp(let date):
            return "Invalid timestamp: \(date)"
        case .invalidTimezone(let tz):
            return "Invalid timezone: '\(tz)'"
        case .invalidMetadata(let reason):
            return "Invalid metadata: \(reason)"
        case .noEventsRecorded:
            return "No events recorded"
        case .noStreakFound:
            return "Streak not found"
        case .freezeNotAvailable:
            return "No freeze available"
        case .freezeAlreadyUsed(let id):
            return "Freeze '\(id)' already used"
        case .cachingFailed:
            return "Caching failed"
        case .decodingFailed:
            return "Failed to decode data"
        case .encodingFailed:
            return "Failed to encode data"
        case .networkError:
            return "Network error"
        }
    }

    public var failureReason: String? {
        switch self {
        case .invalidStreakId:
            return "Streak ID must contain only lowercase letters, numbers, and underscores"
        case .invalidTimestamp:
            return "Timestamp must not be in the future and not older than 1 year"
        case .invalidTimezone:
            return "Timezone identifier is not recognized by the system"
        case .invalidMetadata(let reason):
            return reason
        case .noEventsRecorded:
            return "At least one event must be logged before calculating streak"
        case .noStreakFound:
            return "No streak data exists for this user and streak ID combination"
        case .freezeNotAvailable:
            return "User has no available freezes remaining"
        case .freezeAlreadyUsed:
            return "This freeze has already been consumed"
        case .cachingFailed(let error):
            return "Failed to access local cache: \(error.localizedDescription)"
        case .decodingFailed(let error):
            return "Failed to decode data: \(error.localizedDescription)"
        case .encodingFailed(let error):
            return "Failed to encode data: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network operation failed: \(error.localizedDescription)"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .invalidStreakId:
            return "Use only lowercase letters (a-z), numbers (0-9), and underscores (_) in streak IDs"
        case .invalidTimestamp:
            return "Ensure event timestamps are current and not backdated more than 1 year"
        case .invalidTimezone:
            return "Use a valid timezone identifier like 'America/New_York' or 'UTC'"
        case .invalidMetadata:
            return "Check that metadata keys contain only alphanumeric characters and underscores"
        case .noEventsRecorded:
            return "Log at least one event before checking streak status"
        case .noStreakFound:
            return "Initialize the streak by logging your first event"
        case .freezeNotAvailable:
            return "Earn or purchase more streak freezes"
        case .freezeAlreadyUsed:
            return "This freeze cannot be reused"
        case .cachingFailed:
            return "Check file permissions and available storage"
        case .decodingFailed:
            return "Data may be corrupted or in an incompatible format"
        case .encodingFailed:
            return "Ensure all data is valid and serializable"
        case .networkError:
            return "Check your internet connection and try again"
        }
    }

    // MARK: - Helper Methods

    /// Is this error recoverable by retrying?
    public var isRecoverable: Bool {
        switch self {
        case .networkError, .cachingFailed:
            return true
        case .invalidStreakId, .invalidTimestamp, .invalidTimezone, .invalidMetadata,
             .noEventsRecorded, .noStreakFound, .freezeNotAvailable, .freezeAlreadyUsed,
             .decodingFailed, .encodingFailed:
            return false
        }
    }

    /// Is this a validation error (user input issue)?
    public var isValidationError: Bool {
        switch self {
        case .invalidStreakId, .invalidTimestamp, .invalidTimezone, .invalidMetadata:
            return true
        case .noEventsRecorded, .noStreakFound, .freezeNotAvailable, .freezeAlreadyUsed,
             .cachingFailed, .decodingFailed, .encodingFailed, .networkError:
            return false
        }
    }

    /// Is this a system error (not user's fault)?
    public var isSystemError: Bool {
        switch self {
        case .cachingFailed, .decodingFailed, .encodingFailed, .networkError:
            return true
        case .invalidStreakId, .invalidTimestamp, .invalidTimezone, .invalidMetadata,
             .noEventsRecorded, .noStreakFound, .freezeNotAvailable, .freezeAlreadyUsed:
            return false
        }
    }
}
