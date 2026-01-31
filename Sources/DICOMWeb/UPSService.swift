import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// UPS-RS (Unified Procedure Step - RESTful Services)
///
/// Provides methods for managing worklist items (workitems) using
/// the Unified Procedure Step service over HTTP.
///
/// Reference: DICOM PS3.18 Section 11 - UPS-RS
public final class UPSService: @unchecked Sendable {
    
    private let client: HTTPClient
    
    init(client: HTTPClient) {
        self.client = client
    }
    
    // MARK: - Workitem Creation
    
    /// Creates a new workitem
    /// - Parameters:
    ///   - workitem: The workitem to create
    ///   - workitemUID: Optional UID for the workitem (auto-generated if not provided)
    /// - Returns: The created workitem UID
    public func createWorkitem(
        _ workitem: UPSWorkitem,
        workitemUID: String? = nil
    ) async throws -> String {
        let encoder = DICOMJSONEncoder()
        var elements: [[String: Any]] = []
        
        // Required attributes
        elements.append(encoder.element(tag: .scheduledProcedureStepStatus, vr: .CS, value: workitem.status.rawValue))
        
        // Optional attributes
        if let label = workitem.procedureStepLabel {
            elements.append(encoder.element(tag: .procedureStepLabel, vr: .LO, value: label))
        }
        if let worklistLabel = workitem.worklistLabel {
            elements.append(encoder.element(tag: .worklistLabel, vr: .LO, value: worklistLabel))
        }
        if let priority = workitem.scheduledProcedureStepPriority {
            elements.append(encoder.element(tag: .scheduledProcedureStepPriority, vr: .CS, value: priority.rawValue))
        }
        if let stationName = workitem.scheduledStationName {
            elements.append(encoder.element(tag: .scheduledStationName, vr: .SH, value: stationName))
        }
        if let stationClassCode = workitem.scheduledStationClassCode {
            elements.append(encoder.element(tag: .scheduledStationClassCodeSequence, vr: .SQ, value: stationClassCode))
        }
        if let startDateTime = workitem.scheduledProcedureStepStartDateTime {
            elements.append(encoder.element(tag: .scheduledProcedureStepStartDateTime, vr: .DT, value: startDateTime))
        }
        if let modificationDateTime = workitem.scheduledProcedureStepModificationDateTime {
            elements.append(encoder.element(tag: .scheduledProcedureStepModificationDateTime, vr: .DT, value: modificationDateTime))
        }
        
        // Patient information
        if let patientName = workitem.patientName {
            elements.append(encoder.element(tag: .patientName, vr: .PN, value: patientName))
        }
        if let patientID = workitem.patientID {
            elements.append(encoder.element(tag: .patientID, vr: .LO, value: patientID))
        }
        
        let body = try encoder.encode(elements: elements)
        
        let path = "workitems"
        var queryItems: [URLQueryItem] = []
        
        if let uid = workitemUID {
            queryItems.append(URLQueryItem(name: "workitem", value: uid))
        }
        
        let (data, response) = try await client.post(
            path: path,
            queryItems: queryItems,
            body: body,
            contentType: DICOMWebMediaType.dicomJSON.rawValue,
            accept: DICOMWebMediaType.dicomJSON.rawValue
        )
        
        // Extract workitem UID from response
        if let location = response.value(forHTTPHeaderField: "Content-Location"),
           let uid = extractWorkitemUID(from: location) {
            return uid
        }
        
        // Try to extract from response body
        if let json = try? DICOMJSONModel(data: data),
           let uid = json.string(for: .affectedSOPInstanceUID) {
            return uid
        }
        
        // Use provided UID if available
        if let uid = workitemUID {
            return uid
        }
        
        throw DICOMWebError.parseError("Could not determine workitem UID")
    }
    
    // MARK: - Workitem Retrieval
    
    /// Retrieves a workitem by UID
    /// - Parameter workitemUID: The workitem UID
    /// - Returns: The workitem data
    public func getWorkitem(workitemUID: String) async throws -> UPSWorkitem {
        let path = "workitems/\(workitemUID)"
        
        let (data, _) = try await client.get(
            path: path,
            accept: DICOMWebMediaType.dicomJSON.rawValue
        )
        
        let json = try DICOMJSONModel(data: data)
        return parseWorkitem(from: json)
    }
    
