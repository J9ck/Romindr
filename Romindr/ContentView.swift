//
//  ContentView.swift
//  Romindr
//
//  Created by Jack Doyle on 8/1/25.
//
import SwiftUI
import AVFoundation
import UserNotifications
import Combine

struct ReminderOption: Identifiable, Codable {
    let id: UUID
    var title: String
    var icon: String
    var isCustomDate: Bool
    var defaultDate: Date?
    var userDate: Date
    var isEnabled: Bool

    init(id: UUID = UUID(), title: String, icon: String, isCustomDate: Bool, defaultDate: Date? = nil, userDate: Date = Date(), isEnabled: Bool = true) {
        self.id = id
        self.title = title
        self.icon = icon
        self.isCustomDate = isCustomDate
        self.defaultDate = defaultDate
        self.userDate = userDate
        self.isEnabled = isEnabled
    }
}

struct ConfettiView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()

        let emitter = CAEmitterLayer()
        emitter.emitterPosition = CGPoint(x: UIScreen.main.bounds.width / 2, y: 0)
        emitter.emitterShape = .line
        emitter.emitterSize = CGSize(width: UIScreen.main.bounds.width, height: 1)

        let colors: [UIColor] = [.systemPink, .systemRed, .systemPurple, .systemTeal, .systemYellow]
        var cells: [CAEmitterCell] = []

        for color in colors {
            let cell = CAEmitterCell()
            cell.birthRate = 6
            cell.lifetime = 4.0
            cell.lifetimeRange = 1.5
            cell.color = color.cgColor
            cell.velocity = 150
            cell.velocityRange = 50
            cell.emissionLongitude = .pi
            cell.emissionRange = .pi / 4
            cell.spin = 3
            cell.spinRange = 3
            cell.scale = 0.05
            cell.scaleRange = 0.02
            cell.contents = UIImage(systemName: "sparkle")?.cgImage
            cells.append(cell)
        }

        emitter.emitterCells = cells
        view.layer.addSublayer(emitter)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            emitter.birthRate = 0
        }

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

struct ContentView: View {
    @State private var reminderOptions: [ReminderOption] = []
    
    // Default templates that can be used
    private let defaultTemplates: [ReminderOption] = [
        ReminderOption(title: "Valentine's Day", icon: "heart.fill", isCustomDate: false,
                       defaultDate: Calendar.current.date(from: DateComponents(month: 2, day: 14))),
        ReminderOption(title: "Our Anniversary", icon: "heart.circle.fill", isCustomDate: true),
        ReminderOption(title: "Their Birthday", icon: "gift.fill", isCustomDate: true),
        ReminderOption(title: "National Boyfriend Day", icon: "heart.fill", isCustomDate: false,
                       defaultDate: Calendar.current.date(from: DateComponents(month: 10, day: 3))),
        ReminderOption(title: "National Girlfriend Day", icon: "heart.fill", isCustomDate: false,
                       defaultDate: Calendar.current.date(from: DateComponents(month: 8, day: 1))),
        ReminderOption(title: "National Couples Day", icon: "heart.circle", isCustomDate: false,
                       defaultDate: Calendar.current.date(from: DateComponents(month: 8, day: 18)))
    ]

    @AppStorage("reminderOptionsData") private var storedReminderData: Data = Data()
    @AppStorage("hasLoadedDefaults") private var hasLoadedDefaults: Bool = false

    @State private var bounce = false
    @State private var hasUserInteracted = false
    @State private var audioPlayer: AVAudioPlayer?

    @State private var titleOpacity: Double = 0.0
    @State private var titleScale: CGFloat = 0.5

    @State private var toggleBounceIndices: Set<UUID> = []
    @State private var flashCardIndices: Set<UUID> = []
    @State private var showConfettiIndices: Set<UUID> = []
    
    @State private var showingAddReminder = false
    @State private var newReminderTitle = ""
    @State private var newReminderDate = Date()
    @State private var showingNotificationAlert = false

