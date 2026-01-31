import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// QIDO-RS (Query based on ID for DICOM Objects - RESTful)
///
/// Provides methods for searching DICOM objects (studies, series, instances)
/// using RESTful query parameters.
///
/// Reference: DICOM PS3.18 Section 10.6 - QIDO-RS
public final class QIDOService: @unchecked Sendable {
    
    private let client: HTTPClient
    
    init(client: HTTPClient) {
        self.client = client
    }
    
    // MARK: - Study Search
    
    /// Searches for studies matching the specified criteria
    /// - Parameters:
    ///   - patientName: Patient name (supports wildcards)
    ///   - patientID: Patient ID
    ///   - studyDate: Study date or date range (YYYYMMDD or YYYYMMDD-YYYYMMDD)
    ///   - modality: Modality filter (e.g., "CT", "MR")
    ///   - accessionNumber: Accession number
    ///   - studyInstanceUID: Study Instance UID
    ///   - options: Search options (limit, offset, include fields)
    /// - Returns: Array of study search results
    public func searchStudies(
        patientName: String? = nil,
        patientID: String? = nil,
        studyDate: String? = nil,
        modality: String? = nil,
        accessionNumber: String? = nil,
        studyInstanceUID: String? = nil,
        options: QIDORequestOptions = .default
    ) async throws -> [QIDOStudyResult] {
        var queryItems: [URLQueryItem] = []
        
        if let patientName = patientName {
            queryItems.append(URLQueryItem(name: "PatientName", value: patientName))
        }
        if let patientID = patientID {
            queryItems.append(URLQueryItem(name: "PatientID", value: patientID))
        }
        if let studyDate = studyDate {
            queryItems.append(URLQueryItem(name: "StudyDate", value: studyDate))
        }
        if let modality = modality {
            queryItems.append(URLQueryItem(name: "ModalitiesInStudy", value: modality))
        }
        if let accessionNumber = accessionNumber {
            queryItems.append(URLQueryItem(name: "AccessionNumber", value: accessionNumber))
        }
        if let studyInstanceUID = studyInstanceUID {
            queryItems.append(URLQueryItem(name: "StudyInstanceUID", value: studyInstanceUID))
        }
        
        // Add options
        queryItems.append(contentsOf: buildOptionsQueryItems(options: options))
        
        // Add default include fields for studies
        if options.includeFields.isEmpty {
            queryItems.append(URLQueryItem(name: "includefield", value: "all"))
        }
        
        let (data, _) = try await client.get(
            path: "studies",
            queryItems: queryItems,
            accept: DICOMWebMediaType.dicomJSON.rawValue
        )
        
        let json = try DICOMJSONModel(data: data)
        return parseStudyResults(from: json)
    }
    
    // MARK: - Series Search
    
    /// Searches for series within a study
    /// - Parameters:
    ///   - studyInstanceUID: The Study Instance UID
    ///   - modality: Modality filter
    ///   - seriesInstanceUID: Series Instance UID
    ///   - seriesNumber: Series number
    ///   - options: Search options
    /// - Returns: Array of series search results
    public func searchSeries(
        studyInstanceUID: String,
        modality: String? = nil,
        seriesInstanceUID: String? = nil,
        seriesNumber: Int? = nil,
        options: QIDORequestOptions = .default
    ) async throws -> [QIDOSeriesResult] {
        var queryItems: [URLQueryItem] = []
        
        if let modality = modality {
            queryItems.append(URLQueryItem(name: "Modality", value: modality))
        }
        if let seriesInstanceUID = seriesInstanceUID {
            queryItems.append(URLQueryItem(name: "SeriesInstanceUID", value: seriesInstanceUID))
        }
        if let seriesNumber = seriesNumber {
            queryItems.append(URLQueryItem(name: "SeriesNumber", value: String(seriesNumber)))
        }
        
        queryItems.append(contentsOf: buildOptionsQueryItems(options: options))
        
        if options.includeFields.isEmpty {
            queryItems.append(URLQueryItem(name: "includefield", value: "all"))
        }
        
        let path = "studies/\(studyInstanceUID)/series"
        
        let (data, _) = try await client.get(
            path: path,
            queryItems: queryItems,
            accept: DICOMWebMediaType.dicomJSON.rawValue
        )
        
        let json = try DICOMJSONModel(data: data)
        return parseSeriesResults(from: json)
    }
    
