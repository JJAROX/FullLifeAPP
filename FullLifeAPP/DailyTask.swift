//
//  DailyTask.swift
//  FullLifeAPP
//
//  Created by Jan Juraszek on 08/08/2026.
//

import Foundation

struct DailyTask: Identifiable, Decodable {
    let id: Int
    let title: String
    let taskDate: String
    let startTime: String
    let endTime: String?
    var isCompleted: Bool
    let priority: Int
    let category: String?
    var isEvent: Bool?
    
    enum CodingKeys: String, CodingKey{
        case id, title, priority, category
        case taskDate = "task_date"
        case startTime = "start_time"
        case endTime = "end_time"
        case isCompleted = "is_completed"
        case isEvent = "is_event"
    }
}
