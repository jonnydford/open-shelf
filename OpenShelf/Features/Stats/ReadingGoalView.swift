import SwiftUI
import SwiftData
import WidgetKit

struct ReadingGoalView: View {
    let booksReadCount: Int
    let year: Int
    let goal: ReadingGoal?

    @State private var showSetGoal = false
    @State private var celebrationScale: CGFloat = 1.0
    @State private var celebrationOpacity: Double = 1.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    private var progress: Double {
        guard let goal, goal.target > 0 else { return 0 }
        return min(Double(booksReadCount) / Double(goal.target), 1.0)
    }

    private var pace: Int {
        guard let goal else { return 0 }
        return StatsCalculator.goalPace(booksRead: booksReadCount, target: goal.target, year: year)
    }

    private var goalMet: Bool {
        guard let goal else { return false }
        return booksReadCount >= goal.target
    }

    var body: some View {
        VStack(spacing: 12) {
            if let goal {
                goalRing(target: goal.target)
            } else {
                setGoalPrompt
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .sheet(isPresented: $showSetGoal) {
            SetReadingGoalSheet(year: year, existingGoal: goal)
        }
    }

    private func goalRing(target: Int) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.accentColor.opacity(colorSchemeContrast == .increased ? 0.35 : 0.2), lineWidth: 12)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        goalMet ? Color.green : Color.accentColor,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 1.0), value: progress)

                VStack(spacing: 2) {
                    Text("\(booksReadCount)")
                        .font(.title.bold())
                    Text("of \(target)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 120, height: 120)
            .scaleEffect(goalMet && !reduceMotion ? celebrationScale : 1.0)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Reading goal progress")
            .accessibilityValue("\(booksReadCount) of \(target) books, \(Int(progress * 100)) percent")

            if goalMet {
                Label("Goal reached!", systemImage: "party.popper.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(.green)
                    .opacity(reduceMotion ? 1.0 : celebrationOpacity)
                    .onAppear {
                        guard !reduceMotion else { return }
                        withAnimation(
                            .spring(duration: 0.6, bounce: 0.5)
                        ) {
                            celebrationScale = 1.15
                        }
                        withAnimation(
                            .spring(duration: 0.4, bounce: 0.3).delay(0.6)
                        ) {
                            celebrationScale = 1.0
                        }
                        withAnimation(
                            .easeInOut(duration: 0.8)
                                .repeatForever(autoreverses: true)
                        ) {
                            celebrationOpacity = 0.6
                        }
                    }
            } else {
                paceLabel
            }

            Button(goalMet ? "Increase Goal" : "Edit Goal") {
                showSetGoal = true
            }
            .font(.caption)
        }
    }

    @ViewBuilder
    private var paceLabel: some View {
        if pace > 0 {
            Text("\(pace) book\(pace == 1 ? "" : "s") ahead of schedule")
                .font(.caption)
                .foregroundStyle(.green)
                .accessibilityLabel("\(pace) book\(pace == 1 ? "" : "s") ahead of reading goal schedule")
        } else if pace < 0 {
            Text("\(abs(pace)) book\(abs(pace) == 1 ? "" : "s") behind schedule")
                .font(.caption)
                .foregroundStyle(.orange)
                .accessibilityLabel("\(abs(pace)) book\(abs(pace) == 1 ? "" : "s") behind reading goal schedule")
        } else {
            Text("Right on schedule")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var setGoalPrompt: some View {
        VStack(spacing: 8) {
            Image(systemName: "target")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Set a Reading Goal")
                .font(.headline)
            Text("Track your progress for \(String(year))")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Set Goal") {
                showSetGoal = true
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
    }
}

struct SetReadingGoalSheet: View {
    let year: Int
    let existingGoal: ReadingGoal?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var target: Int = 12

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper("Books: \(target)", value: $target, in: 1...365)
                } header: {
                    Text("\(String(year)) Reading Goal")
                }

                Section {
                    Text("That's about \(booksPerMonth) book\(booksPerMonth == 1 ? "" : "s") per month")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Reading Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
            .onAppear {
                if let existingGoal {
                    target = existingGoal.target
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var booksPerMonth: Int {
        max(1, Int((Double(target) / 12.0).rounded(.up)))
    }

    private func save() {
        if let existingGoal {
            existingGoal.target = target
        } else {
            let goal = ReadingGoal(year: year, target: target)
            modelContext.insert(goal)
        }
        try? modelContext.save()
        WidgetCenter.shared.reloadAllTimelines()
        dismiss()
    }
}
