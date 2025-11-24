import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "photo.stack")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("PhotoKeepSafe")
                .font(.largeTitle)
                .fontWeight(.bold)
            Text("Your photos, securely stored")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
