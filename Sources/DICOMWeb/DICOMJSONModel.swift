import Foundation

/// JSON metadata handling for DICOMweb
///
/// Reference: DICOM PS3.18 Annex F - DICOM JSON Model
///
/// The DICOM JSON Model represents DICOM data elements as a JSON object
/// where the key is the tag in "GGGGEEEE" format and the value contains
/// the VR and the element's value.
public struct DICOMJSONModel: @unchecked Sendable {
    
    /// The raw JSON data
    public let jsonData: Data
    
    /// The parsed JSON object
    public let jsonObject: [[String: Any]]
    
    /// Creates a JSON model from data
    /// - Parameter data: The JSON data
    /// - Throws: DICOMWebError if parsing fails
    public init(data: Data) throws {
        self.jsonData = data
        
        guard let json = try? JSONSerialization.jsonObject(with: data, options: []) else {
            throw DICOMWebError.invalidJSON("Failed to parse JSON data")
        }
        
        // QIDO-RS returns an array of objects
        if let array = json as? [[String: Any]] {
            self.jsonObject = array
        }
        // Metadata retrieval may return a single object
        else if let dict = json as? [String: Any] {
            self.jsonObject = [dict]
        }
        else {
            throw DICOMWebError.invalidJSON("Unexpected JSON structure")
        }
    }
    
    /// Creates a JSON model from a JSON object
    /// - Parameter jsonObject: The parsed JSON object
    public init(jsonObject: [[String: Any]]) throws {
        self.jsonObject = jsonObject
        self.jsonData = try JSONSerialization.data(withJSONObject: jsonObject, options: [])
    }
}

// MARK: - JSON Value Extraction

extension DICOMJSONModel {
    
    /// Extracts a string value from a JSON element
    /// - Parameters:
    ///   - tag: The DICOM tag
    ///   - index: The object index (for arrays)
    /// - Returns: The string value if present
    public func string(for tag: Tag, at index: Int = 0) -> String? {
        guard index < jsonObject.count else { return nil }
        let tagKey = tag.jsonKey
        
        guard let element = jsonObject[index][tagKey] as? [String: Any],
              let value = element["Value"] as? [Any],
              let firstValue = value.first else {
            return nil
        }
        
        if let string = firstValue as? String {
            return string
        }
        if let number = firstValue as? NSNumber {
            return number.stringValue
        }
        return nil
    }
    
    /// Extracts an integer value from a JSON element
    /// - Parameters:
    ///   - tag: The DICOM tag
    ///   - index: The object index (for arrays)
    /// - Returns: The integer value if present
    public func integer(for tag: Tag, at index: Int = 0) -> Int? {
        guard index < jsonObject.count else { return nil }
        let tagKey = tag.jsonKey
        
        guard let element = jsonObject[index][tagKey] as? [String: Any],
              let value = element["Value"] as? [Any],
              let firstValue = value.first else {
            return nil
        }
        
        if let number = firstValue as? Int {
            return number
        }
        if let number = firstValue as? NSNumber {
            return number.intValue
        }
        if let string = firstValue as? String, let intValue = Int(string) {
            return intValue
        }
        return nil
    }
    
    /// Extracts a double value from a JSON element
    /// - Parameters:
    ///   - tag: The DICOM tag
    ///   - index: The object index (for arrays)
    /// - Returns: The double value if present
    public func double(for tag: Tag, at index: Int = 0) -> Double? {
        guard index < jsonObject.count else { return nil }
        let tagKey = tag.jsonKey
        
        guard let element = jsonObject[index][tagKey] as? [String: Any],
              let value = element["Value"] as? [Any],
              let firstValue = value.first else {
            return nil
        }
        
        if let number = firstValue as? Double {
            return number
        }
        if let number = firstValue as? NSNumber {
            return number.doubleValue
        }
        if let string = firstValue as? String, let doubleValue = Double(string) {
            return doubleValue
        }
        return nil
    }
    
    /// Extracts an array of strings from a JSON element
    /// - Parameters:
    ///   - tag: The DICOM tag
    ///   - index: The object index (for arrays)
    /// - Returns: The array of strings if present
    public func strings(for tag: Tag, at index: Int = 0) -> [String]? {
        guard index < jsonObject.count else { return nil }
        let tagKey = tag.jsonKey
        
        guard let element = jsonObject[index][tagKey] as? [String: Any],
              let value = element["Value"] as? [Any] else {
            return nil
        }
        
        return value.compactMap { item -> String? in
            if let string = item as? String {
                return string
            }
            if let number = item as? NSNumber {
                return number.stringValue
            }
            return nil
        }
    }
    