    /// Searches for all series matching criteria (across all studies)
    /// - Parameters:
    ///   - modality: Modality filter
    ///   - seriesInstanceUID: Series Instance UID
    ///   - studyInstanceUID: Study Instance UID
    ///   - options: Search options
    /// - Returns: Array of series search results
    public func searchAllSeries(
        modality: String? = nil,
        seriesInstanceUID: String? = nil,
        studyInstanceUID: String? = nil,
        options: QIDORequestOptions = .default
    ) async throws -> [QIDOSeriesResult] {
        var queryItems: [URLQueryItem] = []
        
        if let modality = modality {
            queryItems.append(URLQueryItem(name: "Modality", value: modality))
        }
        if let seriesInstanceUID = seriesInstanceUID {
            queryItems.append(URLQueryItem(name: "SeriesInstanceUID", value: seriesInstanceUID))
        }
        if let studyInstanceUID = studyInstanceUID {
            queryItems.append(URLQueryItem(name: "StudyInstanceUID", value: studyInstanceUID))
        }
        
        queryItems.append(contentsOf: buildOptionsQueryItems(options: options))
        
        if options.includeFields.isEmpty {
            queryItems.append(URLQueryItem(name: "includefield", value: "all"))
        }
        
        let (data, _) = try await client.get(
            path: "series",
            queryItems: queryItems,
            accept: DICOMWebMediaType.dicomJSON.rawValue
        )
        
        let json = try DICOMJSONModel(data: data)
        return parseSeriesResults(from: json)
    }
    
    // MARK: - Instance Search
    
    /// Searches for instances within a series
    /// - Parameters:
    ///   - studyInstanceUID: The Study Instance UID
    ///   - seriesInstanceUID: The Series Instance UID
    ///   - sopInstanceUID: SOP Instance UID
    ///   - sopClassUID: SOP Class UID
    ///   - instanceNumber: Instance number
    ///   - options: Search options
    /// - Returns: Array of instance search results
    public func searchInstances(
        studyInstanceUID: String,
        seriesInstanceUID: String,
        sopInstanceUID: String? = nil,
        sopClassUID: String? = nil,
        instanceNumber: Int? = nil,
        options: QIDORequestOptions = .default
    ) async throws -> [QIDOInstanceResult] {
        var queryItems: [URLQueryItem] = []
        
        if let sopInstanceUID = sopInstanceUID {
            queryItems.append(URLQueryItem(name: "SOPInstanceUID", value: sopInstanceUID))
        }
        if let sopClassUID = sopClassUID {
            queryItems.append(URLQueryItem(name: "SOPClassUID", value: sopClassUID))
        }
        if let instanceNumber = instanceNumber {
            queryItems.append(URLQueryItem(name: "InstanceNumber", value: String(instanceNumber)))
        }
        
        queryItems.append(contentsOf: buildOptionsQueryItems(options: options))
        
        if options.includeFields.isEmpty {
            queryItems.append(URLQueryItem(name: "includefield", value: "all"))
        }
        
        let path = "studies/\(studyInstanceUID)/series/\(seriesInstanceUID)/instances"
        
        let (data, _) = try await client.get(
            path: path,
            queryItems: queryItems,
            accept: DICOMWebMediaType.dicomJSON.rawValue
        )
        
        let json = try DICOMJSONModel(data: data)
        return parseInstanceResults(from: json)
    }
    
    /// Searches for all instances matching criteria (across all studies)
    /// - Parameters:
    ///   - sopInstanceUID: SOP Instance UID
    ///   - sopClassUID: SOP Class UID
    ///   - studyInstanceUID: Study Instance UID
    ///   - seriesInstanceUID: Series Instance UID
    ///   - options: Search options
    /// - Returns: Array of instance search results
    public func searchAllInstances(
        sopInstanceUID: String? = nil,
        sopClassUID: String? = nil,
        studyInstanceUID: String? = nil,
        seriesInstanceUID: String? = nil,
        options: QIDORequestOptions = .default
    ) async throws -> [QIDOInstanceResult] {
        var queryItems: [URLQueryItem] = []
        
        if let sopInstanceUID = sopInstanceUID {
            queryItems.append(URLQueryItem(name: "SOPInstanceUID", value: sopInstanceUID))
        }
        if let sopClassUID = sopClassUID {
            queryItems.append(URLQueryItem(name: "SOPClassUID", value: sopClassUID))
        }
        if let studyInstanceUID = studyInstanceUID {
            queryItems.append(URLQueryItem(name: "StudyInstanceUID", value: studyInstanceUID))
        }
        if let seriesInstanceUID = seriesInstanceUID {
            queryItems.append(URLQueryItem(name: "SeriesInstanceUID", value: seriesInstanceUID))
        }
        
        queryItems.append(contentsOf: buildOptionsQueryItems(options: options))
        
        if options.includeFields.isEmpty {
            queryItems.append(URLQueryItem(name: "includefield", value: "all"))
        }
        
        let (data, _) = try await client.get(
            path: "instances",
            queryItems: queryItems,
            accept: DICOMWebMediaType.dicomJSON.rawValue
        )
        
        let json = try DICOMJSONModel(data: data)
        return parseInstanceResults(from: json)
    }
    
