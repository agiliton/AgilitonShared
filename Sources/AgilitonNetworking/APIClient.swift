import Foundation
import AgilitonCore
import OSLog

/// Shared API client using native URLSession with async/await
public class APIClient {
    private let session: URLSession
    private let baseURL: URL
    private let logger = AgilitonLogger.shared
    private let maxRetries = 3

    public init(baseURL: URL,
                configuration: URLSessionConfiguration = .default) {
        self.baseURL = baseURL
        self.session = URLSession(configuration: configuration)
    }

    /// Generic request method with automatic decoding
    public func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        let url = baseURL.appendingPathComponent(endpoint.path)
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue

        // Add headers
        endpoint.headers?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }

        // Add parameters for GET requests
        if endpoint.method == .get, let parameters = endpoint.parameters {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.queryItems = parameters.map { URLQueryItem(name: $0.key, value: "\($0.value)") }
            if let urlWithParams = components?.url {
                request.url = urlWithParams
            }
        }

        // Add body for POST/PUT requests
        if (endpoint.method == .post || endpoint.method == .put), let parameters = endpoint.parameters {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        logger.debug("Request: \(endpoint.method.rawValue) \(url)")

        // Retry logic with exponential backoff
        var lastError: Error?
        for attempt in 0..<maxRetries {
            do {
                let (data, response) = try await session.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NetworkError.invalidResponse
                }

                guard (200...299).contains(httpResponse.statusCode) else {
                    throw NetworkError.httpError(httpResponse.statusCode)
                }

                logger.debug("Success: \(url)")

                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                return try decoder.decode(T.self, from: data)
            } catch {
                lastError = error

                // Don't retry on client errors (4xx)
                if case NetworkError.httpError(let code) = error, (400...499).contains(code) {
                    throw error
                }

                // Exponential backoff for retries
                if attempt < maxRetries - 1 {
                    let delay = pow(2.0, Double(attempt)) * 0.5
                    logger.debug("Retry \(attempt + 1) after \(delay)s")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }

        logger.error("Request failed after \(maxRetries) attempts: \((lastError ?? NetworkError.unknown).localizedDescription)")
        throw lastError ?? NetworkError.unknown
    }
}

/// HTTP methods
public enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
    case patch = "PATCH"
}

/// Protocol for API endpoints
public protocol Endpoint {
    var path: String { get }
    var method: HTTPMethod { get }
    var parameters: [String: Any]? { get }
    var headers: [String: String]? { get }
}

/// Network errors
public enum NetworkError: LocalizedError {
    case noConnection
    case timeout
    case httpError(Int)
    case invalidResponse
    case unknown

    public var errorDescription: String? {
        switch self {
        case .noConnection:
            return "No internet connection"
        case .timeout:
            return "Request timed out"
        case .httpError(let code):
            return "Server error: \(code)"
        case .invalidResponse:
            return "Invalid response from server"
        case .unknown:
            return "An unknown error occurred"
        }
    }
}