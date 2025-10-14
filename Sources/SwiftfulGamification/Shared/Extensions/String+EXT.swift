//
//  String+EXT.swift
//  SwiftfulGamification
//
//  Created by Nick Sarno on 2025-10-14.
//

import Foundation

extension String {

    /// Sanitizes string for use as database key by converting to lowercase and removing whitespace and special characters
    ///
    /// Rules:
    /// - Converts to lowercase
    /// - Replaces whitespace with underscores
    /// - Removes special characters (keeps alphanumeric and underscores only)
    /// - Trims leading/trailing underscores
    /// - Collapses multiple consecutive underscores to single underscore
    ///
    /// Examples:
    /// - "Alpha" → "alpha"
    /// - "Alpha 123" → "alpha_123"
    /// - "My Level!" → "my_level"
    /// - "  Hello   World  " → "hello_world"
    /// - "" → "item" (fallback for empty strings)
    public func sanitizeForDatabaseKeysByConvertingToLowercaseAndRemovingWhitespaceAndSpecialCharacters() -> String {
        // Step 1: Convert to lowercase
        var sanitized = self.lowercased()

        // Step 2: Replace whitespace with underscores
        sanitized = sanitized.replacingOccurrences(of: " ", with: "_")
        sanitized = sanitized.replacingOccurrences(of: "\t", with: "_")
        sanitized = sanitized.replacingOccurrences(of: "\n", with: "_")

        // Step 3: Remove all non-alphanumeric characters (except underscores)
        sanitized = sanitized.filter { $0.isLetter || $0.isNumber || $0 == "_" }

        // Step 4: Collapse multiple consecutive underscores to single underscore
        while sanitized.contains("__") {
            sanitized = sanitized.replacingOccurrences(of: "__", with: "_")
        }

        // Step 5: Trim leading and trailing underscores
        sanitized = sanitized.trimmingCharacters(in: CharacterSet(charactersIn: "_"))

        // Step 6: If result is empty, use a fallback
        if sanitized.isEmpty {
            return "item"
        }

        return sanitized
    }
}
