import SwiftUI
// ---------------------------------------------------------
// GŁÓWNY WIDOK DZIENNY (Twój dotychczasowy planer z kalendarzem)
// ---------------------------------------------------------
struct DailyTasksView: View {
    @State private var tasks: [DailyTask] = []
    @State private var name: Bool = false // (nieużywane, pomijamy)
    @State private var showingAddView = false
    @State private var selectedDate: Date = Date()
    @State private var taskToEdit: DailyTask? = nil
    @State private var isPulsing = false
    
    var filteredTasks: [DailyTask] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let selectedString = formatter.string(from: selectedDate)
                
        return tasks
            .filter { $0.taskDate == selectedString }
            .sorted { $0.startTime < $1.startTime } // <--- AUTOMATYCZNE SORTOWANIE
    }
    
    // Inteligentny licznik passy (dni z rzędu z ukończonymi zadaniami)
    var currentStreak: Int {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        // Grupujemy wszystkie zadania po dacie
        let groupedTasks = Dictionary(grouping: tasks) { $0.taskDate }
        
        var streak = 0
        var checkDate = Date()
        
        // Sprawdzamy wstecz dzień po dniu (maksymalnie rok)
        for _ in 0..<365 {
            let dateString = formatter.string(from: checkDate)
            
            if let dayTasks = groupedTasks[dateString], dayTasks.contains(where: { $0.isCompleted }) {
                streak += 1
                guard let prev = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
                checkDate = prev
            } else {
                // Jeśli to dzisiaj i użytkownik jeszcze nie zdążył nic odhaczyć,
                // nie psujemy passy z poprzednich dni – sprawdzamy po prostu wczorajszy dzień
                if calendar.isDateInToday(checkDate) {
                    guard let prev = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
                    checkDate = prev
                    continue
                }
                break
            }
        }
        return streak
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Poziomy pasek tygodnia
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(getUpcomingDays(), id: \.self) { date in
                            let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
                            
                            // Sprawdzamy czy w tym dniu przypada jakiś Event
                            let hasEvent: Bool = {
                                let formatter = DateFormatter()
                                formatter.dateFormat = "yyyy-MM-dd"
                                let dateStr = formatter.string(from: date)
                                return tasks.contains { $0.taskDate == dateStr && ($0.isEvent == true) }
                            }()
                            
                            VStack(spacing: 6) {
                                Text(shortWeekdayName(for: date))
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(isSelected || hasEvent ? .white : .gray)
                                
                                Text(dayNumber(for: date))
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(isSelected || hasEvent ? .white : .primary)
                            }
                            .frame(width: 55, height: 75)
                            // Jeśli ma Event to na czerwono, inaczej standardowo
                            .background(
                                hasEvent ? (isSelected ? Color.red : Color.red.opacity(0.6)) :
                                (isSelected ? Color.blue : Color.gray.opacity(0.1))
                            )
                            .cornerRadius(16)
                            .onTapGesture {
                                withAnimation(.spring()) {
                                    selectedDate = date
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 5)
                }
                
                if !filteredTasks.isEmpty {
                    let totalCount = filteredTasks.count
                    let completedCount = filteredTasks.filter { $0.isCompleted }.count
                    let progressValue = totalCount > 0 ? Double(completedCount) / Double(totalCount) : 0.0
                    
                    VStack(spacing: 12) {
                        // Górny wiersz: Postęp dzisiejszy + Passa
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Dzisiejszy postęp")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Text("\(completedCount) z \(totalCount) ukończone")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.blue)
                            }
                            
                            Spacer()
                            
                            // Licznik serii (Streak)
                            HStack(spacing: 4) {
                                Text("🔥")
                                Text("\(currentStreak) dni z rzędu")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.orange)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.orange.opacity(0.12))
                            .cornerRadius(8)
                        }
                        
                        // Pasek postępu
                        ProgressView(value: progressValue)
                            .tint(.blue)
                            .scaleEffect(x: 1, y: 1.5, anchor: .center)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.06))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                
                List(filteredTasks) { task in
                    HStack {
                        // Ikona kategorii na podstawie tekstu z bazy
                        Text(iconForCategory(task.category))
                            .font(.title2)
                            .padding(.trailing, 4)
                        
                        VStack(alignment: .leading, spacing: 3) {
                            Text(task.title)
                                .font(.headline)
                            
                            let timeText: String = {
                                let start = String(task.startTime.prefix(5))
                                if let end = task.endTime, !end.isEmpty {
                                    return "\(start) - \(String(end.prefix(5)))"
                                } else {
                                    return start
                                }
                            }()
                            
                            Text(timeText)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                        }
                        
                        Spacer()
                        
                        Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(task.isCompleted ? .green : .gray)
                            .font(.title2)
                            .onTapGesture {
                                Task {
                                    await toggleCompletion(for: task)
                                }
                            }
                    }
                    .padding()
                    // DYNAMICZNE TŁO W ZALEŻNOŚCI OD PRIORYTETU
                    .modifier(EventPulseModifier(
                            isEvent: task.isEvent ?? false,
                            standardColor: backgroundColor(for: task.priority)
                        ))
                        // -------------------------------------------
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    .swipeActions(edge: .leading) {
                            Button {
                                taskToEdit = task
                            } label: {
                                Label("Edytuj", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                    .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                Task {
                                    await deleteTask(for: task)
                                }
                            } label: {
                                Label("Usuń", systemImage: "trash")
                            }
                        }
                }
                .listStyle(.plain)
                .overlay(alignment: .center) {
                    if filteredTasks.isEmpty {
                        Text("Brak zadań na ten dzień 🚀")
                            .foregroundColor(.gray)
                            .padding()
                    }
                }
            }
            .navigationTitle("Plan tygodnia 🗓️")
            .navigationBarItems(trailing: Button(action: {
                showingAddView = true
            }) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
            })
            // Wysuwane okienko formularza (TWORZENIE)
            .sheet(isPresented: $showingAddView) {
                            AddView(initialDate: selectedDate, onTaskAdded: {
                                Task {
                                    await fetchTasks()
                                }
                            })
                        }
                        // Wysuwane okienko formularza (EDYCJA)
            .sheet(item: $taskToEdit) { task in
                            AddView(taskToEdit: task, onTaskAdded: {
                                Task {
                                    await fetchTasks()
                                }
                            })
                        }
            .task {
                requestNotificationPermission()
                await fetchTasks()
            }
            .onAppear {
            isPulsing = true
            }
        }
    }
    
    // Funkcja zwracająca odpowiedni, lekki kolor tła dla karty
    func backgroundColor(for priority: Int) -> Color {
        switch priority {
        case 1:
            return Color.red.opacity(0.12)    // Bardziej wyrazisty, "agresywniejszy" (ale wciąż light) różowo-czerwony
        case 2:
            return Color.blue.opacity(0.06)   // Neutralny, delikatny niebieski dla standardu
        case 3:
            return Color.green.opacity(0.06)  // Spokojny, lekki zielony dla niskiego priorytetu
        default:
            return Color.gray.opacity(0.05)
        }
    }
    
    // Funkcja przypisująca emotikonę do wybranej kategorii
    func iconForCategory(_ category: String?) -> String {
        switch category {
        case "Siłownia": return "🏋️‍♂️"
        case "Rozciąganie": return "🙆🏻"
        case "Programowanie": return "💻"
        case "Pobudka": return "⏰"
        case "Autobus": return "🚌"
        case "Praca": return "💼"
        case "Sen": return "🛌"
        case "Książka": return "📔"
        default: return "📌"
        }
    }
    
    func fetchTasks() async {
        do {
            let fetchedTasks: [DailyTask] = try await supabase
                .from("daily_tasks")
                .select()
                .order("start_time", ascending: true)
                .execute()
                .value
            
            self.tasks = fetchedTasks
        } catch {
            print("Błąd podczas pobierania zadań: \(error)")
        }
    }
    
    func deleteTask(for task: DailyTask) async {
        do {
            try await supabase
                .from("daily_tasks")
                .delete()
                .eq("id", value: task.id)
                .execute()
            
            // Odświeżamy listę po usunięciu z bazy
            await fetchTasks()
        } catch {
            print("Błąd podczas usuwania zadania: \(error)")
        }
    }
    
    func toggleCompletion(for task: DailyTask) async {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        let newValue = !task.isCompleted
        
        withAnimation(.easeInOut(duration: 0.2)) {
            tasks[index].isCompleted = newValue
        }
        
        struct UpdateTask: Encodable {
            let is_completed: Bool
        }
        
        do {
            try await supabase
                .from("daily_tasks")
                .update(UpdateTask(is_completed: newValue))
                .eq("id", value: task.id)
                .execute()
        } catch {
            print("Błąd przy aktualizacji: \(error)")
            withAnimation(.easeInOut(duration: 0.2)) {
                tasks[index].isCompleted = !newValue
            }
        }
    }
    
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("Zgoda na powiadomienia przyznana!")
            } else if let error = error {
                print("Błąd autoryzacji powiadomień: \(error)")
            }
        }
    }
    // Generuje 14 najbliższych dni zaczynając od dzisiaj
        func getUpcomingDays() -> [Date] {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            return (0..<14).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
        }
        
        func shortWeekdayName(for date: Date) -> String {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "pl_PL")
            formatter.dateFormat = "EEE" // Np. pon., wt., śr.
            return formatter.string(from: date).capitalized
        }
        
        func dayNumber(for date: Date) -> String {
            let formatter = DateFormatter()
            formatter.dateFormat = "d"
            return formatter.string(from: date)
        }
}
struct EventPulseModifier: ViewModifier {
    let isEvent: Bool
    let standardColor: Color
    @State private var localIsPulsing = false
    
    func body(content: Content) -> some View {
        content
            // Decydujemy o tle: czerwone dla eventu, standardowe dla reszty
            .background(
                isEvent
                ? (localIsPulsing ? Color.red.opacity(0.2) : Color.red.opacity(0.05))
                : standardColor
            )
            .cornerRadius(12)
            // Pulsująca czerwona ramka i poświata tylko dla eventów
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.red, lineWidth: isEvent ? (localIsPulsing ? 3 : 0) : 0)
                    .shadow(color: .red, radius: (isEvent && localIsPulsing) ? 6 : 0)
            )
            // Fizyczne "oddychanie" kafelka
            .scaleEffect((isEvent && localIsPulsing) ? 1.02 : 1.0)
            .onAppear {
                if isEvent {
                    // Wprawiamy w ruch tylko ten konkretny wiersz!
                    withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                        localIsPulsing = true
                    }
                }
            }
    }
}
