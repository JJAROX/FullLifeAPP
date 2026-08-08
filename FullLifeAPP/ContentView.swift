//
//  ContentView.swift
//  FullLifeAPP
//
//  Created by Jan Juraszek on 08/08/2026.
//

import SwiftUI
import Supabase
import UserNotifications


// 2. GŁÓWNY WIDOK
struct ContentView: View {
    var body: some View {
        TabView {
            DailyTasksView()
                .tabItem {
                    Label("Dzień", systemImage: "calendar")
                }
            
            LongTermPlansView()
                .tabItem {
                    Label("Plany", systemImage: "flag.checkered")
                }
        }
    }
}

