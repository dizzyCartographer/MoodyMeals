import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var members: [FamilyMember]

    var body: some View {
        VStack(spacing: 12) {
            Text("MoodyMeals")
                .font(.largeTitle.bold())
            Text(members.isEmpty ? "Scaffold — M0" :
                 "Household: \(members.map(\.name).sorted().joined(separator: ", "))")
                .foregroundStyle(.secondary)
        }
        .padding()
        .task {
            try? SeedData.loadIfNeeded(into: modelContext)
        }
    }
}

#Preview {
    ContentView()
}
