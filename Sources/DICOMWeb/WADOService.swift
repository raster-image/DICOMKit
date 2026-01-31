import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// WADO-RS (Web Access to DICOM Objects - RESTful Services)
///
/// Provides methods for retrieving DICOM objects, metadata, and bulk data
/// over HTTP using RESTful semantics.
///
/// Reference: DICOM PS3.18 Section 10 - WADO-RS
public final class WADOService: @unchecked Sendable {
    
    private let client: HTTPClient
    
    init(client: HTTPClient) {
        self.client = client
    }
    
    // MARK: - Study Level Retrieval
    
    /// Retrieves all instances in a study
    /// - Parameters:
    ///   - studyInstanceUID: The Study Instance UID
    ///   - options: Request options
    /// - Returns: Array of DICOM instance data
    public func retrieveStudy(
        studyInstanceUID: String,
        options: WADORequestOptions = .default
    ) async throws -> [Data] {
        let path = "studies/\(studyInstanceUID)"
        let accept = buildAcceptHeader(options: options)
        
        let (data, response) = try await client.get(path: path, accept: accept)
        
        // Parse multipart response
        guard let contentType = response.value(forHTTPHeaderField: "Content-Type") else {
            throw DICOMWebError.unexpectedContentType("missing")
        }
        
        let parts = try MultipartHandler.decode(data: data, contentType: contentType)
        return parts.map { $0.data }
    }
    
    /// Retrieves metadata for all instances in a study
    /// - Parameter studyInstanceUID: The Study Instance UID
    /// - Returns: JSON metadata model
    public func retrieveStudyMetadata(studyInstanceUID: String) async throws -> DICOMJSONModel {
        let path = "studies/\(studyInstanceUID)/metadata"
        let accept = DICOMWebMediaType.dicomJSON.rawValue
        
        let (data, _) = try await client.get(path: path, accept: accept)
        
        return try DICOMJSONModel(data: data)
    }
    
    // MARK: - Series Level Retrieval
    
    /// Retrieves all instances in a series
    /// - Parameters:
    ///   - studyInstanceUID: The Study Instance UID
    ///   - seriesInstanceUID: The Series Instance UID
    ///   - options: Request options
    /// - Returns: Array of DICOM instance data
    public func retrieveSeries(
        studyInstanceUID: String,
        seriesInstanceUID: String,
        options: WADORequestOptions = .default
    ) async throws -> [Data] {
        let path = "studies/\(studyInstanceUID)/series/\(seriesInstanceUID)"
        let accept = buildAcceptHeader(options: options)
        
        let (data, response) = try await client.get(path: path, accept: accept)
        
        // Parse multipart response
        guard let contentType = response.value(forHTTPHeaderField: "Content-Type") else {
            throw DICOMWebError.unexpectedContentType("missing")
        }
        
        let parts = try MultipartHandler.decode(data: data, contentType: contentType)
        return parts.map { $0.data }
    }
    
    /// Retrieves metadata for all instances in a series
    /// - Parameters:
    ///   - studyInstanceUID: The Study Instance UID
    ///   - seriesInstanceUID: The Series Instance UID
    /// - Returns: JSON metadata model
    public func retrieveSeriesMetadata(
        studyInstanceUID: String,
        seriesInstanceUID: String
    ) async throws -> DICOMJSONModel {
        let path = "studies/\(studyInstanceUID)/series/\(seriesInstanceUID)/metadata"
        let accept = DICOMWebMediaType.dicomJSON.rawValue
        
        let (data, _) = try await client.get(path: path, accept: accept)
        
        return try DICOMJSONModel(data: data)
    }
    
    // MARK: - Instance Level Retrieval
    
    /// Retrieves a single instance
    /// - Parameters:
    ///   - studyInstanceUID: The Study Instance UID
    ///   - seriesInstanceUID: The Series Instance UID
    ///   - sopInstanceUID: The SOP Instance UID
    ///   - options: Request options
    /// - Returns: DICOM instance data
    public func retrieveInstance(
        studyInstanceUID: String,
        seriesInstanceUID: String,
        sopInstanceUID: String,
        options: WADORequestOptions = .default
    ) async throws -> Data {
        let path = "studies/\(studyInstanceUID)/series/\(seriesInstanceUID)/instances/\(sopInstanceUID)"
        let accept = buildAcceptHeader(options: options)
        
        let (data, response) = try await client.get(path: path, accept: accept)
        
        // May be multipart or single part depending on server
        if let contentType = response.value(forHTTPHeaderField: "Content-Type"),
           contentType.contains("multipart") {
            let parts = try MultipartHandler.decode(data: data, contentType: contentType)
            guard let firstPart = parts.first else {
                throw DICOMWebError.parseError("Empty multipart response")
            }
            return firstPart.data
        }
        
        return data
    }
    
