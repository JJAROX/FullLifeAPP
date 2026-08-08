import SwiftUI

struct AddView: View {
    @Environment(\.dismiss) var dismiss
    
    // Jeśli ten obiekt jest przekazany, to znaczy, że edytujemy istniejące zadanie
    var taskToEdit: DailyTask?
    
    @State private var title: String = ""
    @State private var taskDate: Date = Date()
    @State private var startTime: Date = Date()
    @State private var endTime: Date = Date()
    @State private var priority: Int = 2
    @State private var isEvent: Bool = false
    
    let categories = [
        ("Siłownia", "🏋️‍♂️"),
        ("Rozciąganie", "🙆🏻"),
        ("Programowanie", "💻"),
        ("Pobudka", "⏰"),
        ("Autobus", "🚌"),
        ("Książka", "📔"),
        ("Praca", "💼"),
        ("Sen", "🛌"),
        ("Inne", "📌")
    ]
    
    let daysOfWeek = [
            ("Pon", 2), ("Wt", 3), ("Śr", 4), ("Czw", 5),
            ("Pt", 6), ("Sob", 7), ("Ndz", 1)
        ]
    @State private var selectedWeekdays: Set<Int> = []
    
    @State private var selectedCategory: String = "Siłownia"
    
    var onTaskAdded: () -> Void
    
    // Inicjalizator wypełniający pola danymi w trybie edycji
    // Nowy inicjalizator przyjmujący domyślną datę
        init(taskToEdit: DailyTask? = nil, initialDate: Date = Date(), onTaskAdded: @escaping () -> Void) {
            self.taskToEdit = taskToEdit
            self.onTaskAdded = onTaskAdded
            
            if let task = taskToEdit {
                // TRYB EDYCJI: Wczytujemy dane z istniejącego zadania
                _title = State(initialValue: task.title)
                _priority = State(initialValue: task.priority)
                _selectedCategory = State(initialValue: task.category ?? "Inne")
                _isEvent = State(initialValue: task.isEvent ?? false)
                
                let df = DateFormatter()
                df.dateFormat = "yyyy-MM-dd"
                if let d = df.date(from: task.taskDate) {
                    _taskDate = State(initialValue: d)
                } else {
                    _taskDate = State(initialValue: initialDate)
                }
                
                let tf = DateFormatter()
                tf.dateFormat = "HH:mm:ss"
                if let t = tf.date(from: task.startTime) {
                    _startTime = State(initialValue: t)
                }
                if let endStr = task.endTime, let tEnd = tf.date(from: endStr) {
                    _endTime = State(initialValue: tEnd)
                }
            } else {
                // TRYB TWORZENIA: Ustawiamy datę na tę przekazaną z widoku głównego
                _taskDate = State(initialValue: initialDate)
            }
        }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Szczegóły zadania")) {
                    TextField("Nazwa zadania (np. Trening nóg)", text: $title)
                    
                    Picker("Priorytet", selection: $priority) {
                        Text("🔥 Wysoki").tag(1)
                        Text("Normalny").tag(2)
                        Text("Niski").tag(3)
                    }
                    
                    Toggle("🚨 To jest ważny EVENT", isOn: $isEvent)
                        .tint(.red)
                    
