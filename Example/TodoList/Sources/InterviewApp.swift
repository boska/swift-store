import SwiftStore
import SwiftUI

// Define the state
struct InterviewState: StateType {
  struct Interview: Identifiable, Equatable {
    let id: UUID = UUID()
    var candidateName: String
    var stage: Stage
    var rejectionReason: String?
    var date: Date?  // Optional date for the interview

    enum Stage: String, CaseIterable {
      case firstInterview = "First Interview"
      case secondInterview = "Second Interview"
      case hrInterview = "HR Interview"
      case offer = "Offer"
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
  }
}

// Define the reducer
private func interviewReducer(state: InterviewState, action: InterviewState.Action)
  -> InterviewState
{
  var newState = state

  switch action {
  case .add(let candidateName):
    newState.interviews.append(
      InterviewState.Interview(candidateName: candidateName, stage: .firstInterview))
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
      newState.interviews[index].stage = .offer
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

public struct InterviewList: View {
  @Store(
    initialState: InterviewState(),
    reducer: interviewReducer,
    middleware: [makeLoggingMiddleware()]
  ) private var store

  @State private var newCandidateName = ""
  @State private var rejectionReason = ""
  @State private var showingRejectionAlert = false
  @State private var selectedInterviewId: UUID?

  private func stageColor(_ stage: InterviewState.Interview.Stage) -> Color {
    switch stage {
    case .firstInterview: return .blue
    case .secondInterview: return .purple
    case .hrInterview: return .orange
    case .offer: return .green
    case .rejected: return .red
    }
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
          ForEach(store.state.interviews) { interview in
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

                Picker(
                  "Stage",
                  selection: Binding(
                    get: { interview.stage },
                    set: { newStage in
                      if newStage == .rejected {
                        selectedInterviewId = interview.id
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
                .frame(width: 150)

                // Star button to set the stage to "Offer"
                if interview.stage != .offer {
                  Button(action: {
                    store.dispatch(.setOffered(interview.id))
                  }) {
                    Image(systemName: "star.fill")
                      .foregroundColor(.yellow)
                  }
                }
              }

              if interview.stage == .rejected {
                Text("Reason: \(interview.rejectionReason ?? "N/A")")
                  .foregroundColor(.gray)
                  .italic()
              }

              // Date Picker
              if interview.stage != .rejected {
                DatePicker(
                  "Interview Date",
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
          }
        }
      }
      .navigationTitle("Interview Tracker")
      .alert("Rejection Reason", isPresented: $showingRejectionAlert) {
        TextField("Enter reason", text: $rejectionReason)
        Button("Cancel", role: .cancel) {
          rejectionReason = ""
          selectedInterviewId = nil
        }
        Button("Confirm") {
          if let id = selectedInterviewId {
            store.dispatch(.reject(id, rejectionReason))
            rejectionReason = ""
            selectedInterviewId = nil
          }
        }
      } message: {
        Text("Please provide a reason for rejection")
      }
    }
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    InterviewList()
  }
}
