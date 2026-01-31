import SwiftUI

/// DICOM Viewer Example Application
///
/// A sample application demonstrating how to use DICOMKit to:
/// - Connect to a PACS server
/// - Query for patients, studies, and series
/// - Retrieve and display DICOM images
@main
struct DICOMViewerApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
        #if os(macOS)
        .windowStyle(.automatic)
        .defaultSize(width: 1200, height: 800)
        
        Settings {
            SettingsView()
                .environmentObject(appState)
        }
        #endif
    }
}

/// Global application state
@MainActor
class AppState: ObservableObject {
    @Published var pacsConfiguration: PACSConfiguration = .default
    @Published var isConnected: Bool = false
    @Published var connectionError: String?
    
    lazy var pacsService: PACSService = PACSService(configuration: pacsConfiguration)
    
    func updateConfiguration(_ config: PACSConfiguration) {
        pacsConfiguration = config
        pacsService = PACSService(configuration: config)
        isConnected = false
        connectionError = nil
    }
}
