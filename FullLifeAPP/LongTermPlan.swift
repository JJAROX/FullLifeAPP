import Foundation

struct LongTermPlan: Identifiable, Decodable {
    let id: UUID
    let title: String
    let targetDate: String
    var isCompleted: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, title
        case targetDate = "target_date"
        case isCompleted = "is_completed"
    }
    
    // Sprytna funkcja formatująca surowy tekst z bazy na ładną datę i godzinę
    var formattedDate: String {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        // Próbujemy sparsować datę z Supabase
        if let date = isoFormatter.date(from: targetDate) ?? ISO8601DateFormatter().date(from: targetDate) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short
            displayFormatter.locale = Locale(identifier: "pl_PL") // Polski format
            return displayFormatter.string(from: date)
        }
        
        return targetDate // Awaryjnie, gdyby format się nie zgadzał
    }
}
