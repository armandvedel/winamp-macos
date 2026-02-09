import SwiftUI

// MARK: - Visualization Mode
enum VisualizationMode: Int, CaseIterable {
    case bars = 0
    case oscilloscope = 1
}

// MARK: - Modern Animated Spectrum Visualizer
struct ClassicVisualizerView: View {
    @AppStorage("selectedVizMode") private var visualizationMode: VisualizationMode = .bars
    @EnvironmentObject var audioPlayer: AudioPlayer    
    enum VizMode { case bars, oscilloscope }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                
                // Switcher: The inactive mode is completely removed from memory
                if visualizationMode == .bars {
                    BarsVisualization(size: geometry.size)
                } else {
                    OscilloscopeVisualization(size: geometry.size)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                visualizationMode = (visualizationMode == .bars ? .oscilloscope : .bars)
            }
        }
    }
}

struct BarsVisualization: View {
    //@EnvironmentObject var audioPlayer: AudioPlayer
    @ObservedObject private var spectrum = SpectrumBuffer.shared
    let size: CGSize
    
    // Move the state here so it lives and dies with this specific view
    @State private var peakHeights: [CGFloat] = Array(repeating: 0, count: 15)
    @State private var peakHoldTimer: [TimeInterval] = Array(repeating: 0, count: 15)
    @State private var smoothedHeights: [CGFloat] = Array(repeating: 0, count: 15)
    
    let columns = 15
    let barSpacing: CGFloat = 0.8

    var body: some View {
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

        Canvas { context, canvasSize in
            let barWidth = (canvasSize.width - CGFloat(columns - 1) * barSpacing) / CGFloat(columns)

            var barsPath = Path()
            var peaksPath = Path()

            for col in 0..<columns {
                let x = CGFloat(col) * (barWidth + barSpacing)

                let barHeight = col < smoothedHeights.count ? smoothedHeights[col] : 0
                let peakHeight = col < peakHeights.count ? peakHeights[col] : 0

                let barRect = CGRect(x: x, y: canvasSize.height - barHeight, width: barWidth, height: barHeight)
                barsPath.addRect(barRect)

                if peakHeight > 2 {
                    let peakRect = CGRect(x: x, y: canvasSize.height - peakHeight - 1, width: barWidth, height: 2)
                    peaksPath.addRect(peakRect)
                }
            }

            context.fill(barsPath, with: barGradient)
            context.fill(peaksPath, with: .color(.gray))

            var baselinePath = Path()
            baselinePath.move(to: CGPoint(x: 0, y: canvasSize.height - 2))
            baselinePath.addLine(to: CGPoint(x: canvasSize.width, y: canvasSize.height - 2))
            context.stroke(baselinePath, with: .color(Color(red: 0.2, green: 0.4, blue: 0.8)), style: StrokeStyle(lineWidth: 1, dash: [1, 3]))
        }
        .drawingGroup()
        .onChange(of: SpectrumBuffer.shared.spectrumData) { newData in
            updatePeaks(newData: newData, height: size.height)
        }
    }

    private func updatePeaks(newData: [Float], height: CGFloat) {
        let gravity: CGFloat = 0.15 
        let currentTimestamp = Date().timeIntervalSince1970

        for i in 0..<min(newData.count, columns) {
            let targetHeight = CGFloat(newData[i]) * height
            
            // Update Smooth Bars
            smoothedHeights[i] = (smoothedHeights[i] * 0.7) + (targetHeight * 0.3)
            
            // Update Peaks
            if targetHeight >= peakHeights[i] {
                peakHeights[i] = targetHeight
                peakHoldTimer[i] = currentTimestamp + 0.5 
            } else if currentTimestamp > peakHoldTimer[i] {
                peakHeights[i] = max(0, peakHeights[i] - gravity)
            }
        }
    }
}

struct OscilloscopeVisualization: View {
    @EnvironmentObject var audioPlayer: AudioPlayer
    let size: CGSize
    
    // WavePhase now lives only as long as the Oscilloscope is active
    @State private var wavePhase: Double = 0.0
    @State private var prevLeft: Float = 0.0
    @State private var prevRight: Float = 0.0
    @State private var waveformBuffer: [(left: Float, right: Float)] = []
    let maxBufferSize = 100 // How many points to show in the history
    
