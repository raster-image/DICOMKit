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
            
            Section("Presets") {
                Button("Load Default Settings") {
                    loadConfiguration(.default)
                }
                
                Button("Load Orthanc Docker Settings") {
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
            useTLS: useTLS
        )
        
        config.save()
        appState.updateConfiguration(config)
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState())
}