    /// Retrieves metadata for a single instance
    /// - Parameters:
    ///   - studyInstanceUID: The Study Instance UID
    ///   - seriesInstanceUID: The Series Instance UID
    ///   - sopInstanceUID: The SOP Instance UID
    /// - Returns: JSON metadata model
    public func retrieveInstanceMetadata(
        studyInstanceUID: String,
        seriesInstanceUID: String,
        sopInstanceUID: String
    ) async throws -> DICOMJSONModel {
        let path = "studies/\(studyInstanceUID)/series/\(seriesInstanceUID)/instances/\(sopInstanceUID)/metadata"
        let accept = DICOMWebMediaType.dicomJSON.rawValue
        
        let (data, _) = try await client.get(path: path, accept: accept)
        
        return try DICOMJSONModel(data: data)
    }
    
    // MARK: - Frame Level Retrieval
    
    /// Retrieves specific frames from a multi-frame instance
    /// - Parameters:
    ///   - studyInstanceUID: The Study Instance UID
    ///   - seriesInstanceUID: The Series Instance UID
    ///   - sopInstanceUID: The SOP Instance UID
    ///   - frameNumbers: Frame numbers to retrieve (1-based)
    ///   - options: Request options
    /// - Returns: Array of frame data
    public func retrieveFrames(
        studyInstanceUID: String,
        seriesInstanceUID: String,
        sopInstanceUID: String,
        frameNumbers: [Int],
        options: WADORequestOptions = .default
    ) async throws -> [Data] {
        let frameList = frameNumbers.map { String($0) }.joined(separator: ",")
        let path = "studies/\(studyInstanceUID)/series/\(seriesInstanceUID)/instances/\(sopInstanceUID)/frames/\(frameList)"
        let accept = buildAcceptHeader(options: options)
        
        let (data, response) = try await client.get(path: path, accept: accept)
        
        // Parse multipart response
        guard let contentType = response.value(forHTTPHeaderField: "Content-Type") else {
            throw DICOMWebError.unexpectedContentType("missing")
        }
        
        let parts = try MultipartHandler.decode(data: data, contentType: contentType)
        return parts.map { $0.data }
    }
    
    // MARK: - Bulk Data Retrieval
    
    /// Retrieves bulk data from a URI
    /// - Parameters:
    ///   - uri: The bulk data URI
    ///   - options: Request options
    /// - Returns: Bulk data
    public func retrieveBulkData(
        uri: String,
        options: WADORequestOptions = .default
    ) async throws -> Data {
        guard let url = URL(string: uri) else {
            throw DICOMWebError.invalidURL(uri)
        }
        
        var request = URLRequest(url: url)
        request.setValue(buildAcceptHeader(options: options), forHTTPHeaderField: "Accept")
        
        let (data, response) = try await client.session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DICOMWebError.internalError("Invalid response type")
        }
        
        if httpResponse.statusCode >= 400 {
            let message = String(data: data, encoding: .utf8) ?? ""
            throw DICOMWebError.fromHTTPStatus(httpResponse.statusCode, message: message)
        }
        
