//
//  AddPatientView.swift
//  OralableForDentists
//
//  Apple style - matches OralableApp
//

import SwiftUI

struct AddPatientView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var dataManager: DentistDataManager
    @EnvironmentObject var designSystem: DesignSystem

    @State private var shareCode = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSuccess = false

    @FocusState private var isCodeFieldFocused: Bool

    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    VStack(spacing: 16) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 60))
                            .foregroundColor(.black)

                        Text("Add a Patient")
                            .font(.title2.bold())

                        Text("Enter the 6-digit share code provided by your patient")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .padding(.top, 40)

                    VStack(spacing: 16) {
                        ShareCodeField(code: $shareCode)
                            .focused($isCodeFieldFocused)

                        if let error = errorMessage {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundColor(.red)
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    .padding(.horizontal, 24)

                    Spacer()

                    Button(action: addPatient) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Add Patient")
                            }
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(isValidCode ? Color.black : Color.gray)
                        .cornerRadius(12)
                    }
                    .disabled(!isValidCode || isLoading)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Add Patient")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                isCodeFieldFocused = true
            }
            .alert("Patient Added", isPresented: $showSuccess) {
                Button("Done") {
                    dismiss()
                }
            } message: {
                Text("You can now view this patient's bruxism data.")
            }
        }
    }

    private var isValidCode: Bool {
        shareCode.count == 6 && Int(shareCode) != nil
    }

    private func addPatient() {
        guard isValidCode else { return }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                try await dataManager.addPatientWithShareCode(shareCode)
                showSuccess = true
            } catch let error as DentistDataError {
                errorMessage = error.localizedDescription
            } catch {
                errorMessage = "Failed to add patient. Please try again."
            }
            isLoading = false
        }
    }
}

struct ShareCodeField: View {
    @Binding var code: String

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                ForEach(0..<6, id: \.self) { index in
                    CodeDigitBox(
                        digit: getDigit(at: index),
                        isActive: index == code.count
                    )
                }
            }

            TextField("", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .onChange(of: code) { _, newValue in
                    if newValue.count > 6 {
                        code = String(newValue.prefix(6))
                    }
                    code = newValue.filter { $0.isNumber }
                }
                .frame(width: 0, height: 0)
                .opacity(0)
        }
    }

    private func getDigit(at index: Int) -> String {
        guard index < code.count else { return "" }
        return String(code[code.index(code.startIndex, offsetBy: index)])
    }
}

struct CodeDigitBox: View {
    let digit: String
    let isActive: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .stroke(isActive ? Color.black : Color(UIColor.systemGray4), lineWidth: isActive ? 2 : 1)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(UIColor.systemBackground))
                )

            Text(digit)
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
        }
        .frame(width: 48, height: 56)
    }
}
