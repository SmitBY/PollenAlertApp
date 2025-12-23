import SwiftUI
import GRDB

@Observable
class HistoryViewModel {
    var entries: [DiaryEntry] = []
    private let dbManager = DatabaseManager.shared
    
    func fetchHistory() async {
        do {
            let fetchedEntries = try await dbManager.dbQueue.read { db in
                try DiaryEntry.order(DiaryEntry.Columns.date.desc).fetchAll(db)
            }
            self.entries = fetchedEntries
        } catch {
            print("Failed to fetch history: \(error)")
        }
    }
}

struct HistoryView: View {
    @State private var viewModel = HistoryViewModel()
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            List {
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
            .navigationTitle("История")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Закрыть") {
                        dismiss()
                    }
                }
            }
            .task {
                await viewModel.fetchHistory()
            }
        }
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