    /// Searches for workitems matching criteria
    /// - Parameters:
    ///   - status: Filter by status
    ///   - patientID: Filter by patient ID
    ///   - patientName: Filter by patient name
    ///   - scheduledStationName: Filter by station name
    ///   - limit: Maximum results to return
    ///   - offset: Offset for pagination
    /// - Returns: Array of matching workitems
    public func searchWorkitems(
        status: UPSStatus? = nil,
        patientID: String? = nil,
        patientName: String? = nil,
        scheduledStationName: String? = nil,
        limit: Int? = nil,
        offset: Int? = nil
    ) async throws -> [UPSWorkitem] {
        var queryItems: [URLQueryItem] = []
        
        if let status = status {
            queryItems.append(URLQueryItem(name: "ScheduledProcedureStepStatus", value: status.rawValue))
        }
        if let patientID = patientID {
            queryItems.append(URLQueryItem(name: "PatientID", value: patientID))
        }
        if let patientName = patientName {
            queryItems.append(URLQueryItem(name: "PatientName", value: patientName))
        }
        if let scheduledStationName = scheduledStationName {
            queryItems.append(URLQueryItem(name: "ScheduledStationName", value: scheduledStationName))
        }
        if let limit = limit {
            queryItems.append(URLQueryItem(name: "limit", value: String(limit)))
        }
        if let offset = offset {
            queryItems.append(URLQueryItem(name: "offset", value: String(offset)))
        }
        
        let (data, _) = try await client.get(
            path: "workitems",
            queryItems: queryItems,
            accept: DICOMWebMediaType.dicomJSON.rawValue
        )
        
        let json = try DICOMJSONModel(data: data)
        
        var workitems: [UPSWorkitem] = []
        for i in 0..<json.count {
            // Create a single-item model for each result
            let itemData = try JSONSerialization.data(withJSONObject: [json.jsonObject[i]], options: [])
            let itemJson = try DICOMJSONModel(data: itemData)
            workitems.append(parseWorkitem(from: itemJson))
        }
        
        return workitems
    }
    
    // MARK: - Workitem State Management
    
    /// Changes the state of a workitem
    /// - Parameters:
    ///   - workitemUID: The workitem UID
    ///   - newState: The new state
    ///   - transactionUID: Transaction UID for locking (required for some transitions)
    public func changeState(
        workitemUID: String,
        newState: UPSStatus,
        transactionUID: String? = nil
    ) async throws {
        let encoder = DICOMJSONEncoder()
        var elements: [[String: Any]] = []
        
        elements.append(encoder.element(tag: .procedureStepState, vr: .CS, value: newState.rawValue))
        
        if let transactionUID = transactionUID {
            elements.append(encoder.element(tag: .transactionUID, vr: .UI, value: transactionUID))
        }
        
        let body = try encoder.encode(elements: elements)
        
        let path = "workitems/\(workitemUID)/state"
        
        let (_, _) = try await client.put(
            path: path,
            body: body,
            contentType: DICOMWebMediaType.dicomJSON.rawValue,
            accept: DICOMWebMediaType.dicomJSON.rawValue
        )
    }
    
    /// Claims a workitem (transitions from SCHEDULED to IN PROGRESS)
    /// - Parameter workitemUID: The workitem UID
    /// - Returns: The transaction UID for the claim
    public func claimWorkitem(workitemUID: String) async throws -> String {
        let transactionUID = generateUID()
        
        try await changeState(
            workitemUID: workitemUID,
            newState: .inProgress,
            transactionUID: transactionUID
        )
        
        return transactionUID
    }
    
    /// Completes a workitem
    /// - Parameters:
    ///   - workitemUID: The workitem UID
    ///   - transactionUID: The transaction UID from claiming
    public func completeWorkitem(
        workitemUID: String,
        transactionUID: String
    ) async throws {
        try await changeState(
            workitemUID: workitemUID,
            newState: .completed,
            transactionUID: transactionUID
        )
    }
    
    /// Cancels a workitem
    /// - Parameters:
    ///   - workitemUID: The workitem UID
    ///   - reason: Optional cancellation reason
    public func cancelWorkitem(
        workitemUID: String,
        reason: String? = nil
    ) async throws {
        let encoder = DICOMJSONEncoder()
        var elements: [[String: Any]] = []
        
        elements.append(encoder.element(tag: .procedureStepState, vr: .CS, value: UPSStatus.canceled.rawValue))
        
        if let reasonText = reason {
            elements.append(encoder.element(tag: .procedureStepCancellationDateTime, vr: .DT, value: currentDateTime()))
            // Add reason code using a simple reason code element
            // Note: Full implementation would use a Procedure Step Discontinuation Reason Code Sequence
            // For now, we store it as a comment attribute
            elements.append(encoder.element(tag: Tag(group: 0x0040, element: 0x0310), vr: .SH, value: reasonText))
        }
        
        let body = try encoder.encode(elements: elements)
        
        let path = "workitems/\(workitemUID)/cancelrequest"
        
        let (_, _) = try await client.post(
            path: path,
            body: body,
            contentType: DICOMWebMediaType.dicomJSON.rawValue,
            accept: DICOMWebMediaType.dicomJSON.rawValue
        )
    }
    
