import SwiftUI

/// Advanced query view with multiple search criteria
struct QueryView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = QueryViewModel()
    
    var body: some View {
        Form {
            Section("Patient Information") {
                TextField("Patient Name", text: $viewModel.patientName)
                    .textContentType(.name)
                TextField("Patient ID", text: $viewModel.patientID)
            }
            
            Section("Study Information") {
                TextField("Accession Number", text: $viewModel.accessionNumber)
                
                DatePicker(
                    "Study Date From",
                    selection: $viewModel.studyDateFrom,
                    displayedComponents: .date
                )
                
                DatePicker(
                    "Study Date To",
                    selection: $viewModel.studyDateTo,
                    displayedComponents: .date
                )
                
                Picker("Modality", selection: $viewModel.selectedModality) {
                    Text("Any").tag(nil as String?)
                    ForEach(viewModel.modalities, id: \.self) { modality in
                        Text(modality).tag(modality as String?)
                    }
                }
            }
            
            Section {
                Button(action: {
                    Task {
                        await viewModel.search(using: appState.pacsService)
                    }
                }) {
                    HStack {
                        Spacer()
                        if viewModel.isLoading {
                            ProgressView()
                        } else {
                            Text("Search")
                        }
                        Spacer()
                    }
                }
                .disabled(viewModel.isLoading || !viewModel.hasValidCriteria)
                
                Button("Clear", role: .destructive) {
                    viewModel.clear()
                }
            }
            
            if !viewModel.results.isEmpty {
                Section("Results (\(viewModel.results.count) studies)") {
                    ForEach(viewModel.results) { study in
                        NavigationLink(destination: SeriesListView(study: study).environmentObject(appState)) {
                            StudyRowView(study: study)
                        }
                    }
                }
            } else if viewModel.hasSearched {
                Section {
                    Text("No studies found matching your criteria")
                        .foregroundColor(.secondary)
                }
            }
            
            if let error = viewModel.errorMessage {
                Section {
                    Text(error)
                        .foregroundColor(.red)
                }
            }
        }
        .navigationTitle("Advanced Search")
    }
}

/// View model for advanced query
@MainActor
class QueryViewModel: ObservableObject {
    @Published var patientName: String = ""
    @Published var patientID: String = ""
    @Published var accessionNumber: String = ""
    @Published var studyDateFrom: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @Published var studyDateTo: Date = Date()
    @Published var selectedModality: String?
    
    @Published var results: [StudyItem] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var hasSearched: Bool = false
    
    let modalities = ["CT", "MR", "CR", "DX", "US", "XA", "NM", "PT", "MG", "RF"]
    
    var hasValidCriteria: Bool {
        !patientName.isEmpty || !patientID.isEmpty || !accessionNumber.isEmpty || selectedModality != nil
    }
    
    func search(using service: PACSService) async {
        isLoading = true
        errorMessage = nil
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        
        let dateRange = "\(dateFormatter.string(from: studyDateFrom))-\(dateFormatter.string(from: studyDateTo))"
        
        do {
            results = try await service.searchStudies(
                patientName: patientName.isEmpty ? nil : patientName,
                patientID: patientID.isEmpty ? nil : patientID,
                studyDate: dateRange,
                modality: selectedModality,
                accessionNumber: accessionNumber.isEmpty ? nil : accessionNumber
            )
            hasSearched = true
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func clear() {
        patientName = ""
        patientID = ""
        accessionNumber = ""
        studyDateFrom = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        studyDateTo = Date()
        selectedModality = nil
        results = []
        errorMessage = nil
        hasSearched = false
    }
}

#Preview {
    NavigationStack {
        QueryView()
            .environmentObject(AppState())
    }
}
