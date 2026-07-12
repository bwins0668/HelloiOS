import SwiftUI
import SpriteKit

struct GameView: View {
    var scene: GameScene {
        let scene = GameScene()
        scene.size = CGSize(width: 390, height: 844)
        scene.scaleMode = .aspectFill
        return scene
    }
    
    var body: some View {
        SpriteView(scene: scene)
            .ignoresSafeArea()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}