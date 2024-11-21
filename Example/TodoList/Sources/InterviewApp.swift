import SwiftStore
import SwiftUI

// Define the state
struct InterviewState: StateType, Codable {
  struct Interview: Identifiable, Equatable {
    let id: UUID = UUID()
    var candidateName: String
    var stage: Stage
    var rejectionReason: String?
    var date: Date?  // Optional date for the interview

    enum Stage: String, CaseIterable {
      case interviewing = "Interviewing"
      case offered = "Offered"
      case rejected = "Rejected"
    }
  }

  var interviews: [Interview] = []

  enum Action {
    case add(String)
    case setStage(UUID, Interview.Stage)
    case reject(UUID, String)
    case setOffered(UUID)  // New action to set the stage to "Offer"
    case updateDate(UUID, Date)  // Action to update the date
    case reset  // New action to clear the state
  }
}

// Add Codable conformance to Interview and Stage
extension InterviewState.Interview: Codable {}
extension InterviewState.Interview.Stage: Codable {}

// Define the reducer
private func interviewReducer(state: InterviewState, action: InterviewState.Action)
  -> InterviewState
{
  var newState = state

  switch action {
  case .reset:
    newState.interviews = []
  case .add(let candidateName):
    newState.interviews.append(
      InterviewState.Interview(candidateName: candidateName, stage: .interviewing))
  case .setStage(let id, let newStage):
    if let index = newState.interviews.firstIndex(where: { $0.id == id }) {
      newState.interviews[index].stage = newStage
      if newStage != .rejected {
        newState.interviews[index].rejectionReason = nil
      }
    }
  case .reject(let id, let reason):
    if let index = newState.interviews.firstIndex(where: { $0.id == id }) {
      newState.interviews[index].stage = .rejected
      newState.interviews[index].rejectionReason = reason
    }
  case .setOffered(let id):
    if let index = newState.interviews.firstIndex(where: { $0.id == id }) {
      newState.interviews[index].stage = .offered
    }
  case .updateDate(let id, let date):
    if let index = newState.interviews.firstIndex(where: { $0.id == id }) {
      newState.interviews[index].date = date
    }
  }

  return newState
}

// Example logging middleware
func makeLoggingMiddleware() -> Middleware<InterviewState> {
  return { getState, dispatch, next, action in
    print("⚡️ Before action: \(action)")
    print("📝 Current state: \(getState())")

    await next(action)

    print("✅ After action: \(action)")
    print("📝 New state: \(getState())")
  }
}

// Create a storage middleware
func makeStorageMiddleware() -> Middleware<InterviewState> {
  let defaults = UserDefaults.standard
  let storageKey = "interview_state"

  // Load initial state if available
  let initialState: InterviewState? = {
    guard let data = defaults.data(forKey: storageKey),
      let state = try? JSONDecoder().decode(InterviewState.self, from: data)
    else {
      return nil
    }
    return state
  }()

  return { getState, dispatch, next, action in
    // First, process the action
    await next(action)

    // Then, save the updated state
    let currentState = getState()
    if let encoded = try? JSONEncoder().encode(currentState) {
      defaults.set(encoded, forKey: storageKey)
    }
  }
}

// Add delay middleware
func makeDelayMiddleware(duration: TimeInterval = 0.3) -> Middleware<InterviewState> {
  return { getState, dispatch, next, action in
    // Add delay before processing action
    try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))

    // Process the action
    await next(action)
  }
}

public struct InterviewList: View {
  @Store(
    initialState: {
      // Try to load saved state, fall back to empty state
      let defaults = UserDefaults.standard
      let storageKey = "interview_state"

      if let data = defaults.data(forKey: storageKey),
        let state = try? JSONDecoder().decode(InterviewState.self, from: data)
      {
        return state
      }
      return InterviewState()
    }(),
    reducer: interviewReducer,
    middleware: [
      makeStorageMiddleware()
      // makeDelayMiddleware(duration: 0.3),
    ]
  ) private var store

  @State private var newCandidateName = ""
  @State private var rejectionReason = ""
  @State private var showingRejectionAlert = false
  @State private var selectedInterviewId: UUID?

  private func stageColor(_ stage: InterviewState.Interview.Stage) -> Color {
    switch stage {
    case .interviewing: return .blue
    case .offered: return .green
    case .rejected: return .red
    }
  }

  private func loadDemoData() {
    let companies = [
      "Google", "Apple", "Meta", "Amazon", "Netflix",
      "Microsoft", "Twitter", "Uber", "Airbnb", "LinkedIn",
      "Stripe", "Square", "Coinbase", "Robinhood", "Spotify",
      "ByteDance", "Tesla", "Slack", "Zoom", "Palantir",
    ]

    let rejectionReasons = [
      "Team fit concerns",
      "Technical skills gap",
      "Experience level mismatch",
      "Position filled internally",
      "Hiring freeze",
    ]

    // Generate 10-20 random interviews
    let count = Int.random(in: 10...20)

    // Create demo interviews using existing actions
    Task {
      for _ in 0..<count {
        let company = companies.randomElement()!
        store.dispatch(.add(company))

        // Get the ID of the just-added interview
        if let id = store.state.interviews.first?.id {
          // Randomly set stage with equal distribution
          let randomValue = Double.random(in: 0...1)
          let stage: InterviewState.Interview.Stage

          switch randomValue {
          case 0..<0.4:  // 40% interviewing
            stage = .interviewing
          case 0.4..<0.7:  // 30% offered
            stage = .offered
          default:  // 30% rejected
            stage = .rejected
          }

          print(stage)

          store.dispatch(.setStage(id, stage))

          if stage == .rejected {
            store.dispatch(.reject(id, rejectionReasons.randomElement()!))
          } else if stage == .offered {
            store.dispatch(.setStage(id, .offered))
          }
          // No need to dispatch for .interviewing as it's the default

          // Add random date if not rejected
          if stage != .rejected {
            let randomDays = Int.random(in: 1...30)
            let futureDate = Calendar.current.date(
              byAdding: .day,
              value: randomDays,
              to: Date()
            )!
            await store.dispatch(.updateDate(id, futureDate))
          }
        }
      }
      print(store.state)

    }
  }