                    Picker("Kategoria", selection: $selectedCategory) {
                        ForEach(categories, id: \.0) { cat in
                            Text("\(cat.1) \(cat.0)").tag(cat.0)
                        }
                    }
                }
                
                Section(header: Text("Czas")) {
                    DatePicker("Data", selection: $taskDate, displayedComponents: .date)
                    DatePicker("Godzina startu", selection: $startTime, displayedComponents: .hourAndMinute)
                    DatePicker("Godzina końca", selection: $endTime, displayedComponents: .hourAndMinute)
                }
                
                // Wyświetlaj powtarzalność tylko podczas dodawania nowego zadania (nie przy edycji)
                                if taskToEdit == nil {
                                    Section(header: Text("Powtarzaj w dni (Kolejne 4 tygodnie)")) {
                                        HStack(spacing: 0) {
                                            ForEach(daysOfWeek, id: \.1) { dayName, dayValue in
                                                Text(dayName)
                                                    .font(.caption)
                                                    .fontWeight(.bold)
                                                    .frame(maxWidth: .infinity)
                                                    .padding(.vertical, 10)
                                                    .background(selectedWeekdays.contains(dayValue) ? Color.blue : Color.clear)
                                                    .foregroundColor(selectedWeekdays.contains(dayValue) ? .white : .gray)
                                                    .cornerRadius(8)
                                                    .onTapGesture {
                                                        if selectedWeekdays.contains(dayValue) {
                                                            selectedWeekdays.remove(dayValue)
                                                        } else {
                                                            selectedWeekdays.insert(dayValue)
                                                        }
                                                    }
                                            }
                                        }
                                        .background(Color.gray.opacity(0.1))
                                        .cornerRadius(8)
                                    }
                                }
                
                Section {
                    Button(action: {
                        Task {
                            scheduleNotification(for: title, date: taskDate, startTime: startTime)
                            await saveTask()
                        }
                    }) {
                        Text(taskToEdit == nil ? "Zapisz Zadanie" : "Zaktualizuj Zadanie")
                            .frame(maxWidth: .infinity, alignment: .center)
                            .foregroundColor(.white)
                    }
                    .listRowBackground(Color.blue)
                }
            }
            .navigationTitle(taskToEdit == nil ? "Nowe Zadanie" : "Edytuj Zadanie")
            .navigationBarItems(leading: Button("Anuluj") {
                dismiss()
            })
        }
    }
    
    func saveTask() async {
            guard !title.isEmpty else { return }
            
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm:ss"
            let startTimeString = timeFormatter.string(from: startTime)
            let endTimeString = timeFormatter.string(from: endTime)
            
            struct TaskPayload: Encodable {
                let title: String
                let task_date: String
                let start_time: String
                let end_time: String
                let priority: Int
                let category: String
                let is_completed: Bool
                let is_event: Bool
            }
            
            do {
                if let task = taskToEdit {
                    // TRYB EDYCJI - Pojedyncze zadanie
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd"
                    let dateString = dateFormatter.string(from: taskDate)
                    
                    let payload = TaskPayload(title: title, task_date: dateString, start_time: startTimeString, end_time: endTimeString, priority: priority, category: selectedCategory, is_completed: task.isCompleted, is_event: isEvent)
                    
                    try await supabase.from("daily_tasks").update(payload).eq("id", value: task.id).execute()
                    
                } else {
                    // TRYB TWORZENIA NOWEGO
                    var payloadsToInsert: [TaskPayload] = []
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd"
                    
                    if selectedWeekdays.isEmpty {
                        // Brak powtarzania - wrzucamy tylko jedno zadanie
                        let dateString = dateFormatter.string(from: taskDate)
                        let payload = TaskPayload(title: title, task_date: dateString, start_time: startTimeString, end_time: endTimeString, priority: priority, category: selectedCategory, is_completed: false, is_event: isEvent)
                        payloadsToInsert.append(payload)
                    } else {
                        // Powtarzanie - generujemy daty na najbliższe 28 dni
                        let calendar = Calendar.current
                        let today = Date()
                        
                        for i in 0..<28 {
                            if let dateToCheck = calendar.date(byAdding: .day, value: i, to: today) {
                                let weekday = calendar.component(.weekday, from: dateToCheck)
                                
                                if selectedWeekdays.contains(weekday) {
                                    let dateString = dateFormatter.string(from: dateToCheck)
                                    let payload = TaskPayload(title: title, task_date: dateString, start_time: startTimeString, end_time: endTimeString, priority: priority, category: selectedCategory, is_completed: false, is_event: isEvent)
                                    payloadsToInsert.append(payload)
                                }
                            }
                        }
                    }
                    
                    // Supabase automatycznie obsługuje wstawianie całej tablicy na raz!
                    try await supabase.from("daily_tasks").insert(payloadsToInsert).execute()
                }
                
                // Tutaj możesz odpalić powiadomienie (tylko na najblizsze zadanie zeby nie spamowac systemu)
                scheduleNotification(for: title, date: taskDate, startTime: startTime)
                
                onTaskAdded()
                dismiss()
                
            } catch {
                print("Błąd podczas zapisywania zadania: \(error)")
            }
        }
    func scheduleNotification(for title: String, date: Date, startTime: Date) {
        let content = UNMutableNotificationContent()
        content.title = "Czas na zadanie! 🚀"
        content.body = title
        content.sound = .default
        
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: startTime)
        
        var triggerComponents = DateComponents()
        triggerComponents.year = dateComponents.year
        triggerComponents.month = dateComponents.month
        triggerComponents.day = dateComponents.day
        triggerComponents.hour = timeComponents.hour
        triggerComponents.minute = timeComponents.minute
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Błąd podczas planowania powiadomienia: \(error)")
            }
        }
    }
}
