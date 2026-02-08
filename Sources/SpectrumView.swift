import SwiftUI

// MARK: - Visualization Mode
enum VisualizationMode {
    case bars
    case oscilloscope
}

// MARK: - Modern Animated Spectrum Visualizer
struct ClassicVisualizerView: View {
    @EnvironmentObject var audioPlayer: AudioPlayer
    @State private var peakHeights: [CGFloat] = Array(repeating: 0, count: 15)
    @State private var peakHoldTimer: [TimeInterval] = Array(repeating: 0, count: 15)
    @State private var smoothedHeights: [CGFloat] = Array(repeating: 0, count: 15)
    @AppStorage("visualizationMode") private var visualizationModeRaw: Int = 0
    @State private var waveformBuffer: [(left: Float, right: Float)] = []
    
    // Waveform state for smooth oscillations
    @State private var wavePhase: Double = 0.0
    @State private var prevLeft: Float = 0
    @State private var prevRight: Float = 0
    
    private var visualizationMode: VisualizationMode {
        visualizationModeRaw == 0 ? .bars : .oscilloscope
    }

    let columns = 15
    let barWidth: CGFloat = 4.5
    let barSpacing: CGFloat = 0.8
    let maxBufferSize = 300 // Number of bars to show
    
    var body: some View {
        GeometryReader { geometry in
            Group {
                if visualizationMode == .bars {
                    barsVisualization(size: geometry.size)
                } else {
                    oscilloscopeVisualization(size: geometry.size)
                }
            }
            .background(Color.black)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.3)) {
                    let newMode: VisualizationMode = visualizationMode == .bars ? .oscilloscope : .bars
                    visualizationModeRaw = newMode == .bars ? 0 : 1
                }
            }
        }
    }
    
    private func barsVisualization(size: CGSize) -> some View {
        // 1. Move the gradient out of the loop to save massive CPU cycles
        let barGradient = GraphicsContext.Shading.linearGradient(
            Gradient(stops: [
                .init(color: .green, location: 0.0),
                .init(color: Color(red: 0.5, green: 1.0, blue: 0.0), location: 0.3),
                .init(color: .yellow, location: 0.5),
                .init(color: .orange, location: 0.7),
                .init(color: .red, location: 0.85)
            ]),
            startPoint: CGPoint(x: 0, y: size.height),
            endPoint: CGPoint(x: 0, y: 0)
        )

        return Canvas { context, canvasSize in
            let barWidth = (canvasSize.width - CGFloat(columns - 1) * barSpacing) / CGFloat(columns)

            // Use single paths for "Batch Drawing"
            var barsPath = Path()
            var peaksPath = Path()

            for col in 0..<columns {
                let x = CGFloat(col) * (barWidth + barSpacing)

                // Safety check for array bounds
                let barHeight = col < smoothedHeights.count ? smoothedHeights[col] : 0
                let peakHeight = col < peakHeights.count ? peakHeights[col] : 0

                // Main Bar
                let barRect = CGRect(x: x, y: canvasSize.height - barHeight, width: barWidth, height: barHeight)
                barsPath.addRect(barRect)

                // Peak Line (only if significant)
                if peakHeight > 2 {
                    let peakRect = CGRect(x: x, y: canvasSize.height - peakHeight - 1, width: barWidth, height: 2)
                    peaksPath.addRect(peakRect)
                }
            }

            // DRAW CALL 1: All bars at once with gradient
            context.fill(barsPath, with: barGradient)

            // DRAW CALL 2: All peaks at once
            context.fill(peaksPath, with: .color(.gray))

            // DRAW CALL 3: Optimized Baseline
            var baselinePath = Path()
            baselinePath.move(to: CGPoint(x: 0, y: canvasSize.height - 2))
            baselinePath.addLine(to: CGPoint(x: canvasSize.width, y: canvasSize.height - 2))
            context.stroke(baselinePath, with: .color(Color(red: 0.2, green: 0.4, blue: 0.8)), style: StrokeStyle(lineWidth: 1, dash: [1, 3]))
        }
        .drawingGroup()
        .onChange(of: audioPlayer.spectrumData) { newData in
            // Ensure this is using the "Gravity" logic we discussed to fix the slow fall
            updatePeaks(newData: newData, height: size.height)
        }
    }
    
    private func oscilloscopeVisualization(size: CGSize) -> some View {
        TimelineView(.animation(minimumInterval: 0.033)) { timeline in
            Canvas { context, canvasSize in
                let centerY = canvasSize.height / 2
                let barWidth: CGFloat = 2.0
                let barSpacing: CGFloat = 1.0
                let totalBarWidth = barWidth + barSpacing
                
                // Calculate how many bars fit in the width
                let numBars = Int(canvasSize.width / totalBarWidth)
                
                // Get individual spectrum values for maximum dynamics
                let spectrumCount = audioPlayer.spectrumData.count
                
                // Draw static bars that dance up/down based on their position
                for i in 0..<numBars {
                    let x = CGFloat(i) * totalBarWidth
                    
                    // Calculate wave pattern based on position across screen
                    let spatialPhase = Double(i) * 0.25 // More spacing for dramatic waves
                    
                    // Map each bar to a spectrum index for direct response
                    let spectrumIndex = (i * spectrumCount) / numBars
                    let localFreq = CGFloat(audioPlayer.spectrumData[min(spectrumIndex, spectrumCount - 1)])
                    
                    // Slower, smoother time-based oscillators
                    let veryFast = sin(wavePhase * 2.5 + Double(i) * 0.1) * 0.35
                    let fast = cos(wavePhase * 1.8 + Double(i) * 0.05) * 0.3
                    let medium = sin(wavePhase * 1.2 + Double(i) * 0.08) * 0.25
                    let slow = cos(wavePhase * 0.6) * 0.2
                    let chaotic = sin(wavePhase * 1.5 + Double(i) * 0.15) * 0.15
                    let timeModulation = veryFast + fast + medium + slow + chaotic
                    
                    // Add per-bar randomness for organic chaos
                    let randomVariation = Double.random(in: 0.85...1.15)
                    
                    // Left channel (red) - very complex wave with many harmonics
                    let leftWaveShape = sin(spatialPhase) * 0.4 + 
                                       sin(spatialPhase * 3.1) * 0.3 + 
                                       sin(spatialPhase * 0.6) * 0.2 +
                                       cos(spatialPhase * 1.7) * 0.15
                    let leftDynamic = abs(leftWaveShape * (0.3 + Double(localFreq) * 2.5) * (0.5 + timeModulation) * randomVariation)
                    
                    // Right channel (blue) - completely different harmonics
                    let rightWaveShape = sin(spatialPhase * 1.3 + 0.7) * 0.4 + 
                                        cos(spatialPhase * 2.4 + 1.2) * 0.3 +
                                        sin(spatialPhase * 0.8 + 0.4) * 0.2 +
                                        cos(spatialPhase * 1.9 + 1.5) * 0.15
                    let rightDynamic = abs(rightWaveShape * (0.3 + Double(localFreq) * 2.5) * (0.5 + sin(wavePhase * 1.4 + Double(i) * 0.12) + cos(wavePhase * 1.9) * 0.4) * randomVariation)
                    
                    // Much more aggressive amplitude scaling
                    let leftAmp = min(CGFloat(leftDynamic) * canvasSize.height * 0.5, canvasSize.height / 2 - 1)
                    let rightAmp = min(CGFloat(rightDynamic) * canvasSize.height * 0.5, canvasSize.height / 2 - 1)
                    
                    // Draw vertical bar
                    // Bottom half represents left channel (red)
                    let leftTop = centerY
                    let leftBottom = centerY + leftAmp
                    
                    var leftPath = Path()
                    leftPath.move(to: CGPoint(x: x, y: leftTop))
                    leftPath.addLine(to: CGPoint(x: x, y: leftBottom))
                    context.stroke(leftPath, with: .color(Color(red: 1.0, green: 0.0, blue: 0.0)), lineWidth: barWidth)
                    
                    // Top half represents right channel (blue)
                    let rightTop = centerY - rightAmp
                    let rightBottom = centerY
                    
                    var rightPath = Path()
                    rightPath.move(to: CGPoint(x: x, y: rightTop))
                    rightPath.addLine(to: CGPoint(x: x, y: rightBottom))
                    context.stroke(rightPath, with: .color(Color(red: 0.0, green: 0.5, blue: 1.0)), lineWidth: barWidth)
                }
                
                // Draw center line
                var centerLine = Path()
                centerLine.move(to: CGPoint(x: 0, y: centerY))
                centerLine.addLine(to: CGPoint(x: canvasSize.width, y: centerY))
                context.stroke(centerLine, with: .color(Color(red: 0.2, green: 0.4, blue: 0.8).opacity(0.5)), lineWidth: 1)
                
                // Draw blue dotted baseline at the bottom (boundary marker)
                let dotSpacing: CGFloat = 3
                let dotSize: CGFloat = 1
                for i in stride(from: 0, to: canvasSize.width, by: dotSpacing) {
                    let dotRect = CGRect(x: i, y: canvasSize.height - 2, width: dotSize, height: dotSize)
                    context.fill(
                        Path(ellipseIn: dotRect),
                        with: .color(Color(red: 0.2, green: 0.4, blue: 0.8))
                    )
                }
            }
            .onChange(of: audioPlayer.spectrumData) { newData in
                updateWaveformBuffer(spectrumData: newData)
            }
        }
    }
    
    private func updateWaveformBuffer(spectrumData: [Float]) {
        // Calculate amplitude from spectrum data
        let amplitude = spectrumData.reduce(0, +) / Float(spectrumData.count)
        
        // Advance wave phase (creates the oscillation effect)
        wavePhase += 0.15 // Speed of oscillation (reduced for slower movement)
        
        // Generate waveform-like patterns using sine waves that oscillate from 0 to 1
        // These create the "bouncing" effect
        let wave1 = sin(wavePhase * 1.2) // Primary wave
        let wave2 = sin(wavePhase * 2.1 + 0.5) // Harmonic
        let wave3 = sin(wavePhase * 0.8 + 1.0) // Sub-harmonic
        
        // Combine waves and map from [-1,1] to [0,1] for bouncing from zero
        let baseWave = (wave1 * 0.5 + wave2 * 0.3 + wave3 * 0.2)
        
        // Scale by audio amplitude - louder audio = bigger bounces
        let scale = Float(amplitude) * 3.0
        
        // Create stereo variation with different phase offsets
        // Left channel 
        let leftWave = sin(wavePhase * 0.95)
        let leftHarmonic = sin(wavePhase * 1.9 + 0.3)
        let leftCombined = (leftWave * 0.6 + leftHarmonic * 0.4 + baseWave * 0.3)
        
        // Right channel - different frequency/phase for stereo separation
        let rightWave = sin(wavePhase * 1.05 + 0.7)
        let rightHarmonic = sin(wavePhase * 2.3 + 0.8)
        let rightCombined = (rightWave * 0.6 + rightHarmonic * 0.4 + baseWave * 0.3)
        
        // Map sine output [-1,1] to [0,1] range - this creates the bounce from zero
        var leftValue = Float(leftCombined + 1.0) / 2.0 // Now ranges 0 to 1
        var rightValue = Float(rightCombined + 1.0) / 2.0
        
        // Apply audio amplitude scaling
        leftValue *= scale
        rightValue *= scale
        
        // Add randomness for more dynamic variation
        leftValue += Float.random(in: -0.08...0.08) * amplitude
        rightValue += Float.random(in: -0.08...0.08) * amplitude
        
        // Very light smoothing only to prevent extreme jumps
        let smoothing: Float = 0.1
        prevLeft = prevLeft * smoothing + leftValue * (1 - smoothing)
        prevRight = prevRight * smoothing + rightValue * (1 - smoothing)
        
        // Clamp to 0-1 range
        let finalLeft = min(max(prevLeft, 0.0), 1.0)
        let finalRight = min(max(prevRight, 0.0), 1.0)
        
        waveformBuffer.append((left: finalLeft, right: finalRight))

        if waveformBuffer.count > maxBufferSize {
            waveformBuffer.removeFirst()
        }
    }    

    private func updatePeaks(newData: [Float], height: CGFloat) {
        let currentTime = Date().timeIntervalSince1970

        // ADJUST THESE FOR "VIOLENT" MOVEMENT:
        let gravity: CGFloat = 12.0      // Pixels the main bars drop per frame
        let peakGravity: CGFloat = 4.0   // Pixels the peak lines drop per frame
        let peakHold: Double = 0.2        // Seconds the peak stays before falling

        let count = min(columns, newData.count)

        for i in 0..<count {
            let targetHeight = CGFloat(newData[i]) * height * 0.95

            // --- BAR LOGIC (The Gradient Bars) ---
            if targetHeight > smoothedHeights[i] {
                smoothedHeights[i] = targetHeight // Jump up instantly
            } else {
                // Constant drop speed (Gravity) prevents the "slow-down" at the bottom
                smoothedHeights[i] = max(targetHeight, smoothedHeights[i] - gravity)
            }

            // --- PEAK LOGIC (The Grey Lines) ---
            if targetHeight > peakHeights[i] {
                peakHeights[i] = targetHeight
                peakHoldTimer[i] = currentTime
            } else if currentTime - peakHoldTimer[i] > peakHold {
                peakHeights[i] = max(0, peakHeights[i] - peakGravity)
            }
        }
    }
}

// Keep old one for compatibility but unused
struct SpectrumView: View {
    @EnvironmentObject var audioPlayer: AudioPlayer
    
    var body: some View {
        ClassicVisualizerView()
    }
}

struct SpectrumBar: View {
    let value: Float
    let height: CGFloat
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            WinampColors.spectrumDot,
                            WinampColors.spectrumDot.opacity(0.7),
                            WinampColors.spectrumDot.opacity(0.4)
                        ],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .frame(height: CGFloat(value) * height * 0.8)
        }
        .frame(maxWidth: .infinity)
    }
}

