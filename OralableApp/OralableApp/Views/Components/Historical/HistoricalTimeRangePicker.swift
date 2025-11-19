import SwiftUI

// MARK: - Time Range Picker Component
struct HistoricalTimeRangePicker: View {
    @Binding var selectedRange: TimeRange

    var body: some View {
        HStack(spacing: 30) {
            ForEach([TimeRange.day, TimeRange.week, TimeRange.month], id: \.self) { range in
                Button(action: {
                    selectedRange = range
                }) {
                    Text(range.rawValue)
                        .font(.system(size: 17, weight: selectedRange == range ? .semibold : .regular))
                        .foregroundColor(selectedRange == range ? .blue : .primary)
                }
            }
        }
        .padding(.horizontal)
    }
}