        return data
    }
    
    // MARK: - Rendered Images
    
    /// Retrieves a rendered frame as an image
    /// - Parameters:
    ///   - studyInstanceUID: The Study Instance UID
    ///   - seriesInstanceUID: The Series Instance UID
    ///   - sopInstanceUID: The SOP Instance UID
    ///   - frameNumber: Frame number (1-based)
    ///   - viewport: Optional viewport size
    ///   - windowCenter: Optional window center
    ///   - windowWidth: Optional window width
    ///   - mediaType: Requested image media type (default: JPEG)
    /// - Returns: Rendered image data
    public func retrieveRenderedFrame(
        studyInstanceUID: String,
        seriesInstanceUID: String,
        sopInstanceUID: String,
        frameNumber: Int = 1,
        viewport: Viewport? = nil,
        windowCenter: Double? = nil,
        windowWidth: Double? = nil,
        mediaType: DICOMWebMediaType = .jpeg
    ) async throws -> Data {
        let path = "studies/\(studyInstanceUID)/series/\(seriesInstanceUID)/instances/\(sopInstanceUID)/frames/\(frameNumber)/rendered"
        
        var queryItems: [URLQueryItem] = []
        
        if let viewport = viewport {
            queryItems.append(URLQueryItem(name: "viewport", value: "\(viewport.width),\(viewport.height)"))
        }
        
        if let windowCenter = windowCenter {
            queryItems.append(URLQueryItem(name: "windowcenter", value: String(windowCenter)))
        }
        
        if let windowWidth = windowWidth {
            queryItems.append(URLQueryItem(name: "windowwidth", value: String(windowWidth)))
        }
        
        let accept = mediaType.rawValue
        
        let (data, _) = try await client.get(path: path, queryItems: queryItems, accept: accept)
        
        return data
    }
    
    /// Retrieves a thumbnail for an instance
    /// - Parameters:
    ///   - studyInstanceUID: The Study Instance UID
    ///   - seriesInstanceUID: The Series Instance UID
    ///   - sopInstanceUID: The SOP Instance UID
    ///   - viewport: Optional viewport size
    /// - Returns: Thumbnail image data
    public func retrieveThumbnail(
        studyInstanceUID: String,
        seriesInstanceUID: String,
        sopInstanceUID: String,
        viewport: Viewport? = nil
    ) async throws -> Data {
        let path = "studies/\(studyInstanceUID)/series/\(seriesInstanceUID)/instances/\(sopInstanceUID)/thumbnail"
        
        var queryItems: [URLQueryItem] = []
        
        if let viewport = viewport {
            queryItems.append(URLQueryItem(name: "viewport", value: "\(viewport.width),\(viewport.height)"))
        }
        
        let (data, _) = try await client.get(path: path, queryItems: queryItems, accept: DICOMWebMediaType.jpeg.rawValue)
        
        return data
    }
    
    /// Retrieves a thumbnail for a series
    /// - Parameters:
    ///   - studyInstanceUID: The Study Instance UID
    ///   - seriesInstanceUID: The Series Instance UID
    ///   - viewport: Optional viewport size
    /// - Returns: Thumbnail image data
    public func retrieveSeriesThumbnail(
        studyInstanceUID: String,
        seriesInstanceUID: String,
        viewport: Viewport? = nil
    ) async throws -> Data {
        let path = "studies/\(studyInstanceUID)/series/\(seriesInstanceUID)/thumbnail"
        
        var queryItems: [URLQueryItem] = []
        
        if let viewport = viewport {
            queryItems.append(URLQueryItem(name: "viewport", value: "\(viewport.width),\(viewport.height)"))
        }
        
        let (data, _) = try await client.get(path: path, queryItems: queryItems, accept: DICOMWebMediaType.jpeg.rawValue)
        
        return data
    }
    
    /// Retrieves a thumbnail for a study
    /// - Parameters:
    ///   - studyInstanceUID: The Study Instance UID
    ///   - viewport: Optional viewport size
    /// - Returns: Thumbnail image data
    public func retrieveStudyThumbnail(
        studyInstanceUID: String,
        viewport: Viewport? = nil
    ) async throws -> Data {
        let path = "studies/\(studyInstanceUID)/thumbnail"
        
        var queryItems: [URLQueryItem] = []
        
        if let viewport = viewport {
            queryItems.append(URLQueryItem(name: "viewport", value: "\(viewport.width),\(viewport.height)"))
        }
        
        let (data, _) = try await client.get(path: path, queryItems: queryItems, accept: DICOMWebMediaType.jpeg.rawValue)
        
        return data
    }
    
    // MARK: - Helper Methods
    
    private func buildAcceptHeader(options: WADORequestOptions) -> String {
        var parts: [String] = []
        
        for mediaType in options.acceptMediaTypes {
            if !options.transferSyntaxUIDs.isEmpty && mediaType == .dicom {
                // Add transfer syntax parameter
                for ts in options.transferSyntaxUIDs {
                    parts.append(mediaType.withParameters(["transfer-syntax": ts]))
                }
            } else {
                parts.append(mediaType.rawValue)
            }
        }
        
        return parts.joined(separator: ", ")
    }
}
