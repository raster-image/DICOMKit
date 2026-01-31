import SwiftUI

/// Settings view for configuring PACS connection
struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    
    @State private var host: String = ""
    @State private var port: String = ""
    @State private var callingAE: String = ""
    @State private var calledAE: String = ""
    @State private var timeout: String = ""
    @State private var useTLS: Bool = false
    @State private var dicomWebURL: String = ""
    @State private var wadoURIURL: String = ""
    
    var body: some View {
        Form {
            Section("PACS Server") {
                TextField("Host", text: $host)
                    #if os(iOS)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                    #endif
                
                TextField("Port", text: $port)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
            }
            
            Section("Application Entities") {
                TextField("Calling AE Title (Your App)", text: $callingAE)
                    #if os(iOS)
                    .autocapitalization(.allCharacters)
                    #endif
                
                TextField("Called AE Title (PACS)", text: $calledAE)
                    #if os(iOS)
                    .autocapitalization(.allCharacters)
                    #endif
            }
            
            Section("Connection") {
                TextField("Timeout (seconds)", text: $timeout)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
                
                Toggle("Use TLS", isOn: $useTLS)
            }
            
            Section("DICOMweb (Optional)") {
                TextField("DICOMweb URL", text: $dicomWebURL)
                    .textContentType(.URL)
                    #if os(iOS)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                    #endif
                
                TextField("WADO-URI URL", text: $wadoURIURL)
                    .textContentType(.URL)
                    #if os(iOS)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                    #endif
            }
            
            Section("Presets") {
                Button("Load TEAMPACS (Default)") {
                    loadConfiguration(.default)
                }
                
                Button("Load Orthanc Local") {
                    loadConfiguration(.orthancLocal)
                }
                
                Button("Load Orthanc Docker") {
                    loadConfiguration(.orthancDocker)
                }
            }
            
            Section {
                Button("Save Configuration") {
                    saveConfiguration()
                }
                .disabled(!isValid)
            }
        }
        .navigationTitle("Settings")
        .onAppear {
            loadConfiguration(appState.pacsConfiguration)
        }
    }
    
    private var isValid: Bool {
        !host.isEmpty &&
        !port.isEmpty &&
        UInt16(port) != nil &&
        !callingAE.isEmpty &&
        !calledAE.isEmpty &&
        !timeout.isEmpty &&
        Double(timeout) != nil
    }
    
    private func loadConfiguration(_ config: PACSConfiguration) {
        host = config.host
        port = String(config.port)
        callingAE = config.callingAETitle
        calledAE = config.calledAETitle
        timeout = String(Int(config.timeout))
        useTLS = config.useTLS
        dicomWebURL = config.dicomWebURL ?? ""
        wadoURIURL = config.wadoURIURL ?? ""
    }
    
    private func saveConfiguration() {
        guard let portValue = UInt16(port),
              let timeoutValue = Double(timeout) else {
            return
        }
        
        let config = PACSConfiguration(
            host: host,
            port: portValue,
            callingAETitle: callingAE,
            calledAETitle: calledAE,
            timeout: timeoutValue,
            useTLS: useTLS,
            dicomWebURL: dicomWebURL.isEmpty ? nil : dicomWebURL,
            wadoURIURL: wadoURIURL.isEmpty ? nil : wadoURIURL
        )
        
        config.save()
        appState.updateConfiguration(config)
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState())
}
