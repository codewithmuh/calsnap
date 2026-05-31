import Foundation

enum AppConfig {
    /// Base URL of the Django API.
    ///
    /// - Simulator talks to your Mac via 127.0.0.1.
    /// - On a real device, set this to your Mac's LAN IP, e.g. http://192.168.1.20:8008
    ///
    /// Port 8008 matches the Docker `web` host port (WEB_HOST_PORT in docker-compose.yml).
    static let apiBaseURL = URL(string: "http://127.0.0.1:8008")!
}
