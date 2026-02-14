import SwiftUI

// MARK: - Visualization Mode
enum VisualizationMode: Int, CaseIterable {
    case bars = 0
    case oscilloscope = 1
}

// MARK: - Modern Animated Spectrum Visualizer
struct ClassicVisualizerView: View {

    @AppStorage("selectedVizMode")
    private var storedMode: VisualizationMode = .bars

    @State
    private var visualizationMode: VisualizationMode = .bars

    @EnvironmentObject var audioPlayer: AudioPlayer

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black

                Group {
                    if visualizationMode == .bars {
                        BarsVisualization(size: geometry.size)
                    } else {
                        OscilloscopeVisualization(size: geometry.size)
                    }
                }
                .id(visualizationMode)
            }
            .onAppear {
                visualizationMode = storedMode
            }
            .onTapGesture {
                let newMode: VisualizationMode =
                    visualizationMode == .bars ? .oscilloscope : .bars

                visualizationMode = newMode     // immediate UI update
                storedMode = newMode            // persist
            }
        }
    }
}

class SpectrumProcessor: ObservableObject {
    // @Published ensures the View refreshes when these change
    @Published var smoothedHeights: [CGFloat] = Array(repeating: 0, count: 15)
    @Published var peakHeights: [CGFloat] = Array(repeating: 0, count: 15)
    
    private var peakHoldTimer: [TimeInterval] = Array(repeating: 0, count: 15)
    private let columns = 15
    private let gravity: CGFloat = 1.5 // Amount peaks fall per frame

    func update(with newData: [Float], totalHeight: CGFloat) {
        let currentTimestamp = Date().timeIntervalSince1970
        
        for i in 0..<min(newData.count, columns) {
            let targetHeight = CGFloat(newData[i]) * totalHeight
            
            // 1. Smooth the bars (Lerp-like smoothing)
            smoothedHeights[i] = (smoothedHeights[i] * 0.7) + (targetHeight * 0.3)
            
            // 2. Handle Peaks
            if targetHeight >= peakHeights[i] {
                // New peak reached: hold it
                peakHeights[i] = targetHeight
                peakHoldTimer[i] = currentTimestamp + 0.5 // 0.5s hold time
            } else if currentTimestamp > peakHoldTimer[i] {
                // Hold time expired: apply gravity
                peakHeights[i] = max(0, peakHeights[i] - gravity)
            }
        }
    }
}

struct BarsVisualization: View {
    @ObservedObject private var spectrum = SpectrumBuffer.shared
    
    // StateObject ensures the processor lives as long as the view exists
    @StateObject private var processor = SpectrumProcessor()
    
    let size: CGSize
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
                let scale: CGFloat = 0.75

                let barHeight = processor.smoothedHeights[col] * scale
                let peakHeight = processor.peakHeights[col] * scale

                // Bar Rect
                let barRect = CGRect(x: x, y: canvasSize.height - barHeight, width: barWidth, height: barHeight)
                barsPath.addRect(barRect)

                // Peak Rect
                if peakHeight > 2 {
                    let peakRect = CGRect(x: x, y: canvasSize.height - peakHeight - 1, width: barWidth, height: 2)
                    peaksPath.addRect(peakRect)
                }
            }

            context.fill(barsPath, with: barGradient)
            context.fill(peaksPath, with: .color(.gray))

            // Baseline
            var baselinePath = Path()
            baselinePath.move(to: CGPoint(x: 0, y: canvasSize.height - 2))
            baselinePath.addLine(to: CGPoint(x: canvasSize.width, y: canvasSize.height - 2))
            context.stroke(baselinePath, with: .color(Color(red: 0.2, green: 0.4, blue: 0.8)), style: StrokeStyle(lineWidth: 1, dash: [1, 3]))
        }
        //.drawingGroup() // Keeps rendering on the GPU (Metal)
        .onReceive(spectrum.$spectrumData) { newData in
            // Use onReceive for better compatibility with ObservableObject
            processor.update(with: newData, totalHeight: size.height)
        }
    }
}

struct OscilloscopeVisualization: View {
    @EnvironmentObject var audioPlayer: AudioPlayer
    let size: CGSize

    @State private var wavePhase: Double = 0.0

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.033)) { timeline in
            drawOscilloscope()
                .onChange(of: timeline.date) { _ in
                    wavePhase += 0.1
                }
        }
    }
}

