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
        Canvas { context, canvasSize in
            let totalWidth = canvasSize.width
            let barWidth = (totalWidth - CGFloat(columns - 1) * barSpacing) / CGFloat(columns)
            
            for col in 0..<columns {
                let spectrumIndex = min(col, audioPlayer.spectrumData.count - 1)
                
                // Use smoothed height for smoother animation
                let barHeight = col < smoothedHeights.count ? smoothedHeights[col] : 0
                
                let x = CGFloat(col) * (barWidth + barSpacing)
                let y = canvasSize.height - barHeight
                
                // Draw main bar with gradient based on VERTICAL POSITION
                // Each part of the bar gets colored based on where it is vertically
                let barRect = CGRect(x: x, y: y, width: barWidth, height: barHeight)
                
                // Create gradient colors based on vertical position thresholds
                // Green (0-30%), Yellow-Green (30-50%), Yellow (50-70%), Orange (70-85%), Red (85-100%)
                let gradient = Gradient(stops: [
                    .init(color: Color(red: 0.0, green: 1.0, blue: 0.0), location: 0.0),    // Bottom: Green
                    .init(color: Color(red: 0.5, green: 1.0, blue: 0.0), location: 0.30),   // 30%: Yellow-Green
                    .init(color: Color(red: 1.0, green: 1.0, blue: 0.0), location: 0.50),   // 50%: Yellow
                    .init(color: Color(red: 1.0, green: 0.65, blue: 0.0), location: 0.70),  // 70%: Orange
                    .init(color: Color(red: 1.0, green: 0.0, blue: 0.0), location: 0.85),   // 85%: Red
                    .init(color: Color(red: 1.0, green: 0.0, blue: 0.0), location: 1.0)     // Top: Red
                ])
                
                // Apply gradient from bottom to top of the ENTIRE spectrum area
                // This way each bar shows the gradient color for its vertical position
                context.fill(
                    Path(barRect),
                    with: .linearGradient(
                        gradient,
                        startPoint: CGPoint(x: x, y: canvasSize.height),  // Bottom of spectrum
                        endPoint: CGPoint(x: x, y: 0)                      // Top of spectrum
                    )
                )
                
                // Draw peak indicator (grey bar at the top)
                if col < peakHeights.count && peakHeights[col] > 2 {
                    let peakY = canvasSize.height - peakHeights[col]
                    let peakRect = CGRect(x: x, y: peakY - 1, width: barWidth, height: 2)
                    
                    // Grey peak indicator
                    context.fill(
                        Path(peakRect),
                        with: .color(Color(red: 0.6, green: 0.6, blue: 0.6))
                    )
                }
            }
            
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
        let smoothingFactor: CGFloat = 0.3 // Lower = smoother/slower (0.3 = 30% new, 70% old)
        let amplitudeScale: CGFloat = 0.95 // Balanced amplitude - mostly green/yellow with occasional orange/red
        
        for i in 0..<min(columns, newData.count) {
            let targetHeight = CGFloat(newData[i]) * height * amplitudeScale
            
            // Smooth the bar height changes (slower rise and fall)
            if i < smoothedHeights.count {
                let currentSmoothed = smoothedHeights[i]
                
                // Rise quickly, fall slowly
                if targetHeight > currentSmoothed {
                    smoothedHeights[i] = currentSmoothed + (targetHeight - currentSmoothed) * 0.5 // Rise at 50% speed
                } else {
                    smoothedHeights[i] = currentSmoothed + (targetHeight - currentSmoothed) * smoothingFactor // Fall at 30% speed
                }
            }
            
            // Update peak if current value is higher
            if targetHeight > peakHeights[i] {
                peakHeights[i] = targetHeight
                peakHoldTimer[i] = currentTime
            }
            // Decay peak slowly after hold time
            else if currentTime - peakHoldTimer[i] > 0.8 {
                peakHeights[i] = max(peakHeights[i] - 1.5, 0) // Slower decay
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

