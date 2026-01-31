import Foundation

/// Configuration for a DICOMweb client
///
/// Reference: DICOM PS3.18 Section 6 - Web Services Interface
public struct DICOMWebConfiguration: Sendable {
    
    /// The base URL for the DICOMweb service
    /// Example: https://pacs.hospital.com/dicomweb
    public let baseURL: URL
    
    /// Authentication configuration
    public let authentication: DICOMWebAuthentication
    
    /// Request timeout in seconds
    public let timeout: TimeInterval
    
    /// Maximum concurrent requests
    public let maxConcurrentRequests: Int
    
    /// Whether to validate SSL certificates
    public let validateCertificates: Bool
    
    /// Custom HTTP headers to include in all requests
    public let customHeaders: [String: String]
    
    /// Preferred transfer syntaxes for WADO-RS requests
    /// Listed in order of preference
    public let preferredTransferSyntaxes: [String]
    
    /// Maximum PDU size for multipart responses
    public let maxPartSize: Int
    
    /// Default limit for search results
    public let defaultSearchLimit: Int
    
    /// Creates a DICOMweb configuration
    /// - Parameters:
    ///   - baseURL: The base URL for the DICOMweb service
    ///   - authentication: Authentication configuration (default: none)
    ///   - timeout: Request timeout in seconds (default: 60)
    ///   - maxConcurrentRequests: Maximum concurrent requests (default: 4)
    ///   - validateCertificates: Whether to validate SSL certificates (default: true)
    ///   - customHeaders: Custom HTTP headers (default: empty)
    ///   - preferredTransferSyntaxes: Preferred transfer syntaxes (default: standard list)
    ///   - maxPartSize: Maximum size per multipart part (default: 10MB)
    ///   - defaultSearchLimit: Default limit for search results (default: 100)
    public init(
        baseURL: URL,
        authentication: DICOMWebAuthentication = .none,
        timeout: TimeInterval = 60,
        maxConcurrentRequests: Int = 4,
        validateCertificates: Bool = true,
        customHeaders: [String: String] = [:],
        preferredTransferSyntaxes: [String] = DICOMWebConfiguration.defaultTransferSyntaxes,
        maxPartSize: Int = 10 * 1024 * 1024,
        defaultSearchLimit: Int = 100
    ) {
        self.baseURL = baseURL
        self.authentication = authentication
        self.timeout = timeout
        self.maxConcurrentRequests = maxConcurrentRequests
        self.validateCertificates = validateCertificates
        self.customHeaders = customHeaders
        self.preferredTransferSyntaxes = preferredTransferSyntaxes
        self.maxPartSize = maxPartSize
        self.defaultSearchLimit = defaultSearchLimit
    }
    
    /// Default transfer syntaxes in order of preference
    public static let defaultTransferSyntaxes: [String] = [
        "1.2.840.10008.1.2.1",     // Explicit VR Little Endian
        "1.2.840.10008.1.2",       // Implicit VR Little Endian
        "1.2.840.10008.1.2.4.90",  // JPEG 2000 Lossless
        "1.2.840.10008.1.2.4.70",  // JPEG Lossless
        "1.2.840.10008.1.2.4.50",  // JPEG Baseline
    ]
}

// MARK: - Authentication

/// Authentication methods for DICOMweb services
public enum DICOMWebAuthentication: Sendable, Equatable {
    
    /// No authentication
    case none
    
    /// Basic authentication with username and password
    case basic(username: String, password: String)
    
    /// Bearer token authentication
    case bearer(token: String)
    
    /// OAuth2 authentication
    case oauth2(configuration: OAuth2Configuration)
    
    /// API key authentication
    case apiKey(headerName: String, value: String)
    
    /// Custom authentication with header name and value
    case custom(headers: [String: String])
    
    /// Returns the HTTP headers for this authentication method
    public var headers: [String: String] {
        switch self {
        case .none:
            return [:]
        case .basic(let username, let password):
            let credentials = "\(username):\(password)"
            let data = Data(credentials.utf8)
            let base64 = data.base64EncodedString()
            return ["Authorization": "Basic \(base64)"]
        case .bearer(let token):
            return ["Authorization": "Bearer \(token)"]
        case .oauth2:
            // OAuth2 headers are managed by the token refresh mechanism
            return [:]
        case .apiKey(let headerName, let value):
            return [headerName: value]
        case .custom(let headers):
            return headers
        }
    }
}

// MARK: - OAuth2 Configuration

/// OAuth2 configuration for DICOMweb authentication
///
/// Reference: RFC 6749 - The OAuth 2.0 Authorization Framework
public struct OAuth2Configuration: Sendable, Equatable {
    
    /// Token endpoint URL
    public let tokenEndpoint: URL
    
    /// Client ID
    public let clientID: String
    
    /// Client secret (optional, depends on grant type)
    public let clientSecret: String?
    
    /// OAuth2 scopes
    public let scopes: [String]
    
    /// Grant type
    public let grantType: OAuth2GrantType
    
    /// OpenID Connect discovery endpoint (optional)
    public let discoveryEndpoint: URL?
    
    /// Creates an OAuth2 configuration
    /// - Parameters:
    ///   - tokenEndpoint: Token endpoint URL
    ///   - clientID: Client ID
    ///   - clientSecret: Client secret (optional)
    ///   - scopes: OAuth2 scopes
    ///   - grantType: Grant type (default: .clientCredentials)
    ///   - discoveryEndpoint: OpenID Connect discovery endpoint (optional)
    public init(
        tokenEndpoint: URL,
        clientID: String,
        clientSecret: String? = nil,
        scopes: [String] = [],
        grantType: OAuth2GrantType = .clientCredentials,
        discoveryEndpoint: URL? = nil
    ) {
        self.tokenEndpoint = tokenEndpoint
        self.clientID = clientID
        self.clientSecret = clientSecret
        self.scopes = scopes
        self.grantType = grantType
        self.discoveryEndpoint = discoveryEndpoint
    }
}

