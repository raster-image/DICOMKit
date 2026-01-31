import Testing
import Foundation
@testable import DICOMWeb
@testable import DICOMCore

@Suite("DICOM JSON Model Tests")
struct DICOMJSONModelTests {
    
    @Test("Parse single-item JSON array")
    func testParseSingleItem() throws {
        let json = """
        [
            {
                "00080020": {
                    "vr": "DA",
                    "Value": ["20240115"]
                },
                "00100010": {
                    "vr": "PN",
                    "Value": ["Doe^John"]
                }
            }
        ]
        """
        
        let model = try DICOMJSONModel(data: Data(json.utf8))
        
        #expect(model.count == 1)
        #expect(model.string(for: .studyDate) == "20240115")
        #expect(model.string(for: .patientName) == "Doe^John")
    }
    
    @Test("Parse multiple-item JSON array")
    func testParseMultipleItems() throws {
        let json = """
        [
            {
                "00100020": {
                    "vr": "LO",
                    "Value": ["PATIENT001"]
                }
            },
            {
                "00100020": {
                    "vr": "LO",
                    "Value": ["PATIENT002"]
                }
            }
        ]
        """
        
        let model = try DICOMJSONModel(data: Data(json.utf8))
        
        #expect(model.count == 2)
        #expect(model.string(for: .patientID, at: 0) == "PATIENT001")
        #expect(model.string(for: .patientID, at: 1) == "PATIENT002")
    }
    
    @Test("Parse integer values")
    func testParseInteger() throws {
        let json = """
        [
            {
                "00280010": {
                    "vr": "US",
                    "Value": [512]
                }
            }
        ]
        """
        
        let model = try DICOMJSONModel(data: Data(json.utf8))
        
        #expect(model.integer(for: .rows) == 512)
    }
    
    @Test("Parse double values")
    func testParseDouble() throws {
        let json = """
        [
            {
                "00180050": {
                    "vr": "DS",
                    "Value": [2.5]
                }
            }
        ]
        """
        
        let model = try DICOMJSONModel(data: Data(json.utf8))
        
        #expect(model.double(for: .sliceThickness) == 2.5)
    }
    
    @Test("Parse string array values")
    func testParseStringArray() throws {
        let json = """
        [
            {
                "00080061": {
                    "vr": "CS",
                    "Value": ["CT", "MR", "US"]
                }
            }
        ]
        """
        
        let model = try DICOMJSONModel(data: Data(json.utf8))
        
        let modalities = model.strings(for: Tag.modalitiesInStudy)
        #expect(modalities == ["CT", "MR", "US"])
    }
    
    @Test("Parse VR from element")
    func testParseVR() throws {
        let json = """
        [
            {
                "00080020": {
                    "vr": "DA",
                    "Value": ["20240115"]
                }
            }
        ]
        """
        
        let model = try DICOMJSONModel(data: Data(json.utf8))
        
        #expect(model.vr(for: .studyDate) == "DA")
    }
    
    @Test("Parse bulk data URI")
    func testParseBulkDataURI() throws {
        let json = """
        [
            {
                "7FE00010": {
                    "vr": "OW",
                    "BulkDataURI": "http://server/studies/1.2.3/series/4.5.6/instances/7.8.9/bulkdata/7fe00010"
                }
            }
        ]
        """
        
        let model = try DICOMJSONModel(data: Data(json.utf8))
        
        let uri = model.bulkDataURI(for: .pixelData)
        #expect(uri?.contains("bulkdata/7fe00010") == true)
    }
    
    @Test("Missing value returns nil")
    func testMissingValue() throws {
        let json = """
        [
            {
                "00080020": {
                    "vr": "DA",
                    "Value": ["20240115"]
                }
            }
        ]
        """
        
        let model = try DICOMJSONModel(data: Data(json.utf8))
        
        #expect(model.string(for: .patientName) == nil)
    }
    
    @Test("Out of bounds index returns nil")
    func testOutOfBoundsIndex() throws {
        let json = """
        [
            {
                "00080020": {
                    "vr": "DA",
                    "Value": ["20240115"]
                }
            }
        ]
        """
        
        let model = try DICOMJSONModel(data: Data(json.utf8))
        
        #expect(model.string(for: .studyDate, at: 5) == nil)
    }
    
    @Test("Invalid JSON throws error")
    func testInvalidJSON() throws {
        let invalidJSON = "not valid json"
        
        #expect(throws: DICOMWebError.self) {
            _ = try DICOMJSONModel(data: Data(invalidJSON.utf8))
        }
    }
    
    @Test("Tag to JSON key conversion")
    func testTagToJSONKey() {
        let tag = Tag(group: 0x0008, element: 0x0020)
        #expect(tag.jsonKey == "00080020")
    }
    
    @Test("JSON key to Tag conversion")
    func testJSONKeyToTag() {
        let tag = Tag.fromJSONKey("00100010")
        
        #expect(tag?.group == 0x0010)
        #expect(tag?.element == 0x0010)
    }
    
    @Test("Invalid JSON key returns nil")
    func testInvalidJSONKey() {
        let tag = Tag.fromJSONKey("invalid")
        #expect(tag == nil)
    }
}

@Suite("DICOM JSON Encoder Tests")
struct DICOMJSONEncoderTests {
    
    @Test("Encode string element")
    func testEncodeString() throws {
        let encoder = DICOMJSONEncoder()
        let element = encoder.element(tag: .patientName, vr: .PN, value: "Doe^John")
        
        let jsonKey = Tag.patientName.jsonKey
        #expect(element[jsonKey] != nil)
    }
    
    @Test("Encode integer element")
    func testEncodeInteger() throws {
        let encoder = DICOMJSONEncoder()
        let element = encoder.element(tag: .rows, vr: .US, value: 512)
        
        let jsonKey = Tag.rows.jsonKey
        #expect(element[jsonKey] != nil)
    }
    
    @Test("Encode double element")
    func testEncodeDouble() throws {
        let encoder = DICOMJSONEncoder()
        let element = encoder.element(tag: .sliceThickness, vr: .DS, value: 2.5)
        
        let jsonKey = Tag.sliceThickness.jsonKey
        #expect(element[jsonKey] != nil)
    }
    
    @Test("Encode bulk data element")
    func testEncodeBulkData() throws {
        let encoder = DICOMJSONEncoder()
        let element = encoder.bulkDataElement(tag: .pixelData, vr: .OW, uri: "http://example.com/bulkdata")
        
        let jsonKey = Tag.pixelData.jsonKey
        guard let inner = element[jsonKey] as? [String: Any] else {
            Issue.record("Expected inner dictionary")
            return
        }
        #expect(inner["BulkDataURI"] as? String == "http://example.com/bulkdata")
    }
    
    @Test("Encode multiple elements")
    func testEncodeMultipleElements() throws {
        let encoder = DICOMJSONEncoder()
        let elements = [
            encoder.element(tag: .patientName, vr: .PN, value: "Doe^John"),
            encoder.element(tag: .patientID, vr: .LO, value: "12345")
        ]
        
        let data = try encoder.encode(elements: elements)
        let json = try JSONSerialization.jsonObject(with: data, options: [])
        
        #expect(json is [[String: Any]])
    }
}
