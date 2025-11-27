import SwiftUI

struct AddPatientView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel: AddPatientViewModel
    @FocusState private var isTextFieldFocused: Bool

    init() {
        _viewModel = StateObject(wrappedValue: AddPatientViewModel(
            dataManager: DentistDataManager.shared,
            subscriptionManager: DentistSubscriptionManager.shared
        ))
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "qrcode")
                        .font(.system(size: 60))
                        .foregroundColor(.black)
                        .padding(.top, 40)

                    Text("Add Patient")
                        .font(.title.bold())

                    Text("Enter the 6-digit share code provided by your patient")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }

                // Share code input
                VStack(spacing: 16) {
                    ShareCodeTextField(text: $viewModel.shareCode)
                        .focused($isTextFieldFocused)
                        .onChange(of: viewModel.shareCode) { oldValue, newValue in
                            viewModel.shareCode = viewModel.formatShareCode(newValue)
                        }

                    HStack(spacing: 8) {
                        Image(systemName: viewModel.isShareCodeValid ? "checkmark.circle.fill" : "info.circle")
                            .foregroundColor(viewModel.isShareCodeValid ? .green : .secondary)

                        Text(viewModel.isShareCodeValid ? "Valid code format" : "Code must be 6 digits")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // Instructions
                VStack(alignment: .leading, spacing: 12) {
                    InstructionRow(
                        icon: "1.circle.fill",
                        text: "Patient generates share code in their Oralable app"
                    )

                    InstructionRow(
                        icon: "2.circle.fill",
                        text: "Patient shares the 6-digit code with you"
                    )

                    InstructionRow(
                        icon: "3.circle.fill",
                        text: "Enter the code above to access their data"
                    )
                }
                .padding(.horizontal, 24)

                Spacer()

                // Add button
                Button(action: {
                    viewModel.addPatient()
                }) {
                    if viewModel.isAdding {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.black)
                            .cornerRadius(12)
                    } else {
                        Text("Add Patient")
                            .font(.body.weight(.semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(viewModel.canAddPatient ? Color.black : Color.gray)
                            .cornerRadius(12)
                    }
                }
                .disabled(!viewModel.canAddPatient)
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.clearMessages() } }
            )) {
                Button("OK") {
                    viewModel.clearMessages()
                }
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
            .alert("Success", isPresented: Binding(
                get: { viewModel.successMessage != nil },
                set: { if !$0 { viewModel.clearMessages(); dismiss() } }
            )) {
                Button("OK") {
                    viewModel.clearMessages()
                    dismiss()
                }
            } message: {
                if let success = viewModel.successMessage {
                    Text(success)
                }
            }
            .onChange(of: viewModel.shouldDismiss) { _, shouldDismiss in
                if shouldDismiss {
                    dismiss()
                }
            }
            .onAppear {
                isTextFieldFocused = true
            }
        }
    }
}

// MARK: - Share Code Text Field

struct ShareCodeTextField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<6, id: \.self) { index in
                DigitBox(digit: getDigit(at: index))
            }
        }
        .overlay {
            // Invisible TextField to capture input
            TextField("", text: $text)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .foregroundColor(.clear)
                .accentColor(.clear)
                .background(Color.clear)
        }
    }

    private func getDigit(at index: Int) -> String? {
        guard index < text.count else { return nil }
        let digitIndex = text.index(text.startIndex, offsetBy: index)
        return String(text[digitIndex])
    }
}

struct DigitBox: View {
    let digit: String?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .stroke(digit != nil ? Color.black : Color.gray.opacity(0.3), lineWidth: 2)
                .frame(width: 50, height: 60)

            if let digit = digit {
                Text(digit)
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .foregroundColor(.black)
            }
        }
    }
}

// MARK: - Instruction Row

struct InstructionRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(.black)
                .frame(width: 24)

            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)

            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    AddPatientView()
}
