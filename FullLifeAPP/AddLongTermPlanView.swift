import SwiftUI

struct AddLongTermPlanView: View {
    @Environment(\.dismiss) var dismiss
    
    var planToEdit: LongTermPlan?
    
    @State private var title: String = ""
    @State private var targetDate: Date = Date()
    
    var onPlanAdded: () -> Void
    
    init(planToEdit: LongTermPlan? = nil, onPlanAdded: @escaping () -> Void) {
        self.planToEdit = planToEdit
        self.onPlanAdded = onPlanAdded
        
        if let plan = planToEdit {
            _title = State(initialValue: plan.title)
            
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = isoFormatter.date(from: plan.targetDate) ?? ISO8601DateFormatter().date(from: plan.targetDate) {
                _targetDate = State(initialValue: date)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Szczegóły wydarzenia")) {
                    TextField("Nazwa (np. Koncert)", text: $title)
                    DatePicker("Data i godzina", selection: $targetDate, displayedComponents: [.date, .hourAndMinute])
                }
                
                Section {
                    Button(action: {
                        Task { await savePlan() }
                    }) {
                        Text(planToEdit == nil ? "Zapisz Plan" : "Zaktualizuj Plan")
                            .frame(maxWidth: .infinity, alignment: .center)
                            .foregroundColor(.white)
                    }
                    .listRowBackground(Color.blue)
                }
            }
            .navigationTitle(planToEdit == nil ? "Nowy Plan" : "Edytuj Plan")
            .navigationBarItems(leading: Button("Anuluj") { dismiss() })
        }
    }
    
    func savePlan() async {
        guard !title.isEmpty else { return }
        
        let dateString = ISO8601DateFormatter().string(from: targetDate)
        
        struct PlanPayload: Encodable {
            let title: String
            let target_date: String
            let is_completed: Bool
        }
        
        let payload = PlanPayload(
            title: title,
            target_date: dateString,
            is_completed: planToEdit?.isCompleted ?? false
        )
        
        do {
            if let plan = planToEdit {
                try await supabase
                    .from("long_term_plans")
                    .update(payload)
                    .eq("id", value: plan.id)
                    .execute()
            } else {
                try await supabase
                    .from("long_term_plans")
                    .insert(payload)
                    .execute()
            }
            
            onPlanAdded()
            dismiss()
        } catch {
            print("Błąd zapisu planu: \(error)")
        }
    }
}
