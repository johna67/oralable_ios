//
//  PatientDetailView.swift
//  OralableForProfessionals
//
//  Patient detail - now shows full dashboard with historical navigation
//

import SwiftUI

struct PatientDetailView: View {
    let patient: ProfessionalPatient
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            PatientDashboardView(patient: patient)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Done") { dismiss() }
                    }
                }
        }
    }
}

// MARK: - Preview

#Preview {
    PatientDetailView(patient: ProfessionalPatient(
        id: "1",
        patientID: "patient123",
        patientName: "John Doe",
        shareCode: "123456",
        accessGrantedDate: Date(),
        lastDataUpdate: Date(),
        recordID: "record1"
    ))
    .environmentObject(DesignSystem())
}
