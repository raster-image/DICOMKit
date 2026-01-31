import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Main client for DICOMweb services
///
/// Provides access to WADO-RS, STOW-RS, QIDO-RS, and UPS-RS services
/// through a unified interface.
///
/// Reference: DICOM PS3.18 - Web Services
public final class DICOMWebClient: @unchecked Sendable {
    
    /// The configuration for this client
    public let configuration: DICOMWebConfiguration
    
    /// The underlying URL session
    private let session: URLSession
    
    /// WADO-RS service for retrieving DICOM objects
    public let wado: WADOService
    
    /// QIDO-RS service for querying DICOM objects
    public let qido: QIDOService
    
    /// STOW-RS service for storing DICOM objects
    public let stow: STOWService
    
    /// UPS-RS service for managing worklists
    public let ups: UPSService
    
    /// Creates a DICOMweb client with the given configuration
    /// - Parameter configuration: The client configuration
    public init(configuration: DICOMWebConfiguration) {
        self.configuration = configuration
        
        // Configure URL session
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = configuration.timeout
        sessionConfig.timeoutIntervalForResource = configuration.timeout * 2
        sessionConfig.httpMaximumConnectionsPerHost = configuration.maxConcurrentRequests
        
        // Add custom headers
        var headers = configuration.customHeaders
        headers.merge(configuration.authentication.headers) { _, new in new }
        sessionConfig.httpAdditionalHeaders = headers
        
        self.session = URLSession(configuration: sessionConfig)
        
        // Create services
        let httpClient = HTTPClient(session: session, configuration: configuration)
        self.wado = WADOService(client: httpClient)
        self.qido = QIDOService(client: httpClient)
        self.stow = STOWService(client: httpClient)
        self.ups = UPSService(client: httpClient)
    }
    
    /// Creates a DICOMweb client with a base URL
    /// - Parameter baseURL: The base URL for the DICOMweb service
    public convenience init(baseURL: URL) {
        self.init(configuration: DICOMWebConfiguration(baseURL: baseURL))
    }
    
    /// Creates a DICOMweb client with a base URL and authentication
    /// - Parameters:
    ///   - baseURL: The base URL for the DICOMweb service
    ///   - authentication: The authentication method
    public convenience init(baseURL: URL, authentication: DICOMWebAuthentication) {
        self.init(configuration: DICOMWebConfiguration(baseURL: baseURL, authentication: authentication))
    }
}

// MARK: - HTTP Client

/// Internal HTTP client for making requests
internal final class HTTPClient: @unchecked Sendable {
    
    let session: URLSession
    let configuration: DICOMWebConfiguration
    
    init(session: URLSession, configuration: DICOMWebConfiguration) {
        self.session = session
        self.configuration = configuration
    }
    
    /// Performs a GET request
    /// - Parameters:
    ///   - path: The request path relative to base URL
    ///   - queryItems: Query parameters
    ///   - accept: Accept header value
    /// - Returns: Response data and HTTP response
    func get(
        path: String,
        queryItems: [URLQueryItem] = [],
        accept: String? = nil
    ) async throws -> (Data, HTTPURLResponse) {
        let url = try buildURL(path: path, queryItems: queryItems)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        if let accept = accept {
            request.setValue(accept, forHTTPHeaderField: "Accept")
        }
        
        return try await performRequest(request)
    }
    
    /// Performs a POST request
    /// - Parameters:
    ///   - path: The request path relative to base URL
    ///   - queryItems: Query parameters
    ///   - body: Request body data
    ///   - contentType: Content-Type header value
    ///   - accept: Accept header value
    /// - Returns: Response data and HTTP response
    func post(
        path: String,
        queryItems: [URLQueryItem] = [],
        body: Data,
        contentType: String,
        accept: String? = nil
    ) async throws -> (Data, HTTPURLResponse) {
        let url = try buildURL(path: path, queryItems: queryItems)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        
        if let accept = accept {
            request.setValue(accept, forHTTPHeaderField: "Accept")
        }
        
        return try await performRequest(request)
    }
    
    /// Performs a PUT request
    /// - Parameters:
    ///   - path: The request path relative to base URL
    ///   - body: Request body data
    ///   - contentType: Content-Type header value
    ///   - accept: Accept header value
    /// - Returns: Response data and HTTP response
    func put(
        path: String,
        body: Data,
        contentType: String,
        accept: String? = nil
    ) async throws -> (Data, HTTPURLResponse) {
        let url = try buildURL(path: path, queryItems: [])
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.httpBody = body
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        
        if let accept = accept {
            request.setValue(accept, forHTTPHeaderField: "Accept")
        }
        
        return try await performRequest(request)
    }
    
    /// Performs a DELETE request
    /// - Parameter path: The request path relative to base URL
    /// - Returns: Response data and HTTP response
    func delete(path: String) async throws -> (Data, HTTPURLResponse) {
        let url = try buildURL(path: path, queryItems: [])
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        return try await performRequest(request)
    }
    
    private func buildURL(path: String, queryItems: [URLQueryItem]) throws -> URL {
        var urlString = configuration.baseURL.absoluteString
        if !urlString.hasSuffix("/") && !path.hasPrefix("/") {
            urlString += "/"
        }
        urlString += path
        
        guard var components = URLComponents(string: urlString) else {
            throw DICOMWebError.invalidURL(urlString)
        }
        
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        
        guard let url = components.url else {
            throw DICOMWebError.invalidURL(urlString)
        }
        
        return url
    }
    
    private func performRequest(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DICOMWebError.internalError("Invalid response type")
        }
        
        // Check for HTTP errors
        if httpResponse.statusCode >= 400 {
            let message = String(data: data, encoding: .utf8) ?? ""
            throw DICOMWebError.fromHTTPStatus(httpResponse.statusCode, message: message)
        }
        
        return (data, httpResponse)
    }
}
