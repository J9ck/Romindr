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
    @State private var reminderOptions: [ReminderOption] = [
        ReminderOption(title: "Valentine's Day", icon: "heart.fill", isCustomDate: false,
                       defaultDate: Calendar.current.date(from: DateComponents(year: 2026, month: 2, day: 14))),
        ReminderOption(title: "Our Anniversary", icon: "heart.circle.fill", isCustomDate: true),
        ReminderOption(title: "Their Birthday", icon: "gift.fill", isCustomDate: true),
        ReminderOption(title: "National Boyfriend Day", icon: "heart.fill", isCustomDate: false,
                       defaultDate: Calendar.current.date(from: DateComponents(year: 2025, month: 10, day: 3))),
        ReminderOption(title: "National Girlfriend Day", icon: "heart.fill", isCustomDate: false,
                       defaultDate: Calendar.current.date(from: DateComponents(year: 2025, month: 8, day: 1))),
        ReminderOption(title: "National Couples Day", icon: "heart.circle", isCustomDate: false,
                       defaultDate: Calendar.current.date(from: DateComponents(year: 2025, month: 8, day: 18)))
    ]

    @AppStorage("reminderOptionsData") private var storedReminderData: Data = Data()

    @State private var bounce = false
    @State private var hasUserInteracted = false
    @State private var audioPlayer: AVAudioPlayer?

    @State private var titleOpacity: Double = 0.0
    @State private var titleScale: CGFloat = 0.5

    @State private var toggleBounceIndices: Set<Int> = []
    @State private var flashCardIndices: Set<Int> = []
    @State private var showConfettiIndices: Set<Int> = []

    func playChime() {
        if let url = Bundle.main.url(forResource: "chime", withExtension: "wav") {
            audioPlayer = try? AVAudioPlayer(contentsOf: url)
            audioPlayer?.play()
        }
    }

    func saveReminders() {
        if let data = try? JSONEncoder().encode(reminderOptions) {
            storedReminderData = data
        }
    }

    func loadReminders() {
        if let loaded = try? JSONDecoder().decode([ReminderOption].self, from: storedReminderData) {
            reminderOptions = loaded
        }
    }

    func scheduleNotification(for option: ReminderOption) {
        guard option.isEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = "Romindr 💗"
        content.body = "Today is \(option.title)!"
        content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: "chime.wav"))

        let triggerDate = option.isCustomDate ? option.userDate : option.defaultDate ?? Date()
        let comps = Calendar.current.dateComponents([.month, .day], from: triggerDate)

        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let request = UNNotificationRequest(identifier: option.id.uuidString, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request)
    }

    var sortedReminderOptions: [ReminderOption] {
        let today = Calendar.current.startOfDay(for: Date())
        return reminderOptions
            .map { option in
                var newOption = option
                let base = option.isCustomDate ? option.userDate : option.defaultDate ?? Date()
                let md = Calendar.current.dateComponents([.month, .day], from: base)

                var next = DateComponents()
                next.year = Calendar.current.component(.year, from: today)
                next.month = md.month
                next.day = md.day

                let adjusted = Calendar.current.date(from: next) ?? base

                if adjusted < today {
                    next.year! += 1
                    let nextYear = Calendar.current.date(from: next) ?? adjusted
                    newOption.defaultDate = nextYear
                    newOption.userDate = nextYear
                } else {
                    newOption.defaultDate = adjusted
                    newOption.userDate = adjusted
                }

                return newOption
            }
            .sorted {
                let d1 = $0.isCustomDate ? $0.userDate : $0.defaultDate!
                let d2 = $1.isCustomDate ? $1.userDate : $1.defaultDate!
                return d1 < d2
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
                            ForEach(sortedReminderOptions.indices, id: \.self) { i in
                                let option = sortedReminderOptions[i]

                                HStack {
                                    Spacer()
                                    ZStack {
                                        VStack(alignment: .leading, spacing: 6) {
                                            HStack {
                                                Image(systemName: option.icon)
                                                    .foregroundColor(Color(red: 0.85, green: 0.1, blue: 0.3))
                                                    .scaleEffect(option.isEnabled && bounce ? 1.3 : 1.0)
                                                    .animation(.spring(response: 0.3, dampingFraction: 0.4), value: option.isEnabled && bounce)

                                                VStack(alignment: .leading) {
                                                    Text(option.title)
                                                        .font(.title3)
                                                        .fontWeight(.semibold)
                                                        .foregroundColor(Color(red: 0.85, green: 0.1, blue: 0.3))

                                                    Text(option.isCustomDate ?
                                                         option.userDate.formatted(date: .long, time: .omitted) :
                                                         option.defaultDate?.formatted(date: .long, time: .omitted) ?? "")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
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

                                                            toggleBounceIndices.insert(orig)
                                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                                                toggleBounceIndices.remove(orig)
                                                            }

                                                            flashCardIndices.insert(orig)
                                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                                                flashCardIndices.remove(orig)
                                                            }

                                                            if newValue {
                                                                showConfettiIndices.insert(orig)
                                                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                                                    showConfettiIndices.remove(orig)
                                                                }
                                                            }

                                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                                                bounce = false
                                                            }
                                                        }
                                                }
                                            }

                                            if option.isEnabled, option.isCustomDate {
                                                if let orig = reminderOptions.firstIndex(where: { $0.id == option.id }) {
                                                    DatePicker("Select date for \(option.title)",
                                                               selection: $reminderOptions[orig].userDate,
                                                               displayedComponents: [.date])
                                                        .datePickerStyle(GraphicalDatePickerStyle())
                                                        .accentColor(Color(red: 0.85, green: 0.1, blue: 0.3))
                                                        .onChange(of: reminderOptions[orig].userDate) { _ in
                                                            saveReminders()
                                                            scheduleNotification(for: reminderOptions[orig])
                                                        }
                                                }
                                            }
                                        }
                                        .padding()
                                        .background(
                                            flashCardIndices.contains(
                                                reminderOptions.firstIndex(where: { $0.id == option.id }) ?? -1
                                            ) ? Color(red: 1.0, green: 0.9, blue: 0.95)
                                            : Color.white
                                        )
                                        .cornerRadius(12)
                                        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                                        .scaleEffect(
                                            toggleBounceIndices.contains(
                                                reminderOptions.firstIndex(where: { $0.id == option.id }) ?? -1
                                            ) ? 1.05 : 1.0
                                        )
                                        .animation(.spring(response: 0.3, dampingFraction: 0.6),
                                                   value: toggleBounceIndices.contains(
                                                       reminderOptions.firstIndex(where: { $0.id == option.id }) ?? -1
                                                   ))

                                        if let orig = reminderOptions.firstIndex(where: { $0.id == option.id }),
                                           showConfettiIndices.contains(orig) {
                                            ConfettiView()
                                                .frame(maxWidth: 360, maxHeight: 200)
                                                .allowsHitTesting(false)
                                        }
                                    }
                                    Spacer()
                                }
                            }
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
        }
        .navigationViewStyle(.stack)
        .onAppear {
            loadReminders()
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
    }
}
