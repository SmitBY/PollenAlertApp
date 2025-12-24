import SwiftUI
import GRDB
import Charts
import CoreLocation

@Observable
class HistoryViewModel {
    var entries: [DiaryEntry] = []
    var pollenHistory: [PollenHistory] = []
    private let dbManager = DatabaseManager.shared
    private let pollenRepo = PollenRepository.shared
    
    func fetchHistory(for h3Index: String? = nil) async {
        do {
            let fetchedEntries = try await dbManager.dbQueue.read { db in
                try DiaryEntry.order(DiaryEntry.Columns.date.desc).fetchAll(db)
            }
            
            let fetchedPollen: [PollenHistory]
            if let h3Index = h3Index {
                fetchedPollen = try await pollenRepo.getHistory(h3Index: h3Index, limit: 50)
            } else {
                fetchedPollen = try await pollenRepo.getAllHistory(limit: 50)
            }
            
            self.entries = fetchedEntries
            self.pollenHistory = fetchedPollen.sorted(by: { $0.date < $1.date })
        } catch {
            print("Failed to fetch history: \(error)")
        }
    }
}

struct HistoryView: View {
    @State private var viewModel = HistoryViewModel()
    @Environment(\.dismiss) var dismiss
    var currentH3Index: String? = nil
    
    var body: some View {
        NavigationStack {
            List {
                if !viewModel.pollenHistory.isEmpty {
                    Section("Динамика риска") {
                        PollenHistoryChart(history: viewModel.pollenHistory)
                            .frame(height: 200)
                            .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
                    }
                }
                
                Section("Дневник самочувствия") {
                    if viewModel.entries.isEmpty {
                        ContentUnavailableView(
                            "Нет записей",
                            systemImage: "calendar.badge.exclamationmark",
                            description: Text("Ваша история самочувствия появится здесь после первой записи в дневник.")
                        )
                    } else {
                        ForEach(viewModel.entries, id: \.id) { entry in
                            HistoryRow(entry: entry)
                        }
                    }
                }
            }
            .navigationTitle("История")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Закрыть") {
                        dismiss()
                    }
                }
            }
            .task {
                await viewModel.fetchHistory(for: currentH3Index)
            }
        }
    }
}

struct PollenHistoryChart: View {
    let history: [PollenHistory]
    
    var body: some View {
        Chart {
            ForEach(history) { point in
                LineMark(
                    x: .value("Время", point.date),
                    y: .value("Риск", point.riskLevel)
                )
                .foregroundStyle(riskColor(point.riskLevel))
                .interpolationMethod(.monotone) // Более производительная интерполяция
                
                AreaMark(
                    x: .value("Время", point.date),
                    y: .value("Риск", point.riskLevel)
                )
                .foregroundStyle(riskColor(point.riskLevel).opacity(0.1))
                .interpolationMethod(.monotone)
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 6)) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel(format: .dateTime.hour().minute())
            }
        }
        .chartYAxis {
            AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let risk = value.as(Double.self) {
                        Text("\(Int(risk))%")
                    }
                }
            }
        }
        .chartYScale(domain: 0...100)
    }
    
    private func riskColor(_ level: Double) -> Color {
        if level < 25 { return .gray }
        if level < 50 { return .yellow }
        if level < 75 { return .orange }
        return .red
    }
}

struct HistoryRow: View {
    let entry: DiaryEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(feelingEmoji(entry.feelingScore))
                    .font(.title2)
            }
            
            Text("Состояние: \(feelingText(entry.feelingScore))")
                .font(.headline)
            
            if let symptoms = entry.symptoms {
                Text(symptoms)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func feelingEmoji(_ score: Int) -> String {
        switch score {
        case 0: return "😫"
        case 1: return "🙁"
        case 2: return "😐"
        case 3: return "🙂"
        case 4: return "😊"
        case 5: return "🤩"
        default: return "❓"
        }
    }
    
    private func feelingText(_ score: Int) -> String {
        switch score {
        case 0: return "Очень плохо"
        case 1: return "Плохо"
        case 2: return "Так себе"
        case 3: return "Нормально"
        case 4: return "Хорошо"
        case 5: return "Отлично"
        default: return "Неизвестно"
        }
    }
}

#Preview {
    HistoryView()
}
