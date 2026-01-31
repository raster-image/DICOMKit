import Foundation

/// Errors that can occur during DICOMweb operations
///
/// Reference: DICOM PS3.18 Section 8.6 - Response Messages
public enum DICOMWebError: Error, Sendable, Equatable {
    
    // MARK: - Connection Errors
    
    /// Failed to establish connection to the server
    case connectionFailed(String)
    
    /// The request timed out
    case timeout
    
    /// SSL/TLS certificate validation failed
    case certificateError(String)
    
    // MARK: - HTTP Errors
    
    /// HTTP error with status code
    case httpError(statusCode: Int, message: String)
    
    /// Bad request (400)
    case badRequest(String)
    
    /// Unauthorized (401)
    case unauthorized
    
    /// Forbidden (403)
    case forbidden
    
    /// Resource not found (404)
    case notFound
    
    /// Method not allowed (405)
    case methodNotAllowed
    
    /// Conflict (409)
    case conflict(String)
    
    /// Unsupported media type (415)
    case unsupportedMediaType(String)
    
    /// Unprocessable entity (422)
    case unprocessableEntity(String)
    
    /// Service unavailable (503)
    case serviceUnavailable
    
    // MARK: - Request Errors
    
    /// Invalid URL
    case invalidURL(String)
    
    /// Invalid request parameters
    case invalidParameters(String)
    
    /// Missing required parameter
    case missingParameter(String)
    
    /// Invalid UID format
    case invalidUID(String)
    
    // MARK: - Response Errors
    
    /// Failed to parse response
    case parseError(String)
    
    /// Invalid multipart response
    case invalidMultipartResponse(String)
    
    /// Missing boundary in multipart response
    case missingBoundary
    
    /// Invalid JSON response
    case invalidJSON(String)
    
    /// Unexpected response content type
    case unexpectedContentType(String)
    
    // MARK: - Authentication Errors
    
    /// Authentication required but not provided
    case authenticationRequired
    
    /// OAuth token expired
    case tokenExpired
    
    /// OAuth token refresh failed
    case tokenRefreshFailed(String)
    
    /// Invalid OAuth configuration
    case invalidOAuthConfiguration(String)
    
    // MARK: - STOW-RS Errors
    
    /// All instances failed to store
    case storeAllFailed(String)
    
    /// Some instances failed to store
    case storePartialFailure(stored: Int, failed: Int)
    
    /// Instance already exists
    case instanceAlreadyExists(sopInstanceUID: String)
    
    // MARK: - UPS-RS Errors
    
    /// Workitem not found
    case workitemNotFound(String)
    
    /// Invalid workitem state transition
    case invalidStateTransition(from: String, to: String)
    
    /// Workitem is locked by another user
    case workitemLocked(String)
    
    /// Subscription failed
    case subscriptionFailed(String)
    
    // MARK: - General Errors
    
    /// Operation cancelled
    case cancelled
    
    /// Internal error
    case internalError(String)
}

// MARK: - LocalizedError Conformance

extension DICOMWebError: LocalizedError {
    
    public var errorDescription: String? {
        switch self {
        case .connectionFailed(let message):
            return "Connection failed: \(message)"
        case .timeout:
            return "Request timed out"
        case .certificateError(let message):
            return "Certificate error: \(message)"
            
        case .httpError(let statusCode, let message):
            return "HTTP error \(statusCode): \(message)"
        case .badRequest(let message):
            return "Bad request: \(message)"
        case .unauthorized:
            return "Unauthorized - authentication required"
        case .forbidden:
            return "Access forbidden"
        case .notFound:
            return "Resource not found"
        case .methodNotAllowed:
            return "HTTP method not allowed"
        case .conflict(let message):
            return "Conflict: \(message)"
        case .unsupportedMediaType(let message):
            return "Unsupported media type: \(message)"
        case .unprocessableEntity(let message):
            return "Unprocessable entity: \(message)"
        case .serviceUnavailable:
            return "Service unavailable"
            
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        case .invalidParameters(let message):
            return "Invalid parameters: \(message)"
        case .missingParameter(let parameter):
            return "Missing required parameter: \(parameter)"
        case .invalidUID(let uid):
            return "Invalid DICOM UID: \(uid)"
            
        case .parseError(let message):
            return "Parse error: \(message)"
        case .invalidMultipartResponse(let message):
            return "Invalid multipart response: \(message)"
        case .missingBoundary:
            return "Missing boundary in multipart response"
        case .invalidJSON(let message):
            return "Invalid JSON: \(message)"
        case .unexpectedContentType(let contentType):
            return "Unexpected content type: \(contentType)"
            
        case .authenticationRequired:
            return "Authentication required"
        case .tokenExpired:
            return "Authentication token expired"
        case .tokenRefreshFailed(let message):
            return "Token refresh failed: \(message)"
        case .invalidOAuthConfiguration(let message):
            return "Invalid OAuth configuration: \(message)"
            
        case .storeAllFailed(let message):
            return "All instances failed to store: \(message)"
        case .storePartialFailure(let stored, let failed):
            return "Partial store failure: \(stored) stored, \(failed) failed"
        case .instanceAlreadyExists(let uid):
            return "Instance already exists: \(uid)"
            
        case .workitemNotFound(let uid):
            return "Workitem not found: \(uid)"
        case .invalidStateTransition(let from, let to):
            return "Invalid state transition from \(from) to \(to)"
        case .workitemLocked(let uid):
            return "Workitem locked: \(uid)"
        case .subscriptionFailed(let message):
            return "Subscription failed: \(message)"
            
        case .cancelled:
            return "Operation cancelled"
        case .internalError(let message):
            return "Internal error: \(message)"
        }
    }
}

// MARK: - HTTP Status Code Mapping

extension DICOMWebError {
    
    /// Creates a DICOMWebError from an HTTP status code
    /// - Parameters:
    ///   - statusCode: The HTTP status code
    ///   - message: Optional error message
    /// - Returns: The appropriate DICOMWebError
    public static func fromHTTPStatus(_ statusCode: Int, message: String = "") -> DICOMWebError {
        switch statusCode {
        case 400:
            return .badRequest(message)
        case 401:
            return .unauthorized
        case 403:
            return .forbidden
        case 404:
            return .notFound
        case 405:
            return .methodNotAllowed
        case 409:
            return .conflict(message)
        case 415:
            return .unsupportedMediaType(message)
        case 422:
            return .unprocessableEntity(message)
        case 503:
            return .serviceUnavailable
        default:
            return .httpError(statusCode: statusCode, message: message)
        }
    }
}
