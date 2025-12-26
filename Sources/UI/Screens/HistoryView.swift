import SwiftUI
import GRDB
import Charts
import CoreLocation

@Observable
@MainActor
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
            
            // Сразу обновляем записи дневника, чтобы они не ждали загрузки пыльцы
            self.entries = fetchedEntries
            print("📜 Загружено записей дневника: \(fetchedEntries.count)")
            
            var fetchedPollen: [PollenHistory]
            if let h3Index = h3Index {
                fetchedPollen = try await pollenRepo.getHistory(h3Index: h3Index, limit: 500)
            } else {
                fetchedPollen = try await pollenRepo.getAllHistory(limit: 500)
            }
            
            // Сортируем и фильтруем микро-дубликаты (менее 1 минуты), которые ломают интерполяцию
            let sorted = fetchedPollen.sorted(by: { $0.date < $1.date })
            var filtered: [PollenHistory] = []
            for point in sorted {
                if let last = filtered.last {
                    if abs(point.date.timeIntervalSince(last.date)) >= 60.0 {
                        filtered.append(point)
                    } else if point.date == sorted.last?.date {
                        // Всегда оставляем самую последнюю точку
                        filtered.removeLast()
                        filtered.append(point)
                    }
                } else {
                    filtered.append(point)
                }
            }
            
            self.pollenHistory = filtered
            
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
                        ForEach(viewModel.entries) { entry in
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
        let now = Date()
        let start = now.addingTimeInterval(-24 * 3600)
        let end = now
        
        return start...end
    }
    
    private var axisDates: [Date] {
        guard let range = dateRange else { return [] }
        
        var dates: [Date] = []
        let calendar = Calendar.current
        
        // Начинаем с начала часа от нижней границы
        var components = calendar.dateComponents([.year, .month, .day, .hour], from: range.lowerBound)
        components.minute = 0
        components.second = 0
        var current = calendar.date(from: components) ?? range.lowerBound
        
        // Генерируем метки каждые 2 часа до текущего момента
        while current <= range.upperBound {
            if current >= range.lowerBound {
                dates.append(current)
            }
            guard let next = calendar.date(byAdding: .hour, value: 2, to: current) else { break }
            current = next
        }
        
        return dates.sorted()
    }
    
    private var yDomain: ClosedRange<Double> {
        let minRisk = history.map { $0.riskLevel }.min() ?? 0
        let maxRisk = history.map { $0.riskLevel }.max() ?? 0
        // Если риск всегда 0, показываем диапазон 0-10 чтобы линия не прилипала к самому низу
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
                .lineStyle(StrokeStyle(lineWidth: 3)) // Делаем линию толще
                .interpolationMethod(.monotone)
                
                PointMark(
                    x: .value("Время", point.date),
                    y: .value("Риск", point.riskLevel)
                )
                .foregroundStyle(riskColor(point.riskLevel))
                .symbolSize(10) // Добавляем точки чтобы видеть измерения
                
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
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.primary.opacity(0.1))
                AxisValueLabel(anchor: .top) {
                    if let date = value.as(Date.self) {
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
                Text(DiaryEntry.emoji(for: entry.feelingScore))
                    .font(.title2)
            }
            
            Text("Состояние: \(DiaryEntry.description(for: entry.feelingScore))")
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
}

#Preview {
    HistoryView()
}

