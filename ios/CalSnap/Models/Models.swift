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

/// Which meal of the day a logged item belongs to. Raw values match the
/// Django `Meal.MealType` choices (sent/received as snake-case-safe lowercase).
enum MealType: String, Codable, CaseIterable, Identifiable, Hashable {
    case breakfast
    case lunch
    case dinner

    var id: String { rawValue }
    var label: String { rawValue.capitalized }

    var icon: String {
        switch self {
        case .breakfast: return "sunrise.fill"
        case .lunch:     return "sun.max.fill"
        case .dinner:    return "moon.stars.fill"
        }
    }

    /// Sensible default for the picker, based on the current time of day.
    static var current: MealType {
        switch Calendar.current.component(.hour, from: Date()) {
        case 0..<11:  return .breakfast
        case 11..<16: return .lunch
        default:      return .dinner
        }
    }
}

/// A meal as returned by the server.
struct Meal: Codable, Identifiable, Hashable {
    let id: Int
    let mealType: MealType
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
    var mealType: MealType
    var foodName: String
    var calories: Int
    var protein: Int
    var carbs: Int
    var fat: Int
    var confidence: Double
    var note: String
    var imageData: Data?
    var createdAt: Date

    init(analysis: Analysis, mealType: MealType, imageData: Data?, note: String, createdAt: Date) {
        self.id = UUID()
        self.mealType = mealType
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

    // Custom decode so guest meals saved before meal_type existed still load
    // (missing/unknown type falls back to .lunch instead of failing the whole file).
    enum CodingKeys: String, CodingKey {
        case id, mealType, foodName, calories, protein, carbs, fat, confidence, note, imageData, createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        mealType = (try? c.decode(MealType.self, forKey: .mealType)) ?? .lunch
        foodName = try c.decode(String.self, forKey: .foodName)
        calories = try c.decode(Int.self, forKey: .calories)
        protein = try c.decode(Int.self, forKey: .protein)
        carbs = try c.decode(Int.self, forKey: .carbs)
        fat = try c.decode(Int.self, forKey: .fat)
        confidence = try c.decode(Double.self, forKey: .confidence)
        note = try c.decode(String.self, forKey: .note)
        imageData = try c.decodeIfPresent(Data.self, forKey: .imageData)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
    }
}

/// Unified meal for display — comes from either the server or local guest storage.
struct MealItem: Identifiable, Hashable {
    enum Source: Hashable {
        case server(Int)
        case local(UUID)
    }

    let source: Source
    let mealType: MealType
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
            mealType: mealType,
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
            mealType: mealType,
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
