import SwiftUI

/// Main content view with navigation
struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingSettings = false
    
    var body: some View {
        NavigationSplitView {
            SidebarView()
        } detail: {
            StudyBrowserView()
        }
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingSettings = true }) {
                    Image(systemName: "gear")
                }
            }
            #endif
        }
        #if os(iOS)
        .sheet(isPresented: $showingSettings) {
            NavigationStack {
                SettingsView()
                    .environmentObject(appState)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                showingSettings = false
                            }
                        }
                    }
            }
        }
        #endif
    }
}

/// Sidebar with connection status and navigation
struct SidebarView: View {
    @EnvironmentObject var appState: AppState
    @State private var isTestingConnection = false
    @State private var connectionMessage: String?
    
    var body: some View {
        List {
            // Connection Status Section
            Section("PACS Connection") {
                HStack {
                    Circle()
                        .fill(appState.isConnected ? Color.green : Color.red)
                        .frame(width: 10, height: 10)
                    Text(appState.isConnected ? "Connected" : "Not Connected")
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(appState.pacsConfiguration.host)
                        .font(.caption)
                    Text("Port: \(appState.pacsConfiguration.port)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("AE: \(appState.pacsConfiguration.calledAETitle)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Button(action: testConnection) {
                    HStack {
                        if isTestingConnection {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        Text(isTestingConnection ? "Testing..." : "Test Connection")
                    }
                }
                .disabled(isTestingConnection)
                
                if let message = connectionMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundColor(appState.isConnected ? .green : .red)
                }
            }
            
            // Navigation Section
            Section("Browse") {
                NavigationLink(destination: StudyBrowserView()) {
                    Label("Studies", systemImage: "folder")
                }
            }
            
            // Quick Actions
            Section("Actions") {
                NavigationLink(destination: QueryView()) {
                    Label("Advanced Search", systemImage: "magnifyingglass")
                }
            }
        }
        .navigationTitle("DICOM Viewer")
        #if os(macOS)
        .listStyle(.sidebar)
        #endif
    }
    
    private func testConnection() {
        isTestingConnection = true
        connectionMessage = nil
        
        Task {
            do {
                let success = try await appState.pacsService.verifyConnection()
                await MainActor.run {
                    appState.isConnected = success
                    connectionMessage = success ? "C-ECHO successful!" : "C-ECHO failed"
                    isTestingConnection = false
                }
            } catch {
                await MainActor.run {
                    appState.isConnected = false
                    connectionMessage = "Error: \(error.localizedDescription)"
                    appState.connectionError = error.localizedDescription
                    isTestingConnection = false
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
