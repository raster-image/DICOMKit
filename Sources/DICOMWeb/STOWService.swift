import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// STOW-RS (Store Over the Web - RESTful Services)
///
/// Provides methods for storing DICOM objects over HTTP.
///
/// Reference: DICOM PS3.18 Section 10.5 - STOW-RS
public final class STOWService: @unchecked Sendable {
    
    private let client: HTTPClient
    
    init(client: HTTPClient) {
        self.client = client
    }
    
    // MARK: - Store Instances
    
    /// Stores one or more DICOM instances
    /// - Parameters:
    ///   - instances: Array of DICOM instance data to store
    ///   - studyInstanceUID: Optional Study Instance UID to store into
    /// - Returns: Store result with success and failure information
    public func store(
        instances: [Data],
        studyInstanceUID: String? = nil
    ) async throws -> STOWResult {
        let handler = MultipartHandler()
        let body = handler.encode(instances: instances)
        
        let path: String
        if let studyInstanceUID = studyInstanceUID {
            path = "studies/\(studyInstanceUID)"
        } else {
            path = "studies"
        }
        
        let (data, response) = try await client.post(
            path: path,
            body: body,
            contentType: handler.contentType,
            accept: DICOMWebMediaType.dicomJSON.rawValue
        )
        
        // Parse the response
        return try parseStoreResponse(data: data, response: response)
    }
    
    /// Stores a single DICOM instance
    /// - Parameters:
    ///   - instance: The DICOM instance data to store
    ///   - studyInstanceUID: Optional Study Instance UID to store into
    /// - Returns: Store result
    public func storeInstance(
        _ instance: Data,
        studyInstanceUID: String? = nil
    ) async throws -> STOWResult {
        try await store(instances: [instance], studyInstanceUID: studyInstanceUID)
    }
    
    /// Stores DICOM instances with metadata
    /// - Parameters:
    ///   - instancesWithMetadata: Array of tuples containing instance data and metadata
    ///   - studyInstanceUID: Optional Study Instance UID to store into
    /// - Returns: Store result
    public func storeWithMetadata(
        _ instancesWithMetadata: [(data: Data, metadata: [String: Any])],
        studyInstanceUID: String? = nil
    ) async throws -> STOWResult {
        let handler = MultipartHandler()
        
        var parts: [MultipartPart] = []
        for (instanceData, metadata) in instancesWithMetadata {
            // Add metadata part
            if let metadataData = try? JSONSerialization.data(withJSONObject: metadata, options: []) {
                parts.append(MultipartPart(
                    data: metadataData,
                    contentType: .dicomJSON,
                    additionalHeaders: ["Content-ID": UUID().uuidString]
                ))
            }
            
            // Add DICOM data part
            parts.append(MultipartPart(
                data: instanceData,
                contentType: .dicom,
                additionalHeaders: ["Content-ID": UUID().uuidString]
            ))
        }
        
        let body = handler.encode(parts: parts)
        
        let path: String
        if let studyInstanceUID = studyInstanceUID {
            path = "studies/\(studyInstanceUID)"
        } else {
            path = "studies"
        }
        
        let (data, response) = try await client.post(
            path: path,
            body: body,
            contentType: handler.contentType,
            accept: DICOMWebMediaType.dicomJSON.rawValue
        )
        
        return try parseStoreResponse(data: data, response: response)
    }
    
    // MARK: - Helper Methods
    
    private func parseStoreResponse(data: Data, response: HTTPURLResponse) throws -> STOWResult {
        // Check HTTP status
        switch response.statusCode {
        case 200:
            // All instances stored successfully
            return try parseSuccessResponse(data: data)
        case 202:
            // Warning - some instances may have failed
            return try parsePartialResponse(data: data)
        case 409:
            // Conflict - instance already exists
            let message = String(data: data, encoding: .utf8) ?? "Unknown conflict"
            throw DICOMWebError.conflict(message)
        default:
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw DICOMWebError.fromHTTPStatus(response.statusCode, message: message)
        }
    }
    
