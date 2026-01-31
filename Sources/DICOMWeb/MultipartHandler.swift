import Foundation

/// Handles multipart MIME encoding and decoding for DICOMweb requests and responses
///
/// Reference: RFC 2046 - MIME Part Two: Media Types (Section 5.1 - Multipart)
/// Reference: DICOM PS3.18 Section 8.5 - Multipart MIME
public struct MultipartHandler: Sendable {
    
    /// The boundary string used to separate parts
    public let boundary: String
    
    /// Creates a multipart handler with an auto-generated boundary
    public init() {
        self.boundary = MultipartHandler.generateBoundary()
    }
    
    /// Creates a multipart handler with a specific boundary
    /// - Parameter boundary: The boundary string to use
    public init(boundary: String) {
        self.boundary = boundary
    }
    
    /// Generates a unique boundary string
    /// - Returns: A unique boundary string
    public static func generateBoundary() -> String {
        let uuid = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        return "----DICOMKitBoundary\(uuid)"
    }
    
    /// Extracts the boundary from a Content-Type header
    /// - Parameter contentType: The Content-Type header value
    /// - Returns: The boundary string if found
    public static func extractBoundary(from contentType: String) -> String? {
        // Parse Content-Type: multipart/related; boundary="..."
        let components = contentType.components(separatedBy: ";")
        for component in components {
            let trimmed = component.trimmingCharacters(in: .whitespaces)
            if trimmed.lowercased().hasPrefix("boundary=") {
                var boundary = String(trimmed.dropFirst(9))
                // Remove quotes if present
                if boundary.hasPrefix("\"") && boundary.hasSuffix("\"") {
                    boundary = String(boundary.dropFirst().dropLast())
                }
                return boundary
            }
        }
        return nil
    }
    
    /// The Content-Type header value for this multipart message
    public var contentType: String {
        "multipart/related; type=\"application/dicom\"; boundary=\"\(boundary)\""
    }
    
    /// The Content-Type header value for JSON metadata
    public var contentTypeJSON: String {
        "multipart/related; type=\"application/dicom+json\"; boundary=\"\(boundary)\""
    }
}

// MARK: - Encoding

extension MultipartHandler {
    
    /// Encodes multiple DICOM instances into a multipart/related body
    /// - Parameter instances: Array of DICOM data instances
    /// - Returns: The encoded multipart body data
    public func encode(instances: [Data]) -> Data {
        encode(parts: instances.map { MultipartPart(data: $0, contentType: .dicom) })
    }
    
    /// Encodes multiple parts into a multipart/related body
    /// - Parameter parts: Array of multipart parts
    /// - Returns: The encoded multipart body data
    public func encode(parts: [MultipartPart]) -> Data {
        var body = Data()
        
        for part in parts {
            // Boundary delimiter
            body.append(Data("--\(boundary)\r\n".utf8))
            
            // Content-Type header
            body.append(Data("Content-Type: \(part.contentType.rawValue)\r\n".utf8))
            
            // Content-Transfer-Encoding header (optional)
            if let encoding = part.contentTransferEncoding {
                body.append(Data("Content-Transfer-Encoding: \(encoding)\r\n".utf8))
            }
            
            // Additional headers
            for (name, value) in part.additionalHeaders {
                body.append(Data("\(name): \(value)\r\n".utf8))
            }
            
            // Blank line to end headers
            body.append(Data("\r\n".utf8))
            
            // Part body
            body.append(part.data)
            
            // End with CRLF
            body.append(Data("\r\n".utf8))
        }
        
        // Closing boundary
        body.append(Data("--\(boundary)--\r\n".utf8))
        
        return body
    }
}

// MARK: - Decoding

extension MultipartHandler {
    
    /// Parses a multipart response into individual parts
    /// - Parameters:
    ///   - data: The multipart response data
    ///   - contentType: The Content-Type header (used to extract boundary if not set)
    /// - Returns: Array of decoded multipart parts
    /// - Throws: DICOMWebError if parsing fails
    public static func decode(data: Data, contentType: String) throws -> [MultipartPart] {
        guard let boundary = extractBoundary(from: contentType) else {
            throw DICOMWebError.missingBoundary
        }
        
        let handler = MultipartHandler(boundary: boundary)
        return try handler.decode(data: data)
    }
    
    /// Parses a multipart response into individual parts using this handler's boundary
    /// - Parameter data: The multipart response data
    /// - Returns: Array of decoded multipart parts
    /// - Throws: DICOMWebError if parsing fails
    public func decode(data: Data) throws -> [MultipartPart] {
        guard let string = String(data: data, encoding: .utf8) else {
            // Try parsing as binary
            return try decodeBinary(data: data)
        }
        
        return try decodeString(string: string, data: data)
    }
    
    private func decodeString(string: String, data: Data) throws -> [MultipartPart] {
        var parts: [MultipartPart] = []
        
        let boundaryDelimiter = "--\(boundary)"
        
        // Split by boundary
        let sections = string.components(separatedBy: boundaryDelimiter)
        
        for section in sections {
            // Skip preamble and closing
            if section.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
               section.hasPrefix("--") {
                continue
            }
            
            // Trim leading/trailing whitespace
            let trimmed = section.trimmingCharacters(in: CharacterSet(charactersIn: "\r\n"))
            
            // Skip if this is the closing boundary
            if trimmed == "--" || trimmed.isEmpty {
                continue
            }
            
            // Parse headers and body
            guard let part = try? parsePart(from: trimmed) else {
                continue
            }
            
            parts.append(part)
        }
        
        return parts
    }
    
