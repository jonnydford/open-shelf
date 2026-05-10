import SwiftUI
import SwiftData

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(\.modelContext) private var modelContext

    @State private var currentPage = 0
    @State private var goalTarget: Int = 12

    private let currentYear = Calendar.current.component(.year, from: .now)

    var body: some View {
        TabView(selection: $currentPage) {
            welcomePage
                .tag(0)

            getStartedPage
                .tag(1)

            readingGoalPage
                .tag(2)
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .interactiveDismissDisabled()
    }

    // MARK: - Welcome Page

    private var welcomePage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "books.vertical.fill")
                .font(.system(size: 72))
                .foregroundStyle(Color.accentColor)

            Text("Open Shelf")
                .font(.largeTitle.bold())

            Text("Your reading life.\nPrivate by design.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            Text("All your data stays on your device. No accounts, no tracking, no ads.")
                .font(.footnote)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            nextButton(label: "Get Started")
                .padding(.bottom, 32)
        }
        .padding(.horizontal)
    }

    // MARK: - Get Started Page

    private var getStartedPage: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("How would you like to start?")
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            VStack(spacing: 12) {
                Button {
                    completeOnboarding()
                } label: {
                    onboardingCard(
                        icon: "square.and.arrow.down",
                        title: "Import from Goodreads",
                        subtitle: "Bring your existing library over"
                    )
                }
                .buttonStyle(.plain)

                Button {
                    completeOnboarding()
                } label: {
                    onboardingCard(
                        icon: "barcode.viewfinder",
                        title: "Scan a book",
                        subtitle: "Point your camera at a barcode"
                    )
                }
                .buttonStyle(.plain)

                Button {
                    completeOnboarding()
                } label: {
                    onboardingCard(
                        icon: "magnifyingglass",
                        title: "Search for a book",
                        subtitle: "Find books on Open Library"
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)

            Spacer()

            Button {
                completeOnboarding()
            } label: {
                Text("I'll explore on my own")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            nextButton(label: "Next")
                .padding(.bottom, 32)
        }
        .padding(.horizontal)
    }

    // MARK: - Reading Goal Page

    private var readingGoalPage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "target")
                .font(.system(size: 48))
                .foregroundStyle(Color.accentColor)

            Text("Set a reading goal for \(String(currentYear))?")
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            VStack(spacing: 8) {
                Stepper("Books: \(goalTarget)", value: $goalTarget, in: 1...365)
                    .padding(.horizontal, 40)

                let booksPerMonth = max(1, Int((Double(goalTarget) / 12.0).rounded(.up)))
                Text("About \(booksPerMonth) book\(booksPerMonth == 1 ? "" : "s") per month")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)

            Spacer()

            Button {
                completeOnboarding()
            } label: {
                Text("Maybe later")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button {
                saveGoalAndComplete()
            } label: {
                Text("Set Goal & Start Reading")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .padding(.horizontal)
    }

    // MARK: - Components

    private func onboardingCard(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(Color.accentColor)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func nextButton(label: String) -> some View {
        Button {
            withAnimation {
                currentPage += 1
            }
        } label: {
            Text(label)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .padding(.horizontal)
    }

    // MARK: - Actions

    private func completeOnboarding() {
        hasCompletedOnboarding = true
    }

    private func saveGoalAndComplete() {
        let goal = ReadingGoal(year: currentYear, target: goalTarget)
        modelContext.insert(goal)
        try? modelContext.save()
        hasCompletedOnboarding = true
    }
}