    private func parseSuccessResponse(data: Data) throws -> STOWResult {
        // Parse the JSON response
        guard let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            // If no parseable response, assume success
            return STOWResult(
                successfulInstances: [],
                failedInstances: [],
                warnings: []
            )
        }
        
        var successfulInstances: [STOWInstanceResult] = []
        
        // Parse Referenced SOP Sequence
        if let referencedSequence = json["00081199"] as? [String: Any],
           let values = referencedSequence["Value"] as? [[String: Any]] {
            for item in values {
                let result = parseInstanceResult(from: item)
                successfulInstances.append(result)
            }
        }
        
        return STOWResult(
            successfulInstances: successfulInstances,
            failedInstances: [],
            warnings: []
        )
    }
    
    private func parsePartialResponse(data: Data) throws -> STOWResult {
        guard let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            return STOWResult(
                successfulInstances: [],
                failedInstances: [],
                warnings: ["Failed to parse response"]
            )
        }
        
        var successfulInstances: [STOWInstanceResult] = []
        var failedInstances: [STOWFailedInstance] = []
        var warnings: [String] = []
        
        // Parse Referenced SOP Sequence (successful instances)
        if let referencedSequence = json["00081199"] as? [String: Any],
           let values = referencedSequence["Value"] as? [[String: Any]] {
            for item in values {
                let result = parseInstanceResult(from: item)
                successfulInstances.append(result)
            }
        }
        
        // Parse Failed SOP Sequence
        if let failedSequence = json["00081198"] as? [String: Any],
           let values = failedSequence["Value"] as? [[String: Any]] {
            for item in values {
                let failed = parseFailedInstance(from: item)
                failedInstances.append(failed)
            }
        }
        
        // Parse any warning messages
        if let warningReason = json["00081196"] as? [String: Any],
           let values = warningReason["Value"] as? [String] {
            warnings = values
        }
        
        return STOWResult(
            successfulInstances: successfulInstances,
            failedInstances: failedInstances,
            warnings: warnings
        )
    }
    
    private func parseInstanceResult(from item: [String: Any]) -> STOWInstanceResult {
        var sopClassUID: String?
        var sopInstanceUID: String?
        var retrieveURL: String?
        
        // SOP Class UID (0008,1150)
        if let sopClass = item["00081150"] as? [String: Any],
           let values = sopClass["Value"] as? [String],
           let first = values.first {
            sopClassUID = first
        }
        
        // SOP Instance UID (0008,1155)
        if let sopInstance = item["00081155"] as? [String: Any],
           let values = sopInstance["Value"] as? [String],
           let first = values.first {
            sopInstanceUID = first
        }
        
        // Retrieve URL (0008,1190)
        if let retrieve = item["00081190"] as? [String: Any],
           let values = retrieve["Value"] as? [String],
           let first = values.first {
            retrieveURL = first
        }
        
        return STOWInstanceResult(
            sopClassUID: sopClassUID ?? "",
            sopInstanceUID: sopInstanceUID ?? "",
            retrieveURL: retrieveURL
        )
    }
    
    private func parseFailedInstance(from item: [String: Any]) -> STOWFailedInstance {
        var sopClassUID: String?
        var sopInstanceUID: String?
        var failureReason: UInt16?
        
        // SOP Class UID (0008,1150)
        if let sopClass = item["00081150"] as? [String: Any],
           let values = sopClass["Value"] as? [String],
           let first = values.first {
            sopClassUID = first
        }
        
        // SOP Instance UID (0008,1155)
        if let sopInstance = item["00081155"] as? [String: Any],
           let values = sopInstance["Value"] as? [String],
           let first = values.first {
            sopInstanceUID = first
        }
        
        // Failure Reason (0008,1197)
        if let failure = item["00081197"] as? [String: Any],
           let values = failure["Value"] as? [Int],
           let first = values.first {
            failureReason = UInt16(first)
        }
        
        return STOWFailedInstance(
            sopClassUID: sopClassUID ?? "",
            sopInstanceUID: sopInstanceUID ?? "",
            failureReason: failureReason ?? 0
        )
    }
}

