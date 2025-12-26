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
                fetchedPollen = try await pollenRepo.getHistory(h3Index: h3Index, limit: 168)
            } else {
                fetchedPollen = try await pollenRepo.getAllHistory(limit: 168)
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
                            .frame(height: 170)
                            .listRowInsets(EdgeInsets(top: 16, leading: 8, bottom: 0, trailing: 8))
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
    
    private var dateRange: ClosedRange<Date>? {
        guard let last = history.last?.date else { return nil }
        let start = last.addingTimeInterval(-24 * 3600)
        return start...last
    }
    
    private var axisDates: [Date] {
        guard let range = dateRange else { return [] }
        let calendar = Calendar.current
        
        // Берем последний доступный час (округленный вниз)
        var components = calendar.dateComponents([.year, .month, .day, .hour], from: range.upperBound)
        components.minute = 0
        components.second = 0
        let lastHour = calendar.date(from: components) ?? range.upperBound
        
        var dates: [Date] = []
        var current = lastHour
        
        // Идем назад на 24 часа с шагом 2 часа
        for _ in 0...12 {
            if current >= range.lowerBound.addingTimeInterval(-60) {
                dates.append(current)
            }
            guard let prev = calendar.date(byAdding: .hour, value: -2, to: current) else { break }
            current = prev
        }
        
        return dates.sorted()
    }
    
    private var yDomain: ClosedRange<Double> {
        let minRisk = history.map { $0.riskLevel }.min() ?? 0
        let maxRisk = history.map { $0.riskLevel }.max() ?? 0
        if minRisk == 0 && maxRisk == 0 {
            return -2...100
        }
        return min(0, minRisk - 5)...max(100, maxRisk + 5)
    }
    
    var body: some View {
        Chart {
            ForEach(history) { point in
                LineMark(
                    x: .value("Время", point.date),
                    y: .value("Риск", point.riskLevel)
                )
                .foregroundStyle(riskColor(point.riskLevel))
                .lineStyle(StrokeStyle(lineWidth: 3))
                .interpolationMethod(.monotone)
                
                PointMark(
                    x: .value("Время", point.date),
                    y: .value("Риск", point.riskLevel)
                )
                .foregroundStyle(riskColor(point.riskLevel))
                .symbolSize(10)
                
                AreaMark(
                    x: .value("Время", point.date),
                    y: .value("Риск", point.riskLevel)
                )
                .foregroundStyle(riskColor(point.riskLevel).opacity(0.1))
                .interpolationMethod(.monotone)
            }
        }
        .chartXAxis {
            AxisMarks(values: axisDates) { value in
                if let date = value.as(Date.self) {
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.primary.opacity(0.1))
                    AxisValueLabel(anchor: .top) {
                        Text(date.formatted(.dateTime.hour()))
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.primary.opacity(0.1))
                AxisValueLabel {
                    if let risk = value.as(Double.self) {
                        Text("\(Int(risk))%")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .chartXScale(domain: dateRange ?? (Date()...Date()))
        .chartYScale(domain: yDomain)
        .padding(.horizontal, 4) // Уменьшили отступ по бокам
        .environment(\.timeZone, TimeZone.current)
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

