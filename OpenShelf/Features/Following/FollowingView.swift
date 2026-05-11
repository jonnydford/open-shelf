import SwiftUI

struct FollowingView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label("Following", systemImage: "person.2")
            } description: {
                Text("Follow friends to see what they're reading. Share your shelf link from Settings to get started.")
            }
            .navigationTitle("Following")
        }
    }
}
