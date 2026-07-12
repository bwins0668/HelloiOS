import SwiftUI

struct ContentView: View {
    var body: some View {
        ZStack {
            // Dark background
            Color(red: 0.04, green: 0.01, blue: 0.05)
                .ignoresSafeArea()
            
            GameView()
                .ignoresSafeArea()
        }
        .preferredColorScheme(.dark)
        .statusBarHidden()
    }
}

#Preview {
    ContentView()
}