import Foundation

/// Represents a patient in the viewer
struct PatientItem: Identifiable, Hashable {
    let id: String
    let name: String
    let birthDate: String?
    let sex: String?
    
    var displayName: String {
        // Convert DICOM format (LAST^FIRST^MIDDLE) to readable format
        name.replacingOccurrences(of: "^", with: " ").trimmingCharacters(in: .whitespaces)
    }
}

/// Represents a study in the viewer
struct StudyItem: Identifiable, Hashable {
    let id: String  // Study Instance UID
    let patientName: String
    let patientID: String?
    let studyDate: String?
    let studyTime: String?
    let studyDescription: String?
    let modalities: String?
    let accessionNumber: String?
    let numberOfSeries: Int?
    let numberOfInstances: Int?
    
    var displayDate: String {
        guard let date = studyDate, date.count >= 8 else {
            return studyDate ?? "Unknown"
        }
        // Convert YYYYMMDD to YYYY-MM-DD
        let year = date.prefix(4)
        let month = date.dropFirst(4).prefix(2)
        let day = date.dropFirst(6).prefix(2)
        return "\(year)-\(month)-\(day)"
    }
    
    var displayPatientName: String {
        patientName.replacingOccurrences(of: "^", with: " ").trimmingCharacters(in: .whitespaces)
    }
}

/// Represents a series in the viewer
struct SeriesItem: Identifiable, Hashable {
    let id: String  // Series Instance UID
    let studyInstanceUID: String
    let seriesNumber: Int?
    let modality: String?
    let seriesDescription: String?
    let numberOfInstances: Int?
    let bodyPart: String?
    
    var displayDescription: String {
        if let desc = seriesDescription, !desc.isEmpty {
            return desc
        }
        if let modality = modality {
            return "\(modality) Series"
        }
        return "Series \(seriesNumber ?? 0)"
    }
}

/// Represents an instance (image) in the viewer
struct InstanceItem: Identifiable, Hashable {
    let id: String  // SOP Instance UID
    let studyInstanceUID: String
    let seriesInstanceUID: String
    let instanceNumber: Int?
    let sopClassUID: String?
    
    var displayNumber: String {
        "Image \(instanceNumber ?? 0)"
    }
}