  // Add computed properties to group interviews
  private var interviewingCandidates: [InterviewState.Interview] {
    store.state.interviews.filter { $0.stage == .interviewing }
  }

  private var offeredCandidates: [InterviewState.Interview] {
    store.state.interviews.filter { $0.stage == .offered }
  }

  private var rejectedCandidates: [InterviewState.Interview] {
    store.state.interviews.filter { $0.stage == .rejected }
  }

  public var body: some View {
    NavigationView {
      VStack {
        // Add candidate input
        HStack {
          TextField("Candidate Name", text: $newCandidateName)
            .textFieldStyle(RoundedBorderTextFieldStyle())

          Button(action: {
            guard !newCandidateName.isEmpty else { return }
            store.dispatch(.add(newCandidateName))
            newCandidateName = ""
          }) {
            Image(systemName: "plus.circle.fill")
              .foregroundColor(.blue)
          }
        }
        .padding()

        // Interview list
        List {
          // Interviewing Section
          Section(header: Text("Interviewing (\(interviewingCandidates.count))")) {
            ForEach(interviewingCandidates) { interview in
              InterviewRow(interview: interview, store: store)
            }
          }

          // Offered Section
          Section(header: Text("Offered (\(offeredCandidates.count))")) {
            ForEach(offeredCandidates) { interview in
              InterviewRow(interview: interview, store: store)
            }
          }

          // Rejected Section
          Section(header: Text("Rejected (\(rejectedCandidates.count))")) {
            ForEach(rejectedCandidates) { interview in
              InterviewRow(interview: interview, store: store)
            }
          }
        }
        .listStyle(InsetGroupedListStyle())
      }
      .navigationTitle("Interview Tracker")
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          HStack {
            Button(action: {
              store.dispatch(.reset)
            }) {
              Image(systemName: "trash")
                .foregroundColor(.red)
            }

            Button(action: {
              store.undo()
            }) {
              Image(systemName: "arrow.uturn.backward.circle")
            }
            .disabled(!store.canUndo)

            Button(action: {
              withAnimation {
                loadDemoData()
              }
            }) {
              Image(systemName: "wand.and.stars")
            }
          }
        }
      }
    }
  }
}

// Extract interview row to a separate view for cleaner code
struct InterviewRow: View {
  let interview: InterviewState.Interview
  let store: ObservableStore<CoreStore<InterviewState>>
  @State private var showingRejectionAlert = false
  @State private var rejectionReason = ""

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      // Row 1: Name and Stage
      HStack {
        HStack {
          Circle()
            .fill(stageColor(interview.stage))
            .frame(width: 8, height: 8)

          Text(interview.candidateName)
            .font(.headline)
        }

        Spacer()

        // Star button to set the stage to "Offer"
        if interview.stage == .offered {
          Button(action: {
            store.dispatch(.setOffered(interview.id))
          }) {
            Image(systemName: "star.fill")
              .foregroundColor(.yellow)
          }
        }
      }

      Picker(
        "Status",
        selection: Binding(
          get: { interview.stage },
          set: { newStage in
            if newStage == .rejected {
              showingRejectionAlert = true
            } else {
              store.dispatch(.setStage(interview.id, newStage))
            }
          }
        )
      ) {
        ForEach(InterviewState.Interview.Stage.allCases, id: \.self) { stage in
          HStack {
            Circle()
              .fill(stageColor(stage))
              .frame(width: 6, height: 6)
            Text(stage.rawValue)
          }.tag(stage)
        }
      }
      .pickerStyle(MenuPickerStyle())

      if interview.stage == .rejected {
        Text("Reason: \(interview.rejectionReason ?? "N/A")")
          .foregroundColor(.gray)
          .italic()
      }

      // Date Picker
      if interview.stage != .rejected {
        DatePicker(
          "Next interview",
          selection: Binding(
            get: { interview.date ?? Date() },
            set: { newDate in
              store.dispatch(.updateDate(interview.id, newDate))
            }
          ),
          displayedComponents: .date
        )
        .datePickerStyle(CompactDatePickerStyle())
      }
    }
    .padding(.vertical, 5)
    .alert("Rejection Reason", isPresented: $showingRejectionAlert) {
      TextField("Enter reason", text: $rejectionReason)
      Button("Cancel", role: .cancel) {
        rejectionReason = ""
      }
      Button("Confirm") {
        store.dispatch(.reject(interview.id, rejectionReason))
        rejectionReason = ""
      }
    } message: {
      Text("Please provide a reason for rejection")
    }
  }

  private func stageColor(_ stage: InterviewState.Interview.Stage) -> Color {
    switch stage {
    case .interviewing: return .blue
    case .offered: return .green
    case .rejected: return .red
    }
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    InterviewList()
  }
}
