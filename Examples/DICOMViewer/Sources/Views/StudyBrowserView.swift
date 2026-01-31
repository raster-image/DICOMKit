import SwiftUI

/// View for browsing and searching DICOM studies
struct StudyBrowserView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = StudyBrowserViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            SearchBar(
                searchText: $viewModel.searchText,
                isSearching: viewModel.isLoading,
                onSearch: {
                    Task {
                        await viewModel.search(using: appState.pacsService)
                    }
                }
            )
            .padding()
            
            Divider()
            
            // Results
            if viewModel.isLoading {
                Spacer()
                ProgressView("Searching...")
                Spacer()
            } else if let error = viewModel.errorMessage {
                Spacer()
                ContentUnavailableView {
                    Label("Search Failed", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                } actions: {
                    Button("Try Again") {
                        Task {
                            await viewModel.search(using: appState.pacsService)
                        }
                    }
                }
                Spacer()
            } else if viewModel.studies.isEmpty && viewModel.hasSearched {
                Spacer()
                ContentUnavailableView {
                    Label("No Studies Found", systemImage: "magnifyingglass")
                } description: {
                    Text("Try adjusting your search criteria")
                }
                Spacer()
            } else if viewModel.studies.isEmpty {
                Spacer()
                ContentUnavailableView {
                    Label("Search for Studies", systemImage: "magnifyingglass")
                } description: {
                    Text("Enter a patient name or ID to search")
                }
                Spacer()
            } else {
                StudyListView(
                    studies: viewModel.studies,
                    selectedStudy: $viewModel.selectedStudy
                )
            }
        }
        .navigationTitle("Study Browser")
        .sheet(item: $viewModel.selectedStudy) { study in
            NavigationStack {
                SeriesListView(study: study)
                    .environmentObject(appState)
            }
        }
    }
}

/// Search bar component
struct SearchBar: View {
    @Binding var searchText: String
    let isSearching: Bool
    let onSearch: () -> Void
    
    var body: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Patient name or ID...", text: $searchText)
                    .textFieldStyle(.plain)
                    .onSubmit(onSearch)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(.systemGray6))
            .cornerRadius(8)
            
            Button(action: onSearch) {
                Text("Search")
            }
            .buttonStyle(.borderedProminent)
            .disabled(searchText.isEmpty || isSearching)
        }
    }
}

/// List of studies
struct StudyListView: View {
    let studies: [StudyItem]
    @Binding var selectedStudy: StudyItem?
    
    var body: some View {
        List(studies) { study in
            StudyRowView(study: study)
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedStudy = study
                }
        }
        .listStyle(.plain)
    }
}

/// Row view for a single study
struct StudyRowView: View {
    let study: StudyItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(study.displayPatientName)
                    .font(.headline)
                Spacer()
                if let modalities = study.modalities {
                    Text(modalities)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(4)
                }
            }
            
            HStack {
                if let patientID = study.patientID {
                    Label(patientID, systemImage: "person")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Label(study.displayDate, systemImage: "calendar")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if let description = study.studyDescription, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            HStack {
                if let series = study.numberOfSeries {
                    Text("\(series) series")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                if let instances = study.numberOfInstances {
                    Text("• \(instances) images")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

/// View model for study browser
@MainActor
class StudyBrowserViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published var studies: [StudyItem] = []
    @Published var selectedStudy: StudyItem?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var hasSearched: Bool = false
    
    func search(using service: PACSService) async {
        guard !searchText.isEmpty else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Try searching by patient name first, then by ID
            studies = try await service.searchStudies(patientName: searchText)
            
            if studies.isEmpty {
                // Try searching by patient ID
                studies = try await service.searchStudies(patientID: searchText)
            }
            
            hasSearched = true
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}

#Preview {
    StudyBrowserView()
        .environmentObject(AppState())
}
