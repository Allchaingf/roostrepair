//
//  Persistence.swift
//  RoostRepair
//
//  Tiny Codable <-> UserDefaults helpers + image file storage in Documents.
//  Everything in the app is offline and lives on-device.
//

import SwiftUI

enum Persistence {
    private static let defaults = UserDefaults.standard

    static func save<T: Encodable>(_ value: T, key: String) {
        if let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: key)
        }
    }

    static func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    static func remove(_ key: String) {
        defaults.removeObject(forKey: key)
    }
}

// MARK: - Image storage (for Photo Markup)

enum ImageStore {
    private static var directory: URL {
        let url = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("RoostPhotos", isDirectory: true)
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }

    /// Persist a UIImage as JPEG, returning the file name to store in the model.
    static func save(_ image: UIImage) -> String? {
        let name = "photo-\(UUID().uuidString).jpg"
        guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }
        let url = directory.appendingPathComponent(name)
        do {
            try data.write(to: url)
            return name
        } catch {
            return nil
        }
    }

    static func load(_ name: String) -> UIImage? {
        let url = directory.appendingPathComponent(name)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    static func delete(_ name: String) {
        let url = directory.appendingPathComponent(name)
        try? FileManager.default.removeItem(at: url)
    }
}
