//
//  FileManagerStreakPersistence.swift
//  SwiftfulGamification
//
//  Production-ready local persistence using FileManager
//

import Foundation

@MainActor
public struct FileManagerStreakPersistence: LocalStreakPersistence {

    public init() { }

    public func getSavedStreakData(streakKey: String) -> CurrentStreakData? {
        let key = "current_streak_\(streakKey)"
        return try? FileManager.getDocument(key: key)
    }

    public func saveCurrentStreakData(streakKey: String, _ streak: CurrentStreakData?) throws {
        let key = "current_streak_\(streakKey)"
        try FileManager.saveDocument(key: key, value: streak)
    }
}

extension FileManager {

    static func saveDocument<T: Codable>(key: String, value: T?) throws {
        let data = try JSONEncoder().encode(value)
        let url = getDocumentURL(for: key)
        try data.write(to: url)
    }

    static func getDocument<T: Codable>(key: String) throws -> T? {
        let url = getDocumentURL(for: key)
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private static func getDocumentURL(for key: String) -> URL {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("\(key).txt")
    }
}