    // MARK: - Helper Methods
    
    private func buildOptionsQueryItems(options: QIDORequestOptions) -> [URLQueryItem] {
        var items: [URLQueryItem] = []
        
        if let limit = options.limit {
            items.append(URLQueryItem(name: "limit", value: String(limit)))
        }
        if let offset = options.offset {
            items.append(URLQueryItem(name: "offset", value: String(offset)))
        }
        if options.fuzzyMatching {
            items.append(URLQueryItem(name: "fuzzymatching", value: "true"))
        }
        
        for tag in options.includeFields {
            items.append(URLQueryItem(name: "includefield", value: tag.jsonKey))
        }
        
        return items
    }
    
    private func parseStudyResults(from json: DICOMJSONModel) -> [QIDOStudyResult] {
        var results: [QIDOStudyResult] = []
        
        for i in 0..<json.count {
            let result = QIDOStudyResult(
                studyInstanceUID: json.string(for: .studyInstanceUID, at: i) ?? "",
                studyDate: json.string(for: .studyDate, at: i),
                studyTime: json.string(for: .studyTime, at: i),
                studyDescription: json.string(for: .studyDescription, at: i),
                accessionNumber: json.string(for: .accessionNumber, at: i),
                patientName: json.string(for: .patientName, at: i),
                patientID: json.string(for: .patientID, at: i),
                patientBirthDate: json.string(for: .patientBirthDate, at: i),
                patientSex: json.string(for: .patientSex, at: i),
                referringPhysicianName: json.string(for: .referringPhysicianName, at: i),
                modalitiesInStudy: json.strings(for: Tag.modalitiesInStudy, at: i),
                numberOfStudyRelatedSeries: json.integer(for: Tag.numberOfStudyRelatedSeries, at: i),
                numberOfStudyRelatedInstances: json.integer(for: Tag.numberOfStudyRelatedInstances, at: i)
            )
            results.append(result)
        }
        
        return results
    }
    
    private func parseSeriesResults(from json: DICOMJSONModel) -> [QIDOSeriesResult] {
        var results: [QIDOSeriesResult] = []
        
        for i in 0..<json.count {
            let result = QIDOSeriesResult(
                seriesInstanceUID: json.string(for: .seriesInstanceUID, at: i) ?? "",
                studyInstanceUID: json.string(for: .studyInstanceUID, at: i) ?? "",
                seriesNumber: json.integer(for: .seriesNumber, at: i),
                seriesDescription: json.string(for: .seriesDescription, at: i),
                modality: json.string(for: .modality, at: i),
                bodyPartExamined: json.string(for: Tag.bodyPartExamined, at: i),
                numberOfSeriesRelatedInstances: json.integer(for: Tag.numberOfSeriesRelatedInstances, at: i),
                performedProcedureStepStartDate: json.string(for: Tag.performedProcedureStepStartDate, at: i),
                performedProcedureStepStartTime: json.string(for: Tag.performedProcedureStepStartTime, at: i)
            )
            results.append(result)
        }
        
        return results
    }
    
    private func parseInstanceResults(from json: DICOMJSONModel) -> [QIDOInstanceResult] {
        var results: [QIDOInstanceResult] = []
        
        for i in 0..<json.count {
            let result = QIDOInstanceResult(
                sopInstanceUID: json.string(for: .sopInstanceUID, at: i) ?? "",
                sopClassUID: json.string(for: .sopClassUID, at: i) ?? "",
                seriesInstanceUID: json.string(for: .seriesInstanceUID, at: i) ?? "",
                studyInstanceUID: json.string(for: .studyInstanceUID, at: i) ?? "",
                instanceNumber: json.integer(for: .instanceNumber, at: i),
                rows: json.integer(for: .rows, at: i),
                columns: json.integer(for: .columns, at: i),
                bitsAllocated: json.integer(for: .bitsAllocated, at: i),
                numberOfFrames: json.integer(for: .numberOfFrames, at: i)
            )
            results.append(result)
        }
        
        return results
    }
}

// MARK: - Result Types

/// Result from a QIDO-RS study search
public struct QIDOStudyResult: Sendable, Equatable {
    public let studyInstanceUID: String
    public let studyDate: String?
    public let studyTime: String?
    public let studyDescription: String?
    public let accessionNumber: String?
    public let patientName: String?
    public let patientID: String?
    public let patientBirthDate: String?
    public let patientSex: String?
    public let referringPhysicianName: String?
    public let modalitiesInStudy: [String]?
    public let numberOfStudyRelatedSeries: Int?
    public let numberOfStudyRelatedInstances: Int?
    