    private func decodeBinary(data: Data) throws -> [MultipartPart] {
        var parts: [MultipartPart] = []
        
        let boundaryData = Data("--\(boundary)".utf8)
        let doubleCrlfData = Data("\r\n\r\n".utf8)
        
        var currentIndex = 0
        
        while currentIndex < data.count {
            // Find next boundary
            guard let boundaryRange = data.range(of: boundaryData, options: [], in: currentIndex..<data.count) else {
                break
            }
            
            currentIndex = boundaryRange.upperBound
            
            // Skip CRLF after boundary
            if data.count > currentIndex + 2 {
                if data[currentIndex] == 0x0D && data[currentIndex + 1] == 0x0A {
                    currentIndex += 2
                }
            }
            
            // Check for closing boundary
            if currentIndex < data.count && data[currentIndex] == 0x2D { // '-'
                break
            }
            
            // Find header/body separator (double CRLF)
            guard let headerEndRange = data.range(of: doubleCrlfData, options: [], in: currentIndex..<data.count) else {
                continue
            }
            
            // Parse headers
            let headerData = data[currentIndex..<headerEndRange.lowerBound]
            let headers = try parseHeaders(data: headerData)
            
            // Body starts after double CRLF
            let bodyStart = headerEndRange.upperBound
            
            // Find next boundary for body end
            let bodyEndIndex: Int
            if let nextBoundary = data.range(of: boundaryData, options: [], in: bodyStart..<data.count) {
                // Body ends 2 bytes before boundary (CRLF)
                bodyEndIndex = max(bodyStart, nextBoundary.lowerBound - 2)
            } else {
                bodyEndIndex = data.count
            }
            
            let bodyData = data[bodyStart..<bodyEndIndex]
            
            let contentType = headers["content-type"] ?? "application/octet-stream"
            let mediaType = DICOMWebMediaType(rawValue: contentType.lowercased()) ?? .octetStream
            
            parts.append(MultipartPart(
                data: Data(bodyData),
                contentType: mediaType,
                contentTransferEncoding: headers["content-transfer-encoding"],
                additionalHeaders: headers
            ))
            
            currentIndex = bodyEndIndex
        }
        
        return parts
    }
    
    private func parsePart(from string: String) throws -> MultipartPart {
        // Find the separator between headers and body
        guard let separatorRange = string.range(of: "\r\n\r\n") ??
                                    string.range(of: "\n\n") else {
            // No body, just headers
            let headers = parseHeadersFromString(string)
            return MultipartPart(
                data: Data(),
                contentType: .octetStream,
                additionalHeaders: headers
            )
        }
        
        let headerSection = String(string[..<separatorRange.lowerBound])
        let bodySection = String(string[separatorRange.upperBound...])
        
        let headers = parseHeadersFromString(headerSection)
        
        let contentType = headers["content-type"] ?? "application/octet-stream"
        let mediaType = DICOMWebMediaType(rawValue: contentType.lowercased()) ?? .octetStream
        
        return MultipartPart(
            data: Data(bodySection.utf8),
            contentType: mediaType,
            contentTransferEncoding: headers["content-transfer-encoding"],
            additionalHeaders: headers
        )
    }
    
    private func parseHeadersFromString(_ headerSection: String) -> [String: String] {
        var headers: [String: String] = [:]
        
        let lines = headerSection.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if let colonIndex = trimmed.firstIndex(of: ":") {
                let name = String(trimmed[..<colonIndex]).trimmingCharacters(in: .whitespaces).lowercased()
                let value = String(trimmed[trimmed.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                headers[name] = value
            }
        }
        
        return headers
    }
    
    private func parseHeaders(data: Data) throws -> [String: String] {
        guard let string = String(data: data, encoding: .utf8) else {
            return [:]
        }
        return parseHeadersFromString(string)
    }
}

// MARK: - Multipart Part

/// Represents a single part in a multipart message
public struct MultipartPart: Sendable {
    
    /// The part's body data
    public let data: Data
    
    /// The Content-Type of this part
    public let contentType: DICOMWebMediaType
    
    /// The Content-Transfer-Encoding (optional)
    public let contentTransferEncoding: String?
    
    /// Additional headers
    public let additionalHeaders: [String: String]
    
    /// Creates a multipart part
    /// - Parameters:
    ///   - data: The part's body data
    ///   - contentType: The Content-Type of this part
    ///   - contentTransferEncoding: The Content-Transfer-Encoding (optional)
    ///   - additionalHeaders: Additional headers
    public init(
        data: Data,
        contentType: DICOMWebMediaType,
        contentTransferEncoding: String? = nil,
        additionalHeaders: [String: String] = [:]
    ) {
        self.data = data
        self.contentType = contentType
        self.contentTransferEncoding = contentTransferEncoding
        self.additionalHeaders = additionalHeaders
    }
}

// MARK: - Data Extension

extension Data {
    /// Finds the range of a pattern within a subrange of this data
    func range(of pattern: Data, options: Data.SearchOptions = [], in searchRange: Range<Int>) -> Range<Int>? {
        let startIndex = index(startIndex, offsetBy: searchRange.lowerBound)
        let endIndex = index(self.startIndex, offsetBy: Swift.min(searchRange.upperBound, count))
        
        guard startIndex < endIndex else { return nil }
        
        let subdata = self[startIndex..<endIndex]
        if let range = subdata.range(of: pattern, options: options) {
            let lowerBound = distance(from: self.startIndex, to: range.lowerBound)
            let upperBound = distance(from: self.startIndex, to: range.upperBound)
            return lowerBound..<upperBound
        }
        return nil
    }
}
