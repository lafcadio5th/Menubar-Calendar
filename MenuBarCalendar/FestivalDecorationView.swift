import SwiftUI

struct FestivalDecorationView: View {
    let festival: Festival
    
    // Config
    private let particleCount = 20
    
    var body: some View {
        if festival == .none {
            EmptyView()
        } else {
            GeometryReader { geometry in
                ZStack {
                    ForEach(0..<particleCount, id: \.self) { index in
                        FallingParticleView(
                            emojis: festival.emojis,
                            containerSize: geometry.size,
                            index: index
                        )
                    }
                }
            }
            .allowsHitTesting(false) // Ignore clicks so calendar works
        }
    }
}

struct FallingParticleView: View {
    let emojis: [String]
    let containerSize: CGSize
    let index: Int
    
    @State private var positionY: CGFloat
    @State private var swayOffset: CGFloat = 0
    @State private var rotationX: Double = 0
    @State private var rotationY: Double = 0
    @State private var rotationZ: Double = 0
    @State private var opacity: Double = 0
    
    let startX: CGFloat
    let scale: CGFloat
    let speed: Double
    let swayAmount: CGFloat
    let swayDuration: Double
    let delay: Double
    let emoji: String
    
    init(emojis: [String], containerSize: CGSize, index: Int) {
        self.emojis = emojis
        self.containerSize = containerSize
        self.index = index
        self.emoji = emojis.randomElement() ?? ""
        
        // Randomize initial parameters for organic look
        self.startX = CGFloat.random(in: 0...containerSize.width)
        self._positionY = State(initialValue: -CGFloat.random(in: 50...200)) // Start above screen
        
        // Depth effect: smaller particles move slower and are more transparent
        let depth = Double.random(in: 0.5...1.0)
        self.scale = CGFloat(depth * Double.random(in: 0.8...1.2))
        self.speed = Double.random(in: 10...20) / depth // Further (smaller) particles move slower? Actually usually faster for parallax, but for snow often smaller = slower. Let's try uniform random or classic physics.
        // Let's go with: varied speed unrelated to size for "floating" feel, but lighter things float longer.
        
        self.swayAmount = CGFloat.random(in: 20...80)
        self.swayDuration = Double.random(in: 2...4)
        self.delay = Double.random(in: 0...10)
    }
    
    var body: some View {
        Text(emoji)
            .font(.system(size: 24))
            .scaleEffect(scale)
            .opacity(opacity)
            .rotationEffect(.degrees(rotationZ))
            .rotation3DEffect(.degrees(rotationX), axis: (x: 1, y: 0, z: 0))
            .rotation3DEffect(.degrees(rotationY), axis: (x: 0, y: 1, z: 0))
            .offset(x: startX + swayOffset, y: positionY)
            .onAppear {
                // 1. Falling Animation
                withAnimation(
                    Animation.linear(duration: Double.random(in: 6...12))
                        .repeatForever(autoreverses: false)
                        .delay(delay)
                ) {
                    positionY = containerSize.height + 150
                }
                
                // 2. Swaying (Left/Right) - Sine wave motion
                // Using a simple autoreverse offset for sway
                withAnimation(
                    Animation.easeInOut(duration: swayDuration)
                        .repeatForever(autoreverses: true)
                        .delay(Double.random(in: 0...2))
                ) {
                    swayOffset = swayAmount * (index % 2 == 0 ? 1 : -1)
                }
                
                // 3. 3D Rotation / Tumbling
                withAnimation(
                    Animation.linear(duration: Double.random(in: 3...7))
                        .repeatForever(autoreverses: false)
                        .delay(Double.random(in: 0...2))
                ) {
                    // Randomize rotation axis and amount
                    if Bool.random() { rotationX = 360 }
                    if Bool.random() { rotationY = 360 }
                    rotationZ = Double.random(in: -45...45) // Slight permanent tilt or spin
                    if Bool.random() { rotationZ += 360 }
                }
                
                // 4. Fade In/Out cycle to simulate spawning/dying or catching light
                 withAnimation(
                    Animation.easeInOut(duration: 1.0)
                        .delay(delay)
                ) {
                    opacity = Double.random(in: 0.7...1.0) // Fade in
                }
            }
    }
}
