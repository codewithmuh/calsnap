import Foundation

struct AuthUser: Codable, Identifiable, Hashable {
    let id: Int
    let email: String
    var dailyCalorieGoal: Int
}

struct Tokens: Codable {
    let access: String
    let refresh: String
}

struct AuthResponse: Codable {
    let user: AuthUser
    let tokens: Tokens
}

/// Result of a Claude analysis (from /api/analyze/). Not yet saved anywhere.
struct Analysis: Codable, Hashable {
    let foodName: String
    let calories: Int
    let protein: Int
    let carbs: Int
    let fat: Int
    let confidence: Double
}

/// A meal as returned by the server.
struct Meal: Codable, Identifiable, Hashable {
    let id: Int
    let foodName: String
    let calories: Int
    let protein: Int
    let carbs: Int
    let fat: Int
    let confidence: Double
    let note: String
    let imageUrl: String?
    let createdAt: String

    var createdDate: Date {
        ISO8601DateFormatter.calsnap.date(from: createdAt) ?? Date()
    }
}

/// A meal logged in guest mode, persisted on-device only.
struct LocalMeal: Codable, Identifiable, Hashable {
    var id: UUID
    var foodName: String
    var calories: Int
    var protein: Int
    var carbs: Int
    var fat: Int
    var confidence: Double
    var note: String
    var imageData: Data?
    var createdAt: Date

    init(analysis: Analysis, imageData: Data?, note: String, createdAt: Date) {
        self.id = UUID()
        self.foodName = analysis.foodName
        self.calories = analysis.calories
        self.protein = analysis.protein
        self.carbs = analysis.carbs
        self.fat = analysis.fat
        self.confidence = analysis.confidence
        self.note = note
        self.imageData = imageData
        self.createdAt = createdAt
    }

    var analysis: Analysis {
        Analysis(foodName: foodName, calories: calories, protein: protein,
                 carbs: carbs, fat: fat, confidence: confidence)
    }
}

/// Unified meal for display — comes from either the server or local guest storage.
struct MealItem: Identifiable, Hashable {
    enum Source: Hashable {
        case server(Int)
        case local(UUID)
    }

    let source: Source
    let foodName: String
    let calories: Int
    let protein: Int
    let carbs: Int
    let fat: Int
    let confidence: Double
    let note: String
    let createdAt: Date
    let imageURL: URL?
    let imageData: Data?

    var id: String {
        switch source {
        case .server(let i): return "s\(i)"
        case .local(let u): return "l\(u.uuidString)"
        }
    }

    var serverID: Int? {
        if case .server(let i) = source { return i }
        return nil
    }

    var localID: UUID? {
        if case .local(let u) = source { return u }
        return nil
    }
}

extension Meal {
    var asItem: MealItem {
        MealItem(
            source: .server(id),
            foodName: foodName, calories: calories, protein: protein,
            carbs: carbs, fat: fat, confidence: confidence, note: note,
            createdAt: createdDate,
            imageURL: imageUrl.flatMap(URL.init),
            imageData: nil
        )
    }
}

extension LocalMeal {
    var asItem: MealItem {
        MealItem(
            source: .local(id),
            foodName: foodName, calories: calories, protein: protein,
            carbs: carbs, fat: fat, confidence: confidence, note: note,
            createdAt: createdAt,
            imageURL: nil,
            imageData: imageData
        )
    }
}

struct DayStat: Codable, Identifiable, Hashable {
    var id: String { date }
    let date: String
    let calories: Int
    let protein: Int
    let carbs: Int
    let fat: Int

    var day: Date {
        DateFormatter.yyyyMMddUTC.date(from: date) ?? Date()
    }
}

struct WeeklyStats: Codable {
    let goal: Int
    let days: [DayStat]
}

extension ISO8601DateFormatter {
    static let calsnap: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}

extension DateFormatter {
    static let yyyyMMddUTC: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// Today's date string in UTC, matching the backend's `created_at__date` filter.
    static func todayUTCString() -> String {
        yyyyMMddUTC.string(from: Date())
    }

    static func utcString(from date: Date) -> String {
        yyyyMMddUTC.string(from: date)
    }
}
