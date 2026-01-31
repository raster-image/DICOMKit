import Testing
import Foundation
@testable import DICOMWeb

@Suite("Multipart Handler Tests")
struct MultipartHandlerTests {
    
    @Test("Generate unique boundary")
    func testGenerateBoundary() {
        let boundary1 = MultipartHandler.generateBoundary()
        let boundary2 = MultipartHandler.generateBoundary()
        
        #expect(boundary1 != boundary2)
        #expect(boundary1.hasPrefix("----DICOMKitBoundary"))
        #expect(boundary2.hasPrefix("----DICOMKitBoundary"))
    }
    
    @Test("Extract boundary from Content-Type header")
    func testExtractBoundary() {
        let contentType = "multipart/related; type=\"application/dicom\"; boundary=\"----TestBoundary123\""
        let boundary = MultipartHandler.extractBoundary(from: contentType)
        
        #expect(boundary == "----TestBoundary123")
    }
    
    @Test("Extract boundary without quotes")
    func testExtractBoundaryWithoutQuotes() {
        let contentType = "multipart/related; boundary=----TestBoundary123"
        let boundary = MultipartHandler.extractBoundary(from: contentType)
        
        #expect(boundary == "----TestBoundary123")
    }
    
    @Test("Extract boundary returns nil for missing boundary")
    func testExtractBoundaryMissing() {
        let contentType = "multipart/related; type=\"application/dicom\""
        let boundary = MultipartHandler.extractBoundary(from: contentType)
        
        #expect(boundary == nil)
    }
    
    @Test("Content type header generation")
    func testContentType() {
        let handler = MultipartHandler(boundary: "TestBoundary")
        let contentType = handler.contentType
        
        #expect(contentType.contains("multipart/related"))
        #expect(contentType.contains("type=\"application/dicom\""))
        #expect(contentType.contains("boundary=\"TestBoundary\""))
    }
    
    @Test("Content type JSON header generation")
    func testContentTypeJSON() {
        let handler = MultipartHandler(boundary: "TestBoundary")
        let contentType = handler.contentTypeJSON
        
        #expect(contentType.contains("multipart/related"))
        #expect(contentType.contains("type=\"application/dicom+json\""))
        #expect(contentType.contains("boundary=\"TestBoundary\""))
    }
    
    @Test("Encode single DICOM instance")
    func testEncodeSingleInstance() {
        let handler = MultipartHandler(boundary: "TestBoundary")
        let testData = Data("DICOM DATA".utf8)
        
        let encoded = handler.encode(instances: [testData])
        let encodedString = String(data: encoded, encoding: .utf8)!
        
        #expect(encodedString.contains("--TestBoundary"))
        #expect(encodedString.contains("Content-Type: application/dicom"))
        #expect(encodedString.contains("--TestBoundary--"))
    }
    
    @Test("Encode multiple instances")
    func testEncodeMultipleInstances() {
        let handler = MultipartHandler(boundary: "TestBoundary")
        let data1 = Data("DICOM DATA 1".utf8)
        let data2 = Data("DICOM DATA 2".utf8)
        
        let encoded = handler.encode(instances: [data1, data2])
        let encodedString = String(data: encoded, encoding: .utf8)!
        
        // Count boundary occurrences (should be 3: 2 for parts + 1 closing)
        let boundaryCount = encodedString.components(separatedBy: "--TestBoundary").count - 1
        #expect(boundaryCount == 3)
    }
    
    @Test("Encode parts with custom headers")
    func testEncodePartsWithCustomHeaders() {
        let handler = MultipartHandler(boundary: "TestBoundary")
        let part = MultipartPart(
            data: Data("Test data".utf8),
            contentType: .dicom,
            contentTransferEncoding: "binary",
            additionalHeaders: ["Content-ID": "part1"]
        )
        
        let encoded = handler.encode(parts: [part])
        let encodedString = String(data: encoded, encoding: .utf8)!
        
        #expect(encodedString.contains("Content-Transfer-Encoding: binary"))
        #expect(encodedString.contains("Content-ID: part1"))
    }
    
    @Test("Multipart part creation")
    func testMultipartPartCreation() {
        let testData = Data("Test".utf8)
        let part = MultipartPart(
            data: testData,
            contentType: .dicomJSON,
            contentTransferEncoding: "8bit",
            additionalHeaders: ["X-Custom": "value"]
        )
        
        #expect(part.data == testData)
        #expect(part.contentType == .dicomJSON)
        #expect(part.contentTransferEncoding == "8bit")
        #expect(part.additionalHeaders["X-Custom"] == "value")
    }
}