    var body: some View {
        // TimelineView starts when this struct appears and stops when it disappears
        TimelineView(.animation(minimumInterval: 0.033)) { timeline in
            Canvas { context, canvasSize in
                let centerY = canvasSize.height / 2
                let barWidth: CGFloat = 2.0
                let barSpacing: CGFloat = 1.0
                let totalBarWidth = barWidth + barSpacing
                let numBars = Int(canvasSize.width / totalBarWidth)
                let spectrumCount = SpectrumBuffer.shared.spectrumData.count
                
                // BATCH PATHS: We collect all lines here first
                var leftChannelPath = Path()
                var rightChannelPath = Path()
                
                for i in 0..<numBars {
                    let x = CGFloat(i) * totalBarWidth
                    let spatialPhase = Double(i) * 0.25
                    let spectrumIndex = (i * spectrumCount) / numBars
                    let localFreq = CGFloat(SpectrumBuffer.shared.spectrumData[min(spectrumIndex, spectrumCount - 1)])
                    
                    // Complex Wave Math
                    let veryFast = sin(wavePhase * 2.5 + Double(i) * 0.1) * 0.35
                    let fast = cos(wavePhase * 1.8 + Double(i) * 0.05) * 0.3
                    let medium = sin(wavePhase * 1.2 + Double(i) * 0.08) * 0.25
                    let slow = cos(wavePhase * 0.6) * 0.2
                    let chaotic = sin(wavePhase * 1.5 + Double(i) * 0.15) * 0.15
                    let timeModulation = veryFast + fast + medium + slow + chaotic
                    let randomVariation = Double.random(in: 0.85...1.15)
                    
                    // Left Channel Calculation
                    let leftWaveShape = sin(spatialPhase) * 0.4 + sin(spatialPhase * 3.1) * 0.3 + sin(spatialPhase * 0.6) * 0.2 + cos(spatialPhase * 1.7) * 0.15
                    let leftDynamic = abs(leftWaveShape * (0.3 + Double(localFreq) * 2.5) * (0.5 + timeModulation) * randomVariation)
                    let leftAmp = min(CGFloat(leftDynamic) * canvasSize.height * 0.5, canvasSize.height / 2 - 1)
                    
                    // Add Left Bar to Path
                    leftChannelPath.move(to: CGPoint(x: x, y: centerY))
                    leftChannelPath.addLine(to: CGPoint(x: x, y: centerY + leftAmp))
                    
                    // Right Channel Calculation
                    let rightWaveShape = sin(spatialPhase * 1.3 + 0.7) * 0.4 + cos(spatialPhase * 2.4 + 1.2) * 0.3 + sin(spatialPhase * 0.8 + 0.4) * 0.2 + cos(spatialPhase * 1.9 + 1.5) * 0.15
                    let rightDynamic = abs(rightWaveShape * (0.3 + Double(localFreq) * 2.5) * (0.5 + sin(wavePhase * 1.4 + Double(i) * 0.12) + cos(wavePhase * 1.9) * 0.4) * randomVariation)
                    let rightAmp = min(CGFloat(rightDynamic) * canvasSize.height * 0.5, canvasSize.height / 2 - 1)
                    
                    // Add Right Bar to Path
                    rightChannelPath.move(to: CGPoint(x: x, y: centerY - rightAmp))
                    rightChannelPath.addLine(to: CGPoint(x: x, y: centerY))
                }
                
                // DRAW CALL 1: All Red bars at once
                context.stroke(leftChannelPath, with: .color(.red), lineWidth: barWidth)
                
                // DRAW CALL 2: All Blue bars at once
                context.stroke(rightChannelPath, with: .color(Color(red: 0.0, green: 0.5, blue: 1.0)), lineWidth: barWidth)
                
                // Static Elements (Center line and Dotted Baseline)
                var staticElements = Path()
                staticElements.move(to: CGPoint(x: 0, y: centerY))
                staticElements.addLine(to: CGPoint(x: canvasSize.width, y: centerY))
                context.stroke(staticElements, with: .color(Color.blue.opacity(0.3)), lineWidth: 1)
                
                // Dotted line at bottom
                let dotPath = Path { p in
                    for i in stride(from: 0, to: canvasSize.width, by: 3) {
                        p.addEllipse(in: CGRect(x: i, y: canvasSize.height - 2, width: 1, height: 1))
                    }
                }
                context.fill(dotPath, with: .color(Color(red: 0.2, green: 0.4, blue: 0.8)))
            }
        }
        .onAppear {
            // Start the phase animation
            startAnimation()
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
    
    private func startAnimation() {
        // We use a simple Timer or the TimelineView phase to keep it moving
        // To keep it simple, we can update wavePhase via the TimelineView context if preferred,
        // but updating it here via a DisplayLink or Timer works well for State.
        Timer.scheduledTimer(withTimeInterval: 0.033, repeats: true) { _ in
            wavePhase += 0.1
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

