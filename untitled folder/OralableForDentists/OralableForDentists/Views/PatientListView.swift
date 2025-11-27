import SwiftUI

struct PatientListView: View {
    @EnvironmentObject var dependencies: DentistAppDependencies
    @StateObject private var viewModel: PatientListViewModel

    init() {
        // ViewModel will be properly initialized from environment
        _viewModel = StateObject(wrappedValue: PatientListViewModel(
            dataManager: DentistDataManager.shared,
            subscriptionManager: DentistSubscriptionManager.shared
        ))
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Subscription banner if on free tier
                if viewModel.currentTier == .starter {
                    UpgradeBanner(
                        patientsCount: viewModel.patients.count,
                        maxPatients: viewModel.currentTier.maxPatients
                    )
                }

                // Patient list
                if viewModel.isLoading && viewModel.patients.isEmpty {
                    ProgressView("Loading patients...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.filteredPatients.isEmpty {
                    EmptyPatientsView(showingAddPatient: $viewModel.showingAddPatient)
                } else {
                    List {
                        ForEach(viewModel.filteredPatients) { patient in
                            PatientRow(patient: patient)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    viewModel.selectPatient(patient)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        viewModel.removePatient(patient)
                                    } label: {
                                        Label("Remove", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .listStyle(.plain)
                    .searchable(text: $viewModel.searchText, prompt: "Search patients")
                    .refreshable {
                        await viewModel.refreshPatients()
                    }
                }
            }
            .navigationTitle("My Patients")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        viewModel.showAddPatient()
                    }) {
                        Image(systemName: "plus")
                            .font(.body.weight(.semibold))
                    }
                }
            }
            .sheet(isPresented: $viewModel.showingAddPatient) {
                AddPatientView()
            }
            .sheet(item: $viewModel.selectedPatient) { patient in
                PatientDetailView(patient: patient)
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.clearError()
                }
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
            .onAppear {
                viewModel.loadPatients()
            }
        }
    }
}

// MARK: - Patient Row

struct PatientRow: View {
    let patient: DentistPatient

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(patient.displayName)
                        .font(.headline)

                    Text("Added \(formattedDate(patient.accessGrantedDate))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let lastUpdate = patient.lastDataUpdate {
                Text("Last update: \(formattedDate(lastUpdate))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// MARK: - Empty State

struct EmptyPatientsView: View {
    @Binding var showingAddPatient: Bool

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 80))
                .foregroundColor(.secondary)

            VStack(spacing: 12) {
                Text("No Patients Yet")
                    .font(.title2.bold())

                Text("Add your first patient by entering their share code")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Button(action: {
                showingAddPatient = true
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                    Text("Add Patient")
                }
                .font(.body.weight(.semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.black)
                .cornerRadius(10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Upgrade Banner

struct UpgradeBanner: View {
    let patientsCount: Int
    let maxPatients: Int

    private var isNearLimit: Bool {
        return patientsCount >= maxPatients - 1
    }

    var body: some View {
        if isNearLimit {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Approaching Limit")
                        .font(.subheadline.weight(.semibold))

                    Text("\(patientsCount)/\(maxPatients) patients")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                NavigationLink(destination: UpgradePromptView()) {
                    Text("Upgrade")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.black)
                        .cornerRadius(8)
                }
            }
            .padding()
            .background(Color.orange.opacity(0.1))
        }
    }
}

// MARK: - Preview

#Preview {
    PatientListView()
        .environmentObject(DentistAppDependencies.mock())
}
