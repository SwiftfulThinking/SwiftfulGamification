//
//  StringSanitizationTests.swift
//  SwiftfulGamificationTests
//
//  Created by Nick Sarno on 2025-10-14.
//

import Testing
@testable import SwiftfulGamification

@Suite("String Sanitization Tests")
struct StringSanitizationTests {

    @Test("Sanitize lowercase string")
    func testSanitizeLowercase() {
        let input = "alpha"
        let result = input.sanitizeForDatabaseKeysByConvertingToLowercaseAndRemovingWhitespaceAndSpecialCharacters()
        #expect(result == "alpha")
    }

    @Test("Sanitize uppercase string")
    func testSanitizeUppercase() {
        let input = "Alpha"
        let result = input.sanitizeForDatabaseKeysByConvertingToLowercaseAndRemovingWhitespaceAndSpecialCharacters()
        #expect(result == "alpha")
    }

    @Test("Sanitize string with space")
    func testSanitizeWithSpace() {
        let input = "Alpha 123"
        let result = input.sanitizeForDatabaseKeysByConvertingToLowercaseAndRemovingWhitespaceAndSpecialCharacters()
        #expect(result == "alpha_123")
    }

    @Test("Sanitize string with special characters")
    func testSanitizeWithSpecialCharacters() {
        let input = "My Level!"
        let result = input.sanitizeForDatabaseKeysByConvertingToLowercaseAndRemovingWhitespaceAndSpecialCharacters()
        #expect(result == "my_level")
    }

    @Test("Sanitize string with multiple spaces")
    func testSanitizeWithMultipleSpaces() {
        let input = "  Hello   World  "
        let result = input.sanitizeForDatabaseKeysByConvertingToLowercaseAndRemovingWhitespaceAndSpecialCharacters()
        #expect(result == "hello_world")
    }

    @Test("Sanitize string with tabs and newlines")
    func testSanitizeWithTabsAndNewlines() {
        let input = "Hello\tWorld\nTest"
        let result = input.sanitizeForDatabaseKeysByConvertingToLowercaseAndRemovingWhitespaceAndSpecialCharacters()
        #expect(result == "hello_world_test")
    }

    @Test("Sanitize string with multiple special characters")
    func testSanitizeWithMultipleSpecialCharacters() {
        let input = "Level@#$%123"
        let result = input.sanitizeForDatabaseKeysByConvertingToLowercaseAndRemovingWhitespaceAndSpecialCharacters()
        #expect(result == "level123")
    }

    @Test("Sanitize string with leading and trailing underscores")
    func testSanitizeWithLeadingTrailingUnderscores() {
        let input = "___hello___"
        let result = input.sanitizeForDatabaseKeysByConvertingToLowercaseAndRemovingWhitespaceAndSpecialCharacters()
        #expect(result == "hello")
    }

    @Test("Sanitize string with consecutive underscores")
    func testSanitizeWithConsecutiveUnderscores() {
        let input = "hello___world"
        let result = input.sanitizeForDatabaseKeysByConvertingToLowercaseAndRemovingWhitespaceAndSpecialCharacters()
        #expect(result == "hello_world")
    }

    @Test("Sanitize empty string returns fallback")
    func testSanitizeEmptyString() {
        let input = ""
        let result = input.sanitizeForDatabaseKeysByConvertingToLowercaseAndRemovingWhitespaceAndSpecialCharacters()
        #expect(result == "item")
    }

    @Test("Sanitize string with only special characters returns fallback")
    func testSanitizeOnlySpecialCharacters() {
        let input = "!@#$%^&*()"
        let result = input.sanitizeForDatabaseKeysByConvertingToLowercaseAndRemovingWhitespaceAndSpecialCharacters()
        #expect(result == "item")
    }

    @Test("Sanitize complex real-world example")
    func testSanitizeComplexExample() {
        let input = "  World 1 - Level 5 (Hard Mode)!  "
        let result = input.sanitizeForDatabaseKeysByConvertingToLowercaseAndRemovingWhitespaceAndSpecialCharacters()
        #expect(result == "world_1_level_5_hard_mode")
    }

    @Test("Sanitize string with numbers only")
    func testSanitizeNumbersOnly() {
        let input = "12345"
        let result = input.sanitizeForDatabaseKeysByConvertingToLowercaseAndRemovingWhitespaceAndSpecialCharacters()
        #expect(result == "12345")
    }

    @Test("Sanitize string with underscores already present")
    func testSanitizeWithExistingUnderscores() {
        let input = "hello_world"
        let result = input.sanitizeForDatabaseKeysByConvertingToLowercaseAndRemovingWhitespaceAndSpecialCharacters()
        #expect(result == "hello_world")
    }

    @Test("Sanitize mixed case alphanumeric")
    func testSanitizeMixedCaseAlphanumeric() {
        let input = "TestLevel123"
        let result = input.sanitizeForDatabaseKeysByConvertingToLowercaseAndRemovingWhitespaceAndSpecialCharacters()
        #expect(result == "testlevel123")
    }
}