    // MARK: - Subscription
    
    /// Subscribes to workitem events
    /// - Parameters:
    ///   - workitemUID: Optional specific workitem UID (nil for all workitems)
    ///   - deletionLock: Whether to apply deletion lock
    /// - Returns: Subscription UID
    public func subscribe(
        workitemUID: String? = nil,
        deletionLock: Bool = false
    ) async throws -> String {
        var path = "workitems"
        if let workitemUID = workitemUID {
            path += "/\(workitemUID)"
        }
        path += "/subscribers"
        
        var queryItems: [URLQueryItem] = []
        if deletionLock {
            queryItems.append(URLQueryItem(name: "deletionlock", value: "true"))
        }
        
        let (_, response) = try await client.post(
            path: path,
            queryItems: queryItems,
            body: Data(),
            contentType: DICOMWebMediaType.dicomJSON.rawValue,
            accept: DICOMWebMediaType.dicomJSON.rawValue
        )
        
        // Extract subscription UID from response
        if let location = response.value(forHTTPHeaderField: "Content-Location"),
           let uid = extractSubscriptionUID(from: location) {
            return uid
        }
        
        throw DICOMWebError.subscriptionFailed("Could not determine subscription UID")
    }
    
    /// Unsubscribes from workitem events
    /// - Parameters:
    ///   - subscriptionUID: The subscription UID
    ///   - workitemUID: Optional specific workitem UID
    public func unsubscribe(
        subscriptionUID: String,
        workitemUID: String? = nil
    ) async throws {
        var path = "workitems"
        if let workitemUID = workitemUID {
            path += "/\(workitemUID)"
        }
        path += "/subscribers/\(subscriptionUID)"
        
        let (_, _) = try await client.delete(path: path)
    }
    
    /// Suspends a subscription
    /// - Parameter subscriptionUID: The subscription UID
    public func suspendSubscription(subscriptionUID: String) async throws {
        let path = "workitems/subscribers/\(subscriptionUID)/suspend"
        
        let (_, _) = try await client.post(
            path: path,
            body: Data(),
            contentType: DICOMWebMediaType.dicomJSON.rawValue,
            accept: DICOMWebMediaType.dicomJSON.rawValue
        )
    }
    
    // MARK: - Helper Methods
    
    private func parseWorkitem(from json: DICOMJSONModel) -> UPSWorkitem {
        let statusString = json.string(for: .scheduledProcedureStepStatus) ?? ""
        let status = UPSStatus(rawValue: statusString) ?? .scheduled
        
        let priorityString = json.string(for: .scheduledProcedureStepPriority)
        let priority = priorityString.flatMap { UPSPriority(rawValue: $0) }
        
        return UPSWorkitem(
            workitemUID: json.string(for: .affectedSOPInstanceUID),
            status: status,
            procedureStepLabel: json.string(for: .procedureStepLabel),
            worklistLabel: json.string(for: .worklistLabel),
            scheduledProcedureStepPriority: priority,
            scheduledStationName: json.string(for: .scheduledStationName),
            scheduledStationClassCode: nil,
            scheduledProcedureStepStartDateTime: json.string(for: .scheduledProcedureStepStartDateTime),
            scheduledProcedureStepModificationDateTime: json.string(for: .scheduledProcedureStepModificationDateTime),
            patientName: json.string(for: .patientName),
            patientID: json.string(for: .patientID)
        )
    }
    
    private func extractWorkitemUID(from location: String) -> String? {
        // Extract UID from URL like /workitems/1.2.3.4.5
        let components = location.components(separatedBy: "/")
        return components.last
    }
    
    private func extractSubscriptionUID(from location: String) -> String? {
        // Extract UID from URL like /workitems/subscribers/1.2.3.4.5
        let components = location.components(separatedBy: "/")
        return components.last
    }
    
    private func generateUID() -> String {
        // Simple UID generation based on timestamp and random component
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        let random = Int.random(in: 1000...9999)
        return "2.25.\(timestamp).\(random)"
    }
    
    private func currentDateTime() -> String {
        let formatter = DateFormatter()
        // DICOM DT format: YYYYMMDDHHMMSS.FFFFFF
        // Note: Swift DateFormatter supports up to 3 fractional second digits (SSS)
        // Using SSS to get millisecond precision, which is sufficient for most use cases
        formatter.dateFormat = "yyyyMMddHHmmss.SSS"
        formatter.timeZone = TimeZone(identifier: "UTC")
        let dateString = formatter.string(from: Date())
        // Pad to 6 decimal places for DICOM compliance
        return dateString + "000"
    }
}