    /// Gets the VR for a tag in the JSON data
    /// - Parameters:
    ///   - tag: The DICOM tag
    ///   - index: The object index (for arrays)
    /// - Returns: The VR if present
    public func vr(for tag: Tag, at index: Int = 0) -> String? {
        guard index < jsonObject.count else { return nil }
        let tagKey = tag.jsonKey
        
        guard let element = jsonObject[index][tagKey] as? [String: Any],
              let vr = element["vr"] as? String else {
            return nil
        }
        
        return vr
    }
    
    /// Gets the bulk data URI for a tag
    /// - Parameters:
    ///   - tag: The DICOM tag
    ///   - index: The object index (for arrays)
    /// - Returns: The bulk data URI if present
    public func bulkDataURI(for tag: Tag, at index: Int = 0) -> String? {
        guard index < jsonObject.count else { return nil }
        let tagKey = tag.jsonKey
        
        guard let element = jsonObject[index][tagKey] as? [String: Any],
              let bulkDataURI = element["BulkDataURI"] as? String else {
            return nil
        }
        
        return bulkDataURI
    }
    
    /// The number of items in the JSON array
    public var count: Int {
        jsonObject.count
    }
}

// MARK: - Tag JSON Key Extension

extension Tag {
    
    /// The JSON key for this tag (GGGGEEEE format)
    public var jsonKey: String {
        String(format: "%04X%04X", group, element)
    }
    
    /// Creates a tag from a JSON key (GGGGEEEE format)
    /// - Parameter jsonKey: The JSON key string
    /// - Returns: The tag if parsing succeeds
    public static func fromJSONKey(_ jsonKey: String) -> Tag? {
        guard jsonKey.count == 8,
              let group = UInt16(jsonKey.prefix(4), radix: 16),
              let element = UInt16(jsonKey.suffix(4), radix: 16) else {
            return nil
        }
        return Tag(group: group, element: element)
    }
}

// MARK: - JSON Encoding

/// Helper for creating DICOM JSON representations
public struct DICOMJSONEncoder: Sendable {
    
    public init() {}
    
    /// Creates a JSON element for a string value
    /// - Parameters:
    ///   - tag: The DICOM tag
    ///   - vr: The Value Representation
    ///   - value: The string value
    /// - Returns: A dictionary representing the JSON element
    public func element(tag: Tag, vr: VR, value: String) -> [String: Any] {
        [
            tag.jsonKey: [
                "vr": vr.rawValue,
                "Value": [value]
            ]
        ]
    }
    
    /// Creates a JSON element for multiple string values
    /// - Parameters:
    ///   - tag: The DICOM tag
    ///   - vr: The Value Representation
    ///   - values: The string values
    /// - Returns: A dictionary representing the JSON element
    public func element(tag: Tag, vr: VR, values: [String]) -> [String: Any] {
        [
            tag.jsonKey: [
                "vr": vr.rawValue,
                "Value": values
            ]
        ]
    }
    
    /// Creates a JSON element for an integer value
    /// - Parameters:
    ///   - tag: The DICOM tag
    ///   - vr: The Value Representation
    ///   - value: The integer value
    /// - Returns: A dictionary representing the JSON element
    public func element(tag: Tag, vr: VR, value: Int) -> [String: Any] {
        [
            tag.jsonKey: [
                "vr": vr.rawValue,
                "Value": [value]
            ]
        ]
    }
    
    /// Creates a JSON element for a double value
    /// - Parameters:
    ///   - tag: The DICOM tag
    ///   - vr: The Value Representation
    ///   - value: The double value
    /// - Returns: A dictionary representing the JSON element
    public func element(tag: Tag, vr: VR, value: Double) -> [String: Any] {
        [
            tag.jsonKey: [
                "vr": vr.rawValue,
                "Value": [value]
            ]
        ]
    }
    
    /// Creates a JSON element with a bulk data URI
    /// - Parameters:
    ///   - tag: The DICOM tag
    ///   - vr: The Value Representation
    ///   - uri: The bulk data URI
    /// - Returns: A dictionary representing the JSON element
    public func bulkDataElement(tag: Tag, vr: VR, uri: String) -> [String: Any] {
        [
            tag.jsonKey: [
                "vr": vr.rawValue,
                "BulkDataURI": uri
            ]
        ]
    }
    
    /// Encodes an array of DICOM JSON elements to data
    /// - Parameter elements: Array of JSON element dictionaries
    /// - Returns: The encoded JSON data
    /// - Throws: DICOMWebError if encoding fails
    public func encode(elements: [[String: Any]]) throws -> Data {
        // Merge all elements into a single object
        var merged: [String: Any] = [:]
        for element in elements {
            for (key, value) in element {
                merged[key] = value
            }
        }
        
        guard let data = try? JSONSerialization.data(withJSONObject: [merged], options: [.prettyPrinted]) else {
            throw DICOMWebError.internalError("Failed to encode JSON")
        }
        
        return data
    }
}