    func playChime() {
        guard let url = Bundle.main.url(forResource: "chime", withExtension: "wav") else {
            print("Error: chime.wav not found in bundle")
            return
        }
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.play()
        } catch {
            print("Error playing chime: \(error.localizedDescription)")
        }
    }

    func saveReminders() {
        do {
            let data = try JSONEncoder().encode(reminderOptions)
            storedReminderData = data
        } catch {
            print("Error saving reminders: \(error.localizedDescription)")
        }
    }

    func loadReminders() {
        // Load saved reminders first
        if !storedReminderData.isEmpty {
            do {
                reminderOptions = try JSONDecoder().decode([ReminderOption].self, from: storedReminderData)
            } catch {
                print("Error loading reminders: \(error.localizedDescription)")
            }
        }
        
        // Load defaults only on first launch
        if !hasLoadedDefaults && reminderOptions.isEmpty {
            reminderOptions = defaultTemplates
            hasLoadedDefaults = true
            saveReminders()
        }
    }
    
    func deleteReminder(at offsets: IndexSet) {
        // Get the IDs of reminders to delete
        let idsToDelete = offsets.map { sortedReminderOptions[$0].id }
        
        // Remove notifications
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: idsToDelete.map { $0.uuidString })
        
        // Remove from main array
        reminderOptions.removeAll { reminder in
            idsToDelete.contains(reminder.id)
        }
        
        saveReminders()
    }
    
    func addReminder() {
        guard !newReminderTitle.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        let newReminder = ReminderOption(
            title: newReminderTitle,
            icon: "calendar.badge.clock",
            isCustomDate: true,
            userDate: newReminderDate,
            isEnabled: true
        )
        
        reminderOptions.append(newReminder)
        saveReminders()
        scheduleNotification(for: newReminder)
        
        newReminderTitle = ""
        newReminderDate = Date()
        showingAddReminder = false
    }
    
    func daysUntil(date: Date) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let targetDate = calendar.startOfDay(for: date)
        
        if let days = calendar.dateComponents([.day], from: today, to: targetDate).day {
            return days
        }
        return 0
    }

    func scheduleNotification(for option: ReminderOption) {
        guard option.isEnabled else {
            // Remove notification if disabled
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [option.id.uuidString])
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Romindr 💗"
        content.body = "Today is \(option.title)!"
        content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: "chime.wav"))

        let triggerDate = option.isCustomDate ? option.userDate : option.defaultDate ?? Date()
        let comps = Calendar.current.dateComponents([.month, .day], from: triggerDate)
        
        // Validate date components
        guard comps.month != nil && comps.day != nil else {
            print("Error: Invalid date components for notification")
            return
        }

        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let request = UNNotificationRequest(identifier: option.id.uuidString, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
            }
        }
    }

    var sortedReminderOptions: [ReminderOption] {
        let today = Calendar.current.startOfDay(for: Date())
        let currentYear = Calendar.current.component(.year, from: today)
        
        return reminderOptions
            .map { option -> ReminderOption in
                var newOption = option
                let base = option.isCustomDate ? option.userDate : option.defaultDate ?? Date()
                
                guard let md = Calendar.current.dateComponents([.month, .day], from: base).month,
                      let day = Calendar.current.dateComponents([.month, .day], from: base).day else {
                    return option // Return original if date components are invalid
                }
                
                var nextDate = DateComponents()
                nextDate.year = currentYear
                nextDate.month = md
                nextDate.day = day
                
                guard var adjusted = Calendar.current.date(from: nextDate) else {
                    return option // Return original if date creation fails
                }
                
                // If the date has passed this year, use next year
                if adjusted < today {
                    nextDate.year = currentYear + 1
                    adjusted = Calendar.current.date(from: nextDate) ?? adjusted
                }
                
                // Update the display date without mutating the original stored date
                if !option.isCustomDate {
                    newOption.defaultDate = adjusted
                } else {
                    newOption.userDate = adjusted
                }
                
                return newOption
            }
            .sorted { option1, option2 in
                let date1 = option1.isCustomDate ? option1.userDate : (option1.defaultDate ?? Date())
                let date2 = option2.isCustomDate ? option2.userDate : (option2.defaultDate ?? Date())
                return date1 < date2
            }
    }

    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 1.0, green: 0.9, blue: 0.95),
                        Color(red: 1.0, green: 0.98, blue: 1.0)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .edgesIgnoringSafeArea(.all)

                VStack(spacing: 0) {
                    VStack(spacing: 4) {
                        Text("Romindr")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundColor(Color(red: 0.85, green: 0.1, blue: 0.3))
                            .opacity(titleOpacity)
                            .scaleEffect(titleScale)

                        Text("Because love deserves a reminder.")
                            .font(.system(size: 16, weight: .regular, design: .rounded))
                            .foregroundColor(Color(red: 1.0, green: 0.5, blue: 0.65))
                    }
                    .padding()
                    .onAppear {
                        withAnimation(.easeOut(duration: 0.8)) {
                            titleOpacity = 1.0
                            titleScale = 1.1
                        }
                        withAnimation(.interpolatingSpring(stiffness: 200, damping: 8).delay(0.8)) {
                            titleScale = 1.0
                        }
                    }

                    ScrollView {
                        VStack(spacing: 16) {
                            ForEach(sortedReminderOptions) { option in
                                HStack {
                                    Spacer()
                                    ZStack {
                                        VStack(alignment: .leading, spacing: 6) {
                                            HStack(alignment: .top) {
                                                Image(systemName: option.icon)
                                                    .foregroundColor(Color(red: 0.85, green: 0.1, blue: 0.3))
                                                    .scaleEffect(option.isEnabled && bounce ? 1.3 : 1.0)
                                                    .animation(.spring(response: 0.3, dampingFraction: 0.4), value: option.isEnabled && bounce)

                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(option.title)
                                                        .font(.title3)
                                                        .fontWeight(.semibold)
                                                        .foregroundColor(Color(red: 0.85, green: 0.1, blue: 0.3))

                                                    let displayDate = option.isCustomDate ? option.userDate : (option.defaultDate ?? Date())
                                                    Text(displayDate.formatted(date: .long, time: .omitted))
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                    
                                                    // Days until countdown
                                                    let days = daysUntil(date: displayDate)
                                                    if days >= 0 {
                                                        Text(days == 0 ? "Today! 🎉" : days == 1 ? "Tomorrow" : "In \(days) days")
                                                            .font(.caption2)
                                                            .fontWeight(.medium)
                                                            .foregroundColor(days <= 7 ? Color(red: 0.85, green: 0.1, blue: 0.3) : .secondary)
                                                    }
                                                }

                                                Spacer()

                                                if let orig = reminderOptions.firstIndex(where: { $0.id == option.id }) {
                                                    Toggle("", isOn: $reminderOptions[orig].isEnabled)
                                                        .labelsHidden()
                                                        .toggleStyle(SwitchToggleStyle(tint: Color(red: 0.85, green: 0.1, blue: 0.3)))
                                                        .onChange(of: reminderOptions[orig].isEnabled) { newValue in
                                                            if hasUserInteracted { playChime() }
                                                            hasUserInteracted = true

                                                            bounce = true
                                                            saveReminders()
                                                            scheduleNotification(for: reminderOptions[orig])

                                                            toggleBounceIndices.insert(option.id)
                                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                                                toggleBounceIndices.remove(option.id)
                                                            }

                                                            flashCardIndices.insert(option.id)
                                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                                                flashCardIndices.remove(option.id)
                                                            }

                                                            if newValue {
                                                                showConfettiIndices.insert(option.id)
                                                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                                                    showConfettiIndices.remove(option.id)
                                                                }
                                                            }

                                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                                                bounce = false
                                                            }
                                                        }
                                                }
                                            }

                                            // Show date picker for custom dates (always visible when custom)
                                            if option.isCustomDate {
                                                if let orig = reminderOptions.firstIndex(where: { $0.id == option.id }) {
                                                    DatePicker("Select date for \(option.title)",
                                                               selection: $reminderOptions[orig].userDate,
                                                               displayedComponents: [.date])
                                                        .datePickerStyle(GraphicalDatePickerStyle())
                                                        .accentColor(Color(red: 0.85, green: 0.1, blue: 0.3))
                                                        .onChange(of: reminderOptions[orig].userDate) { _ in
                                                            saveReminders()
                                                            if reminderOptions[orig].isEnabled {
                                                                scheduleNotification(for: reminderOptions[orig])
                                                            }
                                                        }
                                                }
                                            }
                                        }
                                        .padding()
                                        .background(
                                            flashCardIndices.contains(option.id) ? Color(red: 1.0, green: 0.9, blue: 0.95)
                                            : Color.white
                                        )
                                        .cornerRadius(12)
                                        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                                        .scaleEffect(toggleBounceIndices.contains(option.id) ? 1.05 : 1.0)
                                        .animation(.spring(response: 0.3, dampingFraction: 0.6),
                                                   value: toggleBounceIndices.contains(option.id))

                                        if showConfettiIndices.contains(option.id) {
                                            ConfettiView()
                                                .frame(maxWidth: 360, maxHeight: 200)
                                                .allowsHitTesting(false)
                                        }
                                    }
                                    Spacer()
                                }
                            }
                            .onDelete(perform: deleteReminder)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 16)

                        Text("Created by Jack Doyle for Avery Leonard (:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.bottom, 10)
                    }
                }
            }
            .navigationBarItems(trailing: Button(action: {
                showingAddReminder = true
            }) {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(Color(red: 0.85, green: 0.1, blue: 0.3))
                    .font(.title2)
            })
            .sheet(isPresented: $showingAddReminder) {
                NavigationView {
                    Form {
                        Section(header: Text("New Reminder")) {
                            TextField("Reminder Name", text: $newReminderTitle)
                            DatePicker("Date", selection: $newReminderDate, displayedComponents: [.date])
                        }
                    }
                    .navigationTitle("Add Reminder")
                    .navigationBarItems(
                        leading: Button("Cancel") {
                            showingAddReminder = false
                            newReminderTitle = ""
                            newReminderDate = Date()
                        },
                        trailing: Button("Add") {
                            addReminder()
                        }
                        .disabled(newReminderTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                    )
                }
            }
            .alert("Notification Permission", isPresented: $showingNotificationAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Please enable notifications in Settings to receive reminders for your special dates.")
            }
        }
        .navigationViewStyle(.stack)
        .onAppear {
            loadReminders()
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                if let error = error {
                    print("Error requesting notification authorization: \(error.localizedDescription)")
                }
                if granted {
                    print("Notification authorization granted")
                } else {
                    print("Notification authorization denied")
                    DispatchQueue.main.async {
                        showingNotificationAlert = true
                    }
                }
            }
        }
    }
}
