import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "flower")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Rosette")
                .font(.largeTitle)
            Text("A tavern circuit of ancient board games")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
