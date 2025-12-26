import SwiftUI
import Observation
import GRDB

@Observable
@MainActor
class DiaryViewModel {
    var feelingScore: Int = 3
    var symptoms: String = ""
    var isSaving = false
    var lastSavedEntry: DiaryEntry?
    
    private let dbManager = DatabaseManager.shared
    
    func saveEntry(h3Index: String) async {
        guard !isSaving else { return }
        isSaving = true
        
        let entry = DiaryEntry(
            date: Date(),
            feelingScore: feelingScore,
            symptoms: symptoms.isEmpty ? nil : symptoms,
            h3Index: h3Index
        )
        
        do {
            try await dbManager.dbQueue.write { db in
                try entry.save(db)
            }
            lastSavedEntry = entry
            
            // Обновляем персональные пороги после новой записи
            await PersonalRiskService.shared.updateThresholds()
            
            // Очистка после сохранения
            symptoms = ""
            feelingScore = 3
        } catch {
            print("Failed to save diary entry: \(error)")
        }
        
        isSaving = false
    }
}

struct DiaryView: View {
    @State private var viewModel = DiaryViewModel()
    var currentH3Index: String
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Как вы себя чувствуете?") {
                    VStack {
                        HStack {
                            ForEach(0...5, id: \.self) { score in
                                Button {
                                    viewModel.feelingScore = score
                                } label: {
                                    VStack {
                                        Text(DiaryEntry.emoji(for: score))
                                            .font(.title2)
                                        Text("\(score)")
                                            .font(.caption)
                                    }
                                    .padding(8)
                                    .background(viewModel.feelingScore == score ? Color.orange.opacity(0.2) : Color.clear)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.plain)
                                .opacity(viewModel.feelingScore == score ? 1.0 : 0.5)
                            }
                        }
                        .padding(.vertical)
                        
                        Text(DiaryEntry.description(for: viewModel.feelingScore))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Section("Симптомы (необязательно)") {
                    TextField("Например: насморк, зуд в глазах...", text: $viewModel.symptoms, axis: .vertical)
                        .lineLimit(3...5)
                }
                
                Section {
                    Button {
                        Task {
                            await viewModel.saveEntry(h3Index: currentH3Index)
                            dismiss()
                        }
                    } label: {
                        if viewModel.isSaving {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Сохранить")
                                .bold()
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(viewModel.isSaving)
                }
            }
            .navigationTitle("Дневник")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    DiaryView(currentH3Index: "8828308281fffff")
}