extension OscilloscopeVisualization {

    @ViewBuilder
    private func drawOscilloscope() -> some View {
        Canvas { context, canvasSize in
            render(context: context, canvasSize: canvasSize)
        }
    }
}

extension OscilloscopeVisualization {

    private func render(context: GraphicsContext, canvasSize: CGSize) {

        let centerY = canvasSize.height / 2
        let barWidth: CGFloat = 2.0
        let barSpacing: CGFloat = 1.0
        let totalBarWidth = barWidth + barSpacing
        let numBars = Int(canvasSize.width / totalBarWidth)

        let spectrum = SpectrumBuffer.shared.spectrumData
        let spectrumCount = spectrum.count

        var leftChannelPath = Path()
        var rightChannelPath = Path()

        for i in 0..<numBars {

            let x = CGFloat(i) * totalBarWidth
            let spatialPhase = Double(i) * 0.25
            let spectrumIndex = (i * spectrumCount) / numBars
            let localFreq = CGFloat(spectrum[min(spectrumIndex, spectrumCount - 1)])

            let veryFast = sin(wavePhase * 2.5 + Double(i) * 0.1) * 0.35
            let fast = cos(wavePhase * 1.8 + Double(i) * 0.05) * 0.3
            let medium = sin(wavePhase * 1.2 + Double(i) * 0.08) * 0.25
            let slow = cos(wavePhase * 0.6) * 0.2
            let chaotic = sin(wavePhase * 1.5 + Double(i) * 0.15) * 0.15
            let timeModulation = veryFast + fast + medium + slow + chaotic
            let randomVariation = Double.random(in: 0.85...1.15)

            let leftWaveShape =
                sin(spatialPhase) * 0.4 +
                sin(spatialPhase * 3.1) * 0.3 +
                sin(spatialPhase * 0.6) * 0.2 +
                cos(spatialPhase * 1.7) * 0.15

            let leftDynamic =
                abs(leftWaveShape *
                    (0.3 + Double(localFreq) * 2.5) *
                    (0.5 + timeModulation) *
                    randomVariation)

            let leftAmp =
                min(CGFloat(leftDynamic) * canvasSize.height * 0.5,
                    canvasSize.height / 2 - 1)

            leftChannelPath.move(to: CGPoint(x: x, y: centerY))
            leftChannelPath.addLine(to: CGPoint(x: x, y: centerY + leftAmp))

            let rightWaveShape =
                sin(spatialPhase * 1.3 + 0.7) * 0.4 +
                cos(spatialPhase * 2.4 + 1.2) * 0.3 +
                sin(spatialPhase * 0.8 + 0.4) * 0.2 +
                cos(spatialPhase * 1.9 + 1.5) * 0.15

            let rightDynamic =
                abs(rightWaveShape *
                    (0.3 + Double(localFreq) * 2.5) *
                    (0.5 + sin(wavePhase * 1.4 + Double(i) * 0.12)
                         + cos(wavePhase * 1.9) * 0.4) *
                    randomVariation)

            let rightAmp =
                min(CGFloat(rightDynamic) * canvasSize.height * 0.5,
                    canvasSize.height / 2 - 1)

            rightChannelPath.move(to: CGPoint(x: x, y: centerY - rightAmp))
            rightChannelPath.addLine(to: CGPoint(x: x, y: centerY))
        }

        context.stroke(leftChannelPath, with: .color(.red), lineWidth: barWidth)
        context.stroke(rightChannelPath,
                       with: .color(Color(red: 0.0, green: 0.5, blue: 1.0)),
                       lineWidth: barWidth)

        var centerLine = Path()
        centerLine.move(to: CGPoint(x: 0, y: centerY))
        centerLine.addLine(to: CGPoint(x: canvasSize.width, y: centerY))
        context.stroke(centerLine,
                       with: .color(Color.blue.opacity(0.3)),
                       lineWidth: 1)

        let dots = Path { p in
            for i in stride(from: 0, to: canvasSize.width, by: 3) {
                p.addEllipse(in: CGRect(x: i, y: canvasSize.height - 2,
                                        width: 1, height: 1))
            }
        }

        context.fill(dots,
                     with: .color(Color(red: 0.2, green: 0.4, blue: 0.8)))
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

