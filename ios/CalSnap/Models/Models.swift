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
}