// MARK: - UPS Types

/// Represents a Unified Procedure Step workitem
public struct UPSWorkitem: Sendable, Equatable {
    /// The workitem UID
    public let workitemUID: String?
    
    /// Current status of the workitem
    public let status: UPSStatus
    
    /// Label for the procedure step
    public let procedureStepLabel: String?
    
    /// Label for the worklist
    public let worklistLabel: String?
    
    /// Priority of the procedure step
    public let scheduledProcedureStepPriority: UPSPriority?
    
    /// Scheduled station name
    public let scheduledStationName: String?
    
    /// Scheduled station class code
    public let scheduledStationClassCode: String?
    
    /// Scheduled start date/time
    public let scheduledProcedureStepStartDateTime: String?
    
    /// Modification date/time
    public let scheduledProcedureStepModificationDateTime: String?
    
    /// Patient name
    public let patientName: String?
    
    /// Patient ID
    public let patientID: String?
    
    public init(
        workitemUID: String? = nil,
        status: UPSStatus = .scheduled,
        procedureStepLabel: String? = nil,
        worklistLabel: String? = nil,
        scheduledProcedureStepPriority: UPSPriority? = nil,
        scheduledStationName: String? = nil,
        scheduledStationClassCode: String? = nil,
        scheduledProcedureStepStartDateTime: String? = nil,
        scheduledProcedureStepModificationDateTime: String? = nil,
        patientName: String? = nil,
        patientID: String? = nil
    ) {
        self.workitemUID = workitemUID
        self.status = status
        self.procedureStepLabel = procedureStepLabel
        self.worklistLabel = worklistLabel
        self.scheduledProcedureStepPriority = scheduledProcedureStepPriority
        self.scheduledStationName = scheduledStationName
        self.scheduledStationClassCode = scheduledStationClassCode
        self.scheduledProcedureStepStartDateTime = scheduledProcedureStepStartDateTime
        self.scheduledProcedureStepModificationDateTime = scheduledProcedureStepModificationDateTime
        self.patientName = patientName
        self.patientID = patientID
    }
}

/// UPS procedure step status values
///
/// Reference: DICOM PS3.4 Table CC.1.1-1
public enum UPSStatus: String, Sendable {
    case scheduled = "SCHEDULED"
    case inProgress = "IN PROGRESS"
    case completed = "COMPLETED"
    case canceled = "CANCELED"
}

/// UPS priority values
///
/// Reference: DICOM PS3.4 Table CC.1.1-1
public enum UPSPriority: String, Sendable {
    case low = "LOW"
    case medium = "MEDIUM"
    case high = "HIGH"
}

// MARK: - Tag Extensions for UPS

extension Tag {
    /// Scheduled Procedure Step Status (0074,1000)
    static let scheduledProcedureStepStatus = Tag(group: 0x0074, element: 0x1000)
    
    /// Procedure Step State (0074,1000) - alias
    static let procedureStepState = Tag(group: 0x0074, element: 0x1000)
    
    /// Procedure Step Label (0074,1204)
    static let procedureStepLabel = Tag(group: 0x0074, element: 0x1204)
    
    /// Worklist Label (0074,1202)
    static let worklistLabel = Tag(group: 0x0074, element: 0x1202)
    
    /// Scheduled Procedure Step Priority (0074,1200)
    static let scheduledProcedureStepPriority = Tag(group: 0x0074, element: 0x1200)
    
    /// Scheduled Station Name (0040,0010)
    static let scheduledStationName = Tag(group: 0x0040, element: 0x0010)
    
    /// Scheduled Station Class Code Sequence (0040,4026)
    static let scheduledStationClassCodeSequence = Tag(group: 0x0040, element: 0x4026)
    
    /// Scheduled Procedure Step Start DateTime (0040,4005)
    static let scheduledProcedureStepStartDateTime = Tag(group: 0x0040, element: 0x4005)
    
    /// Scheduled Procedure Step Modification DateTime (0040,4010)
    static let scheduledProcedureStepModificationDateTime = Tag(group: 0x0040, element: 0x4010)
    
    /// Transaction UID (0008,1195)
    static let transactionUID = Tag(group: 0x0008, element: 0x1195)
    
    /// Procedure Step Cancellation DateTime (0040,4052)
    static let procedureStepCancellationDateTime = Tag(group: 0x0040, element: 0x4052)
    
    /// Affected SOP Instance UID (0000,1000)
    static let affectedSOPInstanceUID = Tag(group: 0x0000, element: 0x1000)
}
