//
//  PatientListView.swift
//  OralableForDentists
//
//  Apple Health Style - matches OralableApp
//

import SwiftUI

struct PatientListView: View {
    @EnvironmentObject var dependencies: DentistAppDependencies
    @StateObject private var viewModel: PatientListViewModel

    init() {
        _viewModel = StateObject(wrappedValue: PatientListViewModel(
            dataManager: DentistDataManager.shared,
            subscriptionManager: DentistSubscriptionManager.shared
        ))
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    if viewModel.currentTier == .starter {
                        upgradeBanner
                    }

                    if viewModel.isLoading && viewModel.patients.isEmpty {
                        LoadingView(message: "Loading patients...")
                    } else if viewModel.filteredPatients.isEmpty {
                        EmptyStateView(
                            icon: "person.2.slash",
                            title: "No Patients Yet",
                            message: "Add your first patient by entering their share code",
                            buttonTitle: "Add Patient",
                            buttonAction: { viewModel.showAddPatient() }
                        )
                    } else {
                        patientList
                    }
                }
            }
            .navigationTitle("My Patients")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { viewModel.showAddPatient() }) {
                        Image(systemName: "plus")
                            .font(.body.weight(.semibold))
                    }
                }
            }
            .searchable(text: $viewModel.searchText, prompt: "Search patients")
            .sheet(isPresented: $viewModel.showingAddPatient) {
                AddPatientView()
            }
            .sheet(item: $viewModel.selectedPatient) { patient in
                PatientDetailView(patient: patient)
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { viewModel.clearError() }
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
            .onAppear {
                viewModel.loadPatients()
            }
        }
        .navigationViewStyle(.stack)
    }

    private var patientList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.filteredPatients) { patient in
                    PatientRowCard(patient: patient)
                        .onTapGesture {
                            viewModel.selectPatient(patient)
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                viewModel.removePatient(patient)
                            } label: {
                                Label("Remove Patient", systemImage: "trash")
                            }
                        }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
        .refreshable {
            await viewModel.refreshPatients()
        }
    }

    private var upgradeBanner: some View {
        Group {
            if viewModel.patients.count >= viewModel.currentTier.maxPatients - 1 {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Approaching Limit")
                            .font(.subheadline.weight(.semibold))

                        Text("\(viewModel.patients.count)/\(viewModel.currentTier.maxPatients) patients")
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
}

struct PatientRowCard: View {
    let patient: DentistPatient

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.blue)

                    Text("Patient")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(UIColor.tertiaryLabel))
            }

            Text(patient.displayName)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primary)

            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Text("Added \(formattedDate(patient.accessGrantedDate))")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                if let lastUpdate = patient.lastDataUpdate {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Text("Updated \(relativeDate(lastUpdate))")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
