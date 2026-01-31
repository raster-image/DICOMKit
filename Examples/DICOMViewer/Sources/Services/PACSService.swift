import Foundation
import DICOMKit
import DICOMNetwork
import DICOMCore

/// Service for interacting with a PACS server
@MainActor
class PACSService: ObservableObject {
    private let configuration: PACSConfiguration
    
    @Published var isLoading: Bool = false
    @Published var lastError: Error?
    
    init(configuration: PACSConfiguration) {
        self.configuration = configuration
    }
    
    // MARK: - Connectivity
    
    /// Tests connectivity to the PACS server using C-ECHO
    func verifyConnection() async throws -> Bool {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let result = try await DICOMVerificationService.echo(
                host: configuration.host,
                port: configuration.port,
                callingAE: configuration.callingAETitle,
                calledAE: configuration.calledAETitle,
                timeout: configuration.timeout
            )
            lastError = nil
            return result
        } catch {
            lastError = error
            throw error
        }
    }
    
    // MARK: - Study Queries
    
    /// Searches for studies matching the specified criteria
    func searchStudies(
        patientName: String? = nil,
        patientID: String? = nil,
        studyDate: String? = nil,
        modality: String? = nil,
        accessionNumber: String? = nil
    ) async throws -> [StudyItem] {
        isLoading = true
        defer { isLoading = false }
        
        var queryKeys = QueryKeys.defaultStudyKeys()
        
        if let name = patientName, !name.isEmpty {
            // Add wildcard if not present for partial matching
            let searchName = name.contains("*") ? name : "*\(name)*"
            queryKeys = queryKeys.patientName(searchName)
        }
        
        if let id = patientID, !id.isEmpty {
            queryKeys = queryKeys.patientID(id)
        }
        
        if let date = studyDate, !date.isEmpty {
            queryKeys = queryKeys.studyDate(date)
        }
        
        if let mod = modality, !mod.isEmpty {
            queryKeys = queryKeys.modalitiesInStudy(mod)
        }
        
        if let accession = accessionNumber, !accession.isEmpty {
            queryKeys = queryKeys.accessionNumber(accession)
        }
        
        do {
            let results = try await DICOMQueryService.findStudies(
                host: configuration.host,
                port: configuration.port,
                callingAE: configuration.callingAETitle,
                calledAE: configuration.calledAETitle,
                matching: queryKeys,
                timeout: configuration.timeout
            )
            
            lastError = nil
            return results.map { result in
                StudyItem(
                    id: result.studyInstanceUID ?? UUID().uuidString,
                    patientName: result.patientName ?? "Unknown",
                    patientID: result.patientID,
                    studyDate: result.studyDate,
                    studyTime: result.studyTime,
                    studyDescription: result.studyDescription,
                    modalities: result.modalitiesInStudy,
                    accessionNumber: result.accessionNumber,
                    numberOfSeries: result.numberOfStudyRelatedSeries,
                    numberOfInstances: result.numberOfStudyRelatedInstances
                )
            }
        } catch {
            lastError = error
            throw error
        }
    }
    
    // MARK: - Series Queries
    
    /// Finds all series for a given study
    func findSeries(forStudy studyInstanceUID: String) async throws -> [SeriesItem] {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let results = try await DICOMQueryService.findSeries(
                host: configuration.host,
                port: configuration.port,
                callingAE: configuration.callingAETitle,
                calledAE: configuration.calledAETitle,
                forStudy: studyInstanceUID,
                timeout: configuration.timeout
            )
            
            lastError = nil
            return results.map { result in
                SeriesItem(
                    id: result.seriesInstanceUID ?? UUID().uuidString,
                    studyInstanceUID: studyInstanceUID,
                    seriesNumber: result.seriesNumber,
                    modality: result.modality,
                    seriesDescription: result.seriesDescription,
                    numberOfInstances: result.numberOfSeriesRelatedInstances,
                    bodyPart: result.bodyPartExamined
                )
            }.sorted { ($0.seriesNumber ?? 0) < ($1.seriesNumber ?? 0) }
        } catch {
            lastError = error
            throw error
        }
    }
    
    // MARK: - Instance Queries
    
    /// Finds all instances for a given series
    func findInstances(
        forStudy studyInstanceUID: String,
        forSeries seriesInstanceUID: String
    ) async throws -> [InstanceItem] {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let results = try await DICOMQueryService.findInstances(
                host: configuration.host,
                port: configuration.port,
                callingAE: configuration.callingAETitle,
                calledAE: configuration.calledAETitle,
                forStudy: studyInstanceUID,
                forSeries: seriesInstanceUID,
                timeout: configuration.timeout
            )
            
            lastError = nil
            return results.map { result in
                InstanceItem(
                    id: result.sopInstanceUID ?? UUID().uuidString,
                    studyInstanceUID: studyInstanceUID,
                    seriesInstanceUID: seriesInstanceUID,
                    instanceNumber: result.instanceNumber,
                    sopClassUID: result.sopClassUID
                )
            }.sorted { ($0.instanceNumber ?? 0) < ($1.instanceNumber ?? 0) }
        } catch {
            lastError = error
            throw error
        }
    }
    
    // MARK: - Image Retrieval
    
    /// Retrieves a DICOM file using C-GET
    func retrieveInstance(
        studyInstanceUID: String,
        seriesInstanceUID: String,
        sopInstanceUID: String
    ) async throws -> DICOMFile {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let clientConfig = try DICOMClientConfiguration(
                host: configuration.host,
                port: configuration.port,
                callingAE: configuration.callingAETitle,
                calledAE: configuration.calledAETitle,
                timeout: configuration.timeout
            )
            
            let client = DICOMClient(configuration: clientConfig)
            
            var retrievedFile: DICOMFile?
            
            for try await file in try await client.get(
                studyInstanceUID: studyInstanceUID,
                seriesInstanceUID: seriesInstanceUID,
                sopInstanceUID: sopInstanceUID
            ) {
                retrievedFile = file
                break
            }
            
            guard let file = retrievedFile else {
                throw PACSError.retrieveFailed("No file received for instance \(sopInstanceUID)")
            }
            
            lastError = nil
            return file
        } catch {
            lastError = error
            throw error
        }
    }
    
    /// Retrieves all instances in a series using C-GET
    func retrieveSeries(
        studyInstanceUID: String,
        seriesInstanceUID: String
    ) -> AsyncThrowingStream<DICOMFile, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let clientConfig = try DICOMClientConfiguration(
                        host: configuration.host,
                        port: configuration.port,
                        callingAE: configuration.callingAETitle,
                        calledAE: configuration.calledAETitle,
                        timeout: configuration.timeout
                    )
                    
                    let client = DICOMClient(configuration: clientConfig)
                    
                    for try await file in try await client.get(
                        studyInstanceUID: studyInstanceUID,
                        seriesInstanceUID: seriesInstanceUID
                    ) {
                        continuation.yield(file)
                    }
                    
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

// MARK: - Errors

enum PACSError: LocalizedError {
    case connectionFailed(String)
    case queryFailed(String)
    case retrieveFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .connectionFailed(let message):
            return "Connection failed: \(message)"
        case .queryFailed(let message):
            return "Query failed: \(message)"
        case .retrieveFailed(let message):
            return "Retrieve failed: \(message)"
        }
    }
}
