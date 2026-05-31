import Foundation

enum APIError: LocalizedError {
    case server(String)
    case decoding
    case unauthorized
    case unknown

    var errorDescription: String? {
        switch self {
        case .server(let msg): return msg
        case .decoding: return "Couldn't read the server response."
        case .unauthorized: return "Your session expired. Please log in again."
        case .unknown: return "Something went wrong. Please try again."
        }
    }
}

/// Thin async/await REST client for the CalSnap backend.
struct APIClient {
    static let shared = APIClient()

    private let base = AppConfig.apiBaseURL

    private var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }

    // MARK: - Auth

    func register(email: String, password: String, goal: Int) async throws -> AuthResponse {
        try await postJSON(
            "/api/auth/register",
            body: ["email": email, "password": password, "daily_calorie_goal": goal],
            authed: false
        )
    }

    func login(email: String, password: String) async throws -> AuthResponse {
        try await postJSON(
            "/api/auth/login",
            body: ["email": email, "password": password],
            authed: false
        )
    }

    func me() async throws -> AuthUser {
        try await getJSON("/api/auth/me")
    }

    func updateGoal(_ goal: Int) async throws -> AuthUser {
        try await sendJSON("PATCH", "/api/auth/me", body: ["daily_calorie_goal": goal])
    }

    // MARK: - Meals

    func meals(date: String) async throws -> [Meal] {
        try await getJSON("/api/meals/?date=\(date)")
    }

    func weekly() async throws -> WeeklyStats {
        try await getJSON("/api/stats/weekly")
    }

    func deleteMeal(id: Int) async throws {
        let req = try request("DELETE", "/api/meals/\(id)/", authed: true)
        _ = try await perform(req, expectBody: false)
    }

    /// Multipart upload: image (+ optional note) -> Claude-analyzed meal.
    func createMeal(imageData: Data, note: String) async throws -> Meal {
        let boundary = "calsnap-\(UUID().uuidString)"
        var req = try request("POST", "/api/meals/", authed: true)
        req.setValue("multipart/form-data; boundary=\(boundary)",
                     forHTTPHeaderField: "Content-Type")

        var body = Data()
        func append(_ s: String) { body.append(Data(s.utf8)) }

        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"image\"; filename=\"meal.jpg\"\r\n")
        append("Content-Type: image/jpeg\r\n\r\n")
        body.append(imageData)
        append("\r\n")

        if !note.isEmpty {
            append("--\(boundary)\r\n")
            append("Content-Disposition: form-data; name=\"note\"\r\n\r\n")
            append(note)
            append("\r\n")
        }
        append("--\(boundary)--\r\n")
        req.httpBody = body

        let data = try await perform(req, expectBody: true)
        return try decode(data)
    }

    // MARK: - Plumbing

    private func request(_ method: String, _ path: String, authed: Bool) throws -> URLRequest {
        guard let url = URL(string: path, relativeTo: base) else { throw APIError.unknown }
        var req = URLRequest(url: url)
        req.httpMethod = method
        if authed {
            guard let token = Keychain.accessToken else { throw APIError.unauthorized }
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return req
    }

    @discardableResult
    private func perform(_ req: URLRequest, expectBody: Bool) async throws -> Data {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: req)
        } catch {
            throw APIError.server(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else { throw APIError.unknown }

        guard (200..<300).contains(http.statusCode) else {
            if http.statusCode == 401 { throw APIError.unauthorized }
            // Try to surface {"detail": "..."} from DRF.
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let detail = obj["detail"] as? String { throw APIError.server(detail) }
                if let first = obj.values.first as? [String], let msg = first.first {
                    throw APIError.server(msg)
                }
            }
            throw APIError.server("Request failed (\(http.statusCode)).")
        }
        return data
    }

    private func decode<T: Decodable>(_ data: Data) throws -> T {
        do { return try decoder.decode(T.self, from: data) }
        catch { throw APIError.decoding }
    }

    private func getJSON<T: Decodable>(_ path: String) async throws -> T {
        let req = try request("GET", path, authed: true)
        return try decode(try await perform(req, expectBody: true))
    }

    private func postJSON<T: Decodable>(_ path: String, body: [String: Any], authed: Bool) async throws -> T {
        try await sendJSON("POST", path, body: body, authed: authed)
    }

    private func sendJSON<T: Decodable>(_ method: String, _ path: String, body: [String: Any], authed: Bool = true) async throws -> T {
        var req = try request(method, path, authed: authed)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try decode(try await perform(req, expectBody: true))
    }
}