/// OAuth2 grant types
public enum OAuth2GrantType: String, Sendable, Equatable {
    case clientCredentials = "client_credentials"
    case authorizationCode = "authorization_code"
    case refreshToken = "refresh_token"
    case password = "password"
}

// MARK: - Media Types

/// DICOMweb media types as defined in PS3.18
public enum DICOMWebMediaType: String, Sendable {
    
    // MARK: - DICOM Media Types
    
    /// DICOM with any transfer syntax (default for WADO-RS)
    case dicom = "application/dicom"
    
    /// DICOM JSON metadata
    case dicomJSON = "application/dicom+json"
    
    /// DICOM XML metadata
    case dicomXML = "application/dicom+xml"
    
    // MARK: - Multipart Media Types
    
    /// Multipart related (for batch responses)
    case multipartRelated = "multipart/related"
    
    // MARK: - Image Media Types
    
    /// JPEG image
    case jpeg = "image/jpeg"
    
    /// PNG image
    case png = "image/png"
    
    /// GIF image
    case gif = "image/gif"
    
    /// JP2 image (JPEG 2000)
    case jp2 = "image/jp2"
    
    /// JPEG-LS image
    case jpegls = "image/jls"
    
    /// JPEG-XL image
    case jpegxl = "image/jxl"
    
    // MARK: - Video Media Types
    
    /// MPEG video
    case mpeg = "video/mpeg"
    
    /// MP4 video
    case mp4 = "video/mp4"
    
    /// H.265/HEVC video
    case h265 = "video/h265"
    
    // MARK: - Other Media Types
    
    /// Octet stream (raw binary data)
    case octetStream = "application/octet-stream"
    
    /// PDF document
    case pdf = "application/pdf"
    
    /// JSON
    case json = "application/json"
    
    /// Returns the media type string with optional parameters
    /// - Parameter parameters: Optional parameters (e.g., transfer-syntax)
    /// - Returns: Media type string with parameters
    public func withParameters(_ parameters: [String: String]) -> String {
        guard !parameters.isEmpty else { return rawValue }
        let paramString = parameters.map { "\($0.key)=\"\($0.value)\"" }.joined(separator: "; ")
        return "\(rawValue); \(paramString)"
    }
}

// MARK: - Request Options

/// Options for WADO-RS requests
public struct WADORequestOptions: Sendable {
    
    /// Requested media types in order of preference
    public let acceptMediaTypes: [DICOMWebMediaType]
    
    /// Requested transfer syntax UIDs
    public let transferSyntaxUIDs: [String]
    
    /// Whether to include private tags
    public let includePrivateTags: Bool
    
    /// Quality for lossy compression (0-100)
    public let quality: Int?
    
    /// Viewport for rendered images
    public let viewport: Viewport?
    
    /// Window center for rendered images
    public let windowCenter: Double?
    
    /// Window width for rendered images
    public let windowWidth: Double?
    
    /// Creates WADO request options
    public init(
        acceptMediaTypes: [DICOMWebMediaType] = [.dicom],
        transferSyntaxUIDs: [String] = [],
        includePrivateTags: Bool = true,
        quality: Int? = nil,
        viewport: Viewport? = nil,
        windowCenter: Double? = nil,
        windowWidth: Double? = nil
    ) {
        self.acceptMediaTypes = acceptMediaTypes
        self.transferSyntaxUIDs = transferSyntaxUIDs
        self.includePrivateTags = includePrivateTags
        self.quality = quality
        self.viewport = viewport
        self.windowCenter = windowCenter
        self.windowWidth = windowWidth
    }
    
    /// Default options for DICOM retrieval
    public static let `default` = WADORequestOptions()
    
    /// Options for metadata-only retrieval
    public static let metadataOnly = WADORequestOptions(acceptMediaTypes: [.dicomJSON])
    
    /// Options for rendered JPEG retrieval
    public static let rendered = WADORequestOptions(acceptMediaTypes: [.jpeg])
}

/// Viewport specification for rendered images
public struct Viewport: Sendable, Equatable {
    public let width: Int
    public let height: Int
    
    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }
}

/// Options for QIDO-RS search requests
public struct QIDORequestOptions: Sendable {
    
    /// Maximum number of results to return
    public let limit: Int?
    
    /// Offset for pagination
    public let offset: Int?
    
    /// Fields to include in the response
    public let includeFields: [Tag]
    
    /// Whether to perform fuzzy matching
    public let fuzzyMatching: Bool
    
    /// Creates QIDO request options
    public init(
        limit: Int? = nil,
        offset: Int? = nil,
        includeFields: [Tag] = [],
        fuzzyMatching: Bool = false
    ) {
        self.limit = limit
        self.offset = offset
        self.includeFields = includeFields
        self.fuzzyMatching = fuzzyMatching
    }
    
    /// Default options
    public static let `default` = QIDORequestOptions()
}

/// Options for STOW-RS store requests
public struct STOWRequestOptions: Sendable {
    
    /// Whether to allow coercion of conflicts
    public let allowCoercion: Bool
    
    /// Study instance UID to store into (optional)
    public let studyInstanceUID: String?
    
    /// Creates STOW request options
    public init(
        allowCoercion: Bool = false,
        studyInstanceUID: String? = nil
    ) {
        self.allowCoercion = allowCoercion
        self.studyInstanceUID = studyInstanceUID
    }
    
    /// Default options
    public static let `default` = STOWRequestOptions()
}
