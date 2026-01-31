import Foundation

/// Configuration for connecting to a PACS server
struct PACSConfiguration: Codable, Equatable {
    /// PACS server hostname or IP address
    var host: String
    
    /// PACS server port
    var port: UInt16
    
    /// Local Application Entity title (your app's identifier)
    var callingAETitle: String
    
    /// Remote Application Entity title (PACS server's identifier)
    var calledAETitle: String
    
    /// Connection timeout in seconds
    var timeout: TimeInterval
    
    /// Whether to use TLS encryption
    var useTLS: Bool
    
    /// DICOMweb URL (optional, for WADO-RS/STOW-RS/QIDO-RS)
    var dicomWebURL: String?
    
    /// WADO-URI URL (optional, for legacy WADO retrieval)
    var wadoURIURL: String?
    
    /// Default configuration for TEAMPACS server
    /// Note: The IP address and AE titles are based on the provided PACS configuration.
    /// These can be modified in the Settings view at runtime.
    static let `default` = PACSConfiguration(
        host: "117.247.185.219",
        port: 11112,
        callingAETitle: "MAYAM",
        calledAETitle: "TEAMPACS",
        timeout: 30,
        useTLS: false,
        dicomWebURL: nil,
        wadoURIURL: nil  // Contact your PACS administrator if WADO-URI is supported
    )
    
    /// Configuration for local Orthanc development server
    static let orthancLocal = PACSConfiguration(
        host: "localhost",
        port: 11112,
        callingAETitle: "DICOM_VIEWER",
        calledAETitle: "ORTHANC",
        timeout: 30,
        useTLS: false,
        dicomWebURL: nil,
        wadoURIURL: nil
    )
    
    /// Configuration for Orthanc running in Docker
    static let orthancDocker = PACSConfiguration(
        host: "localhost",
        port: 4242,
        callingAETitle: "DICOM_VIEWER",
        calledAETitle: "ORTHANC",
        timeout: 30,
        useTLS: false,
        dicomWebURL: "http://localhost:8042/dicom-web",
        wadoURIURL: "http://localhost:8042/wado"
    )
}

// MARK: - UserDefaults Storage

extension PACSConfiguration {
    private static let userDefaultsKey = "PACSConfiguration"
    
    /// Saves the configuration to UserDefaults
    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.userDefaultsKey)
        }
    }
    
    /// Loads the configuration from UserDefaults
    static func load() -> PACSConfiguration {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let config = try? JSONDecoder().decode(PACSConfiguration.self, from: data) else {
            return .default
        }
        return config
    }
}