    public init(
        studyInstanceUID: String,
        studyDate: String? = nil,
        studyTime: String? = nil,
        studyDescription: String? = nil,
        accessionNumber: String? = nil,
        patientName: String? = nil,
        patientID: String? = nil,
        patientBirthDate: String? = nil,
        patientSex: String? = nil,
        referringPhysicianName: String? = nil,
        modalitiesInStudy: [String]? = nil,
        numberOfStudyRelatedSeries: Int? = nil,
        numberOfStudyRelatedInstances: Int? = nil
    ) {
        self.studyInstanceUID = studyInstanceUID
        self.studyDate = studyDate
        self.studyTime = studyTime
        self.studyDescription = studyDescription
        self.accessionNumber = accessionNumber
        self.patientName = patientName
        self.patientID = patientID
        self.patientBirthDate = patientBirthDate
        self.patientSex = patientSex
        self.referringPhysicianName = referringPhysicianName
        self.modalitiesInStudy = modalitiesInStudy
        self.numberOfStudyRelatedSeries = numberOfStudyRelatedSeries
        self.numberOfStudyRelatedInstances = numberOfStudyRelatedInstances
    }
}

/// Result from a QIDO-RS series search
public struct QIDOSeriesResult: Sendable, Equatable {
    public let seriesInstanceUID: String
    public let studyInstanceUID: String
    public let seriesNumber: Int?
    public let seriesDescription: String?
    public let modality: String?
    public let bodyPartExamined: String?
    public let numberOfSeriesRelatedInstances: Int?
    public let performedProcedureStepStartDate: String?
    public let performedProcedureStepStartTime: String?
    
    public init(
        seriesInstanceUID: String,
        studyInstanceUID: String,
        seriesNumber: Int? = nil,
        seriesDescription: String? = nil,
        modality: String? = nil,
        bodyPartExamined: String? = nil,
        numberOfSeriesRelatedInstances: Int? = nil,
        performedProcedureStepStartDate: String? = nil,
        performedProcedureStepStartTime: String? = nil
    ) {
        self.seriesInstanceUID = seriesInstanceUID
        self.studyInstanceUID = studyInstanceUID
        self.seriesNumber = seriesNumber
        self.seriesDescription = seriesDescription
        self.modality = modality
        self.bodyPartExamined = bodyPartExamined
        self.numberOfSeriesRelatedInstances = numberOfSeriesRelatedInstances
        self.performedProcedureStepStartDate = performedProcedureStepStartDate
        self.performedProcedureStepStartTime = performedProcedureStepStartTime
    }
}

/// Result from a QIDO-RS instance search
public struct QIDOInstanceResult: Sendable, Equatable {
    public let sopInstanceUID: String
    public let sopClassUID: String
    public let seriesInstanceUID: String
    public let studyInstanceUID: String
    public let instanceNumber: Int?
    public let rows: Int?
    public let columns: Int?
    public let bitsAllocated: Int?
    public let numberOfFrames: Int?
    
    public init(
        sopInstanceUID: String,
        sopClassUID: String,
        seriesInstanceUID: String,
        studyInstanceUID: String,
        instanceNumber: Int? = nil,
        rows: Int? = nil,
        columns: Int? = nil,
        bitsAllocated: Int? = nil,
        numberOfFrames: Int? = nil
    ) {
        self.sopInstanceUID = sopInstanceUID
        self.sopClassUID = sopClassUID
        self.seriesInstanceUID = seriesInstanceUID
        self.studyInstanceUID = studyInstanceUID
        self.instanceNumber = instanceNumber
        self.rows = rows
        self.columns = columns
        self.bitsAllocated = bitsAllocated
        self.numberOfFrames = numberOfFrames
    }
}

// MARK: - Tag Extensions

extension Tag {
    /// Modalities In Study (0008,0061)
    static let modalitiesInStudy = Tag(group: 0x0008, element: 0x0061)
    
    /// Number of Study Related Series (0020,1206)
    static let numberOfStudyRelatedSeries = Tag(group: 0x0020, element: 0x1206)
    
    /// Number of Study Related Instances (0020,1208)
    static let numberOfStudyRelatedInstances = Tag(group: 0x0020, element: 0x1208)
    
    /// Body Part Examined (0018,0015)
    static let bodyPartExamined = Tag(group: 0x0018, element: 0x0015)
    
    /// Number of Series Related Instances (0020,1209)
    static let numberOfSeriesRelatedInstances = Tag(group: 0x0020, element: 0x1209)
    
    /// Performed Procedure Step Start Date (0040,0244)
    static let performedProcedureStepStartDate = Tag(group: 0x0040, element: 0x0244)
    
    /// Performed Procedure Step Start Time (0040,0245)
    static let performedProcedureStepStartTime = Tag(group: 0x0040, element: 0x0245)
}
