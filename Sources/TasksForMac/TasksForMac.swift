import AppKit
import Foundation
import SwiftUI

/// A project in the sidebar: a name, a symbol and a colour (tasks carry it as a tag).
struct Project: Identifiable, Hashable, Codable {
    let id: String
    let symbol: String
    let color: Color

    static let launch = Project(id: "Launch", symbol: "paperplane.fill", color: .indigo)
    static let design = Project(id: "Design", symbol: "paintpalette.fill", color: .pink)
    static let home = Project(id: "Home", symbol: "house.fill", color: .green)
    static let all = [launch, design, home]

    init(id: String, symbol: String, color: Color) {
        self.id = id
        self.symbol = symbol
        self.color = color
    }

    // Stored by name only; symbol and colour come from the built-in list.
    init(from decoder: Decoder) throws {
        let name = try decoder.singleValueContainer().decode(String.self)
        self = Project.all.first { $0.id == name } ?? .launch
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(id)
    }

    static func == (lhs: Project, rhs: Project) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct TaskItem: Identifiable, Codable {
    var id = UUID()
    var title: String
    var project: Project
    var time: String
    var done = false
}

enum Filter: String, CaseIterable, Identifiable {
    case all = "All", open = "Open", done = "Done"

    var id: String {
        rawValue
    }
}

/// Sidebar sections (the list on the left; only Today is live, the rest is scenery with counts).
enum Section: String, CaseIterable, Identifiable {
    case today = "Today", upcoming = "Upcoming", flagged = "Flagged"

    var id: String {
        rawValue
    }

    var symbol: String {
        switch self {
        case .today: "sun.max.fill"
        case .upcoming: "calendar"
        case .flagged: "flag.fill"
        }
    }

    var color: Color {
        switch self {
        case .today: .orange
        case .upcoming: .red
        case .flagged: .yellow
        }
    }
}

/// Tasks live in one JSON file on this Mac (~/Library/Application Support/TasksForMac/tasks.json). No account, no network.
enum TaskStore {
    static var url: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TasksForMac", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("tasks.json")
    }

    static let starter = [
        TaskItem(title: "Plan the launch", project: .launch, time: "9:30"),
        TaskItem(title: "Write release notes", project: .launch, time: "11:00"),
        TaskItem(title: "Pick the hero colours", project: .design, time: "14:00"),
    ]

    static func load() -> [TaskItem] {
        guard let data = try? Data(contentsOf: url) else { return starter }
        return (try? JSONDecoder().decode([TaskItem].self, from: data)) ?? starter
    }

    static func save(_ tasks: [TaskItem]) {
        guard let data = try? JSONEncoder().encode(tasks) else { return }
        try? data.write(to: url, options: .atomic)
    }
}

struct ContentView: View {
    @State private var tasks = TaskStore.load()
    @State private var draft = ""
    @State private var filter = Filter.all
    @State private var section: Section? = .today

    var body: some View {
        NavigationSplitView {
            List(selection: $section) {
                ForEach(Section.allCases) { item in
                    SidebarRow(title: item.rawValue, symbol: item.symbol, color: item.color,
                               count: item == .today ? tasks.filter { !$0.done }.count : (item == .upcoming ? 7 : 2))
                        .tag(item)
                }
                SwiftUI.Section("Projects") {
                    ForEach(Project.all) { project in
                        SidebarRow(title: project.id, symbol: project.symbol, color: project.color,
                                   count: tasks.filter { $0.project == project && !$0.done }.count)
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 220)
        } detail: {
            today
        }
        .tint(.indigo)
        .frame(minWidth: 760, idealWidth: 1024, minHeight: 480, idealHeight: 576)
        .onChange(of: tasks.map { "\($0.id)|\($0.title)|\($0.done)" }) { TaskStore.save(tasks) }
    }

    private var visible: [Binding<TaskItem>] {
        $tasks.filter { item in
            switch filter {
            case .all: true
            case .open: !item.wrappedValue.done
            case .done: item.wrappedValue.done
            }
        }
    }

    private var today: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Today").font(.system(size: 34, weight: .bold)).accessibilityAddTraits(.isHeader)
                Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day())).font(.title3).foregroundStyle(.secondary)
            }
            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill").font(.title2).foregroundStyle(.indigo)
                TextField("New task", text: $draft)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .accessibilityIdentifier("new-task")
                    .onSubmit(add)
                Button("Add", action: add)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .accessibilityIdentifier("add-task")
                    .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.background, in: .rect(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.indigo.opacity(0.35)))
            Picker("Show", selection: $filter) {
                ForEach(Filter.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .controlSize(.large)
            .frame(maxWidth: 320)
            .accessibilityIdentifier("filter")
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(visible) { $item in
                        TaskCard(item: $item)
                    }
                }
            }
            .accessibilityIdentifier("task-list")
            HStack {
                Text("\(tasks.filter(\.done).count) of \(tasks.count) done")
                    .font(.callout).foregroundStyle(.secondary)
                    .accessibilityIdentifier("summary")
                Spacer()
                Button("Clear done") {
                    withAnimation { tasks.removeAll(where: \.done) }
                }
                .controlSize(.large)
                .accessibilityIdentifier("clear-done")
                .disabled(!tasks.contains(where: \.done))
            }
        }
        .padding(28)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func add() {
        let title = draft.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        withAnimation(.snappy) {
            tasks.append(TaskItem(title: title, project: Project.all[tasks.count % Project.all.count], time: "16:00"))
        }
        draft = ""
    }
}

struct SidebarRow: View {
    let title: String
    let symbol: String
    let color: Color
    let count: Int

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(color.gradient, in: .rect(cornerRadius: 6))
            Text(title).font(.body)
            Spacer()
            Text("\(count)").font(.callout.monospacedDigit()).foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

struct TaskCard: View {
    @Binding var item: TaskItem

    var body: some View {
        HStack(spacing: 14) {
            Toggle(item.title, isOn: $item.done)
                .toggleStyle(.checkbox)
                .controlSize(.large)
                .font(.title3)
                .strikethrough(item.done)
                .foregroundStyle(item.done ? .secondary : .primary)
            Spacer()
            Text(item.project.id)
                .font(.callout.weight(.medium))
                .foregroundStyle(item.project.color)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(item.project.color.opacity(0.14), in: .capsule)
            Label(item.time, systemImage: "clock")
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.background, in: .rect(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
    }
}

@main
struct TasksForMacApp: App {
    init() {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate()
    }

    var body: some Scene {
        WindowGroup("Tasks") {
            ContentView()
        }
        .defaultSize(width: 1024, height: 576)
    }
}
