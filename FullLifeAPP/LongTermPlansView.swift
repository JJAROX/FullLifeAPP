import SwiftUI

struct LongTermPlansView: View {
    @State private var plans: [LongTermPlan] = []
    @State private var showingAddPlan = false // <--- Stan okienka
    @State private var planToEdit: LongTermPlan? = nil
    
    var body: some View {
        NavigationView {
            List(plans) { plan in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(plan.title)
                            .font(.headline)
                        
                        Text(plan.formattedDate)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    if let days = daysRemaining(to: plan.targetDate) {
                        if days >= 0 {
                            Text("\(days) dni")
                                .font(.system(size: 14, weight: .bold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.blue.opacity(0.15))
                                .foregroundColor(.blue)
                                .cornerRadius(8)
                        } else {
                            Text("Minęło")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(.vertical, 4)
                .swipeActions(edge: .leading) {
                        Button {
                            planToEdit = plan
                        } label: {
                            Label("Edytuj", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            Task {
                                await deletePlan(for: plan)
                            }
                        } label: {
                            Label("Usuń", systemImage: "trash")
                        }
                    }
            }
            .navigationTitle("Plany Długoterminowe")
            // Przycisk plusa w prawym górnym rogu
            .navigationBarItems(trailing: Button(action: {
                showingAddPlan = true
            }) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
            })            // Wysuwane okienko formularza
            .sheet(isPresented: $showingAddPlan) {
                AddLongTermPlanView(onPlanAdded: {
                    Task {
                        await fetchPlans()
                    }
                })
            }
            .sheet(item: $planToEdit) { plan in
                AddLongTermPlanView(planToEdit: plan, onPlanAdded: {
                    Task { await fetchPlans() }
                })
                
            }
            
            .task {
                await fetchPlans()
            }
        }
    }
    
    func fetchPlans() async {
        do {
            let fetchedPlans: [LongTermPlan] = try await supabase
                .from("long_term_plans")
                .select()
                .order("target_date", ascending: true)
                .execute()
                .value
            
            self.plans = fetchedPlans
        } catch {
            print("Błąd pobierania planów długoterminowych: \(error)")
        }
    }
    
    func daysRemaining(to dateString: String) -> Int? {
        let isoFormatter = ISO8601DateFormatter()
        let date = isoFormatter.date(from: dateString) ?? ISO8601DateFormatter().date(from: dateString)
        
        guard let targetDate = date else { return nil }
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: targetDate)
        return components.day
    }
    
    func deletePlan(for plan: LongTermPlan) async {
        do {
            try await supabase
                .from("long_term_plans")
                .delete()
                .eq("id", value: plan.id)
                .execute()
            
            await fetchPlans()
        } catch {
            print("Błąd podczas usuwania planu: \(error)")
        }
    }
}