// MARK: - Result Types

/// Result from a STOW-RS store operation
public struct STOWResult: Sendable, Equatable {
    /// Successfully stored instances
    public let successfulInstances: [STOWInstanceResult]
    
    /// Failed instances
    public let failedInstances: [STOWFailedInstance]
    
    /// Warning messages
    public let warnings: [String]
    
    /// Whether all instances were stored successfully
    public var isSuccess: Bool {
        failedInstances.isEmpty
    }
    
    /// Whether some instances failed
    public var hasPartialFailure: Bool {
        !failedInstances.isEmpty && !successfulInstances.isEmpty
    }
    
    public init(
        successfulInstances: [STOWInstanceResult],
        failedInstances: [STOWFailedInstance],
        warnings: [String]
    ) {
        self.successfulInstances = successfulInstances
        self.failedInstances = failedInstances
        self.warnings = warnings
    }
}

/// Information about a successfully stored instance
public struct STOWInstanceResult: Sendable, Equatable {
    /// The SOP Class UID
    public let sopClassUID: String
    
    /// The SOP Instance UID
    public let sopInstanceUID: String
    
    /// The retrieve URL for the stored instance
    public let retrieveURL: String?
    
    public init(
        sopClassUID: String,
        sopInstanceUID: String,
        retrieveURL: String? = nil
    ) {
        self.sopClassUID = sopClassUID
        self.sopInstanceUID = sopInstanceUID
        self.retrieveURL = retrieveURL
    }
}

/// Information about a failed instance
public struct STOWFailedInstance: Sendable, Equatable {
    /// The SOP Class UID
    public let sopClassUID: String
    
    /// The SOP Instance UID
    public let sopInstanceUID: String
    
    /// The failure reason code
    public let failureReason: UInt16
    
    /// Human-readable failure reason
    public var failureReasonDescription: String {
        STOWFailureReason(rawValue: failureReason)?.description ?? "Unknown failure (\(failureReason))"
    }
    
    public init(
        sopClassUID: String,
        sopInstanceUID: String,
        failureReason: UInt16
    ) {
        self.sopClassUID = sopClassUID
        self.sopInstanceUID = sopInstanceUID
        self.failureReason = failureReason
    }
}

/// STOW-RS failure reason codes
///
/// Reference: DICOM PS3.4 Table CC.2.3-1
public enum STOWFailureReason: UInt16, Sendable {
    case processingFailure = 0x0110
    case duplicateSOPInstance = 0x0111
    case noSuchAttribute = 0x0105
    case invalidAttributeValue = 0x0106
    case missingAttribute = 0x0120
    case missingAttributeValue = 0x0121
    case storageCommitmentFailed = 0x0122
    case outOfResources = 0xA700
    case dataSetDoesNotMatchSOPClass = 0xA900
    case cannotUnderstand = 0xC000
    
    public var description: String {
        switch self {
        case .processingFailure:
            return "Processing failure"
        case .duplicateSOPInstance:
            return "Duplicate SOP instance"
        case .noSuchAttribute:
            return "No such attribute"
        case .invalidAttributeValue:
            return "Invalid attribute value"
        case .missingAttribute:
            return "Missing attribute"
        case .missingAttributeValue:
            return "Missing attribute value"
        case .storageCommitmentFailed:
            return "Storage commitment failed"
        case .outOfResources:
            return "Out of resources"
        case .dataSetDoesNotMatchSOPClass:
            return "Data set does not match SOP class"
        case .cannotUnderstand:
            return "Cannot understand"
        }
    }
}
