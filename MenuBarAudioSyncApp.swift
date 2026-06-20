import SwiftUI
import AppKit
import AVFoundation
import CoreAudio
import AudioToolbox

@main
struct MenuBarAudioSyncApp: App {
    @StateObject private var router = AudioRouter()

    var body: some Scene {
        MenuBarExtra("Audio Sync", systemImage: "speaker.wave.3.fill") {
            ContentView()
                .environmentObject(router)
                .frame(width: 380)
        }
        .menuBarExtraStyle(.window)
    }
}

struct ContentView: View {
    @EnvironmentObject private var router: AudioRouter

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Multi-output audio sync")
                    .font(.headline)
                Spacer()
                Button("Refresh") { router.refreshDevices() }
            }

            Picker("Input", selection: $router.selectedInputID) {
                ForEach(router.inputDevices) { device in
                    Text(device.name).tag(Optional(device.id))
                }
            }
            .onChange(of: router.selectedInputID) { _, _ in router.restartIfRunning() }

            Divider()

            if router.outputDevices.isEmpty {
                Text("No output devices found.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(router.outputDevices) { device in
                    DeviceRow(device: device)
                }
            }

            Divider()

            HStack {
                Button(router.isRunning ? "Stop" : "Start") {
                    router.isRunning ? router.stop() : router.start()
                }
                .keyboardShortcut(.defaultAction)

                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
            }

            if let errorMessage = router.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("Tip: choose BlackHole, Loopback, or another virtual system-audio device as the input. macOS does not allow ordinary apps to capture system output directly without such a device.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .onAppear { router.refreshDevices() }
    }
}

struct DeviceRow: View {
    @EnvironmentObject private var router: AudioRouter
    let device: AudioDeviceInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: Binding(
                get: { router.selectedOutputs.contains(device.id) },
                set: { isOn in router.setOutput(device.id, enabled: isOn) }
            )) {
                Text(device.name).lineLimit(1)
            }

            if router.selectedOutputs.contains(device.id) {
                HStack {
                    Slider(value: Binding(
                        get: { Double(router.delaysMS[device.id, default: 0]) },
                        set: { router.setDelay(device.id, milliseconds: Int($0.rounded())) }
                    ), in: 0...1000, step: 1)
                    TextField("ms", value: Binding(
                        get: { router.delaysMS[device.id, default: 0] },
                        set: { router.setDelay(device.id, milliseconds: $0) }
                    ), format: .number)
                    .frame(width: 54)
                    Text("ms")
                }
                .padding(.leading, 24)
            }
        }
    }
}

struct AudioDeviceInfo: Identifiable, Hashable {
    let id: AudioDeviceID
    let name: String
}

final class AudioRouter: ObservableObject {
    @Published var inputDevices: [AudioDeviceInfo] = []
    @Published var outputDevices: [AudioDeviceInfo] = []
    @Published var selectedInputID: AudioDeviceID?
    @Published var selectedOutputs = Set<AudioDeviceID>()
    @Published var delaysMS: [AudioDeviceID: Int] = [:]
    @Published var isRunning = false
    @Published var errorMessage: String?

    private var captureEngine: AVAudioEngine?
    private var outputPipelines: [AudioDeviceID: OutputPipeline] = [:]
    private let renderQueue = DispatchQueue(label: "AudioRouter.renderQueue", qos: .userInitiated)

    func refreshDevices() {
        inputDevices = Self.devices(withScope: kAudioDevicePropertyScopeInput)
        outputDevices = Self.devices(withScope: kAudioDevicePropertyScopeOutput)
        if selectedInputID == nil { selectedInputID = inputDevices.first?.id }
        selectedOutputs = selectedOutputs.intersection(outputDevices.map(\.id))
    }

    func setOutput(_ id: AudioDeviceID, enabled: Bool) {
        if enabled { selectedOutputs.insert(id) } else { selectedOutputs.remove(id) }
        restartIfRunning()
    }

    func setDelay(_ id: AudioDeviceID, milliseconds: Int) {
        delaysMS[id] = min(1000, max(0, milliseconds))
        outputPipelines[id]?.delayMS = delaysMS[id, default: 0]
    }

    func restartIfRunning() {
        guard isRunning else { return }
        stop()
        start()
    }

    func start() {
        stop()
        errorMessage = nil

        guard let inputID = selectedInputID else {
            errorMessage = "Select an input device first."
            return
        }
        guard !selectedOutputs.isEmpty else {
            errorMessage = "Check at least one output device."
            return
        }

        do {
            let session = AVCaptureDevice.default(for: .audio)
            _ = session // Keeps AVFoundation linked; device routing below uses Core Audio IDs.

            let inputEngine = AVAudioEngine()
            try inputEngine.inputNode.auAudioUnit.setDeviceID(inputID)
            let input = inputEngine.inputNode
            let format = input.outputFormat(forBus: 0)

            var pipelines: [AudioDeviceID: OutputPipeline] = [:]
            for outputID in selectedOutputs {
                let pipeline = try OutputPipeline(deviceID: outputID,
                                                  sourceFormat: format,
                                                  delayMS: delaysMS[outputID, default: 0])
                pipelines[outputID] = pipeline
            }
            outputPipelines = pipelines

            let framesPerBuffer: AVAudioFrameCount = 1024
            input.installTap(onBus: 0, bufferSize: framesPerBuffer, format: format) { [weak self] buffer, _ in
                self?.renderQueue.async {
                    self?.outputPipelines.values.forEach { $0.enqueue(buffer: buffer) }
                }
            }

            try inputEngine.start()
            captureEngine = inputEngine
            isRunning = true
        } catch {
            stop()
            errorMessage = "Audio start failed: \(error.localizedDescription)"
        }
    }

    func stop() {
        captureEngine?.inputNode.removeTap(onBus: 0)
        captureEngine?.stop()
        captureEngine = nil
        outputPipelines.values.forEach { $0.stop() }
        outputPipelines.removeAll()
        isRunning = false
    }

    private static func devices(withScope scope: AudioObjectPropertyScope) -> [AudioDeviceInfo] {
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDevices,
                                                 mScope: kAudioObjectPropertyScopeGlobal,
                                                 mElement: kAudioObjectPropertyElementMain)
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize) == noErr else { return [] }

        let count = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var ids = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize, &ids) == noErr else { return [] }

        return ids.compactMap { id in
            guard hasStreams(deviceID: id, scope: scope) else { return nil }
            return AudioDeviceInfo(id: id, name: name(for: id))
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private static func hasStreams(deviceID: AudioDeviceID, scope: AudioObjectPropertyScope) -> Bool {
        var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyStreams,
                                                 mScope: scope,
                                                 mElement: kAudioObjectPropertyElementMain)
        var dataSize: UInt32 = 0
        return AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &dataSize) == noErr && dataSize > 0
    }

    private static func name(for id: AudioDeviceID) -> String {
        var address = AudioObjectPropertyAddress(mSelector: kAudioObjectPropertyName,
                                                 mScope: kAudioObjectPropertyScopeGlobal,
                                                 mElement: kAudioObjectPropertyElementMain)
        var name: CFString = "Unknown" as CFString
        var dataSize = UInt32(MemoryLayout<CFString>.size)
        _ = AudioObjectGetPropertyData(id, &address, 0, nil, &dataSize, &name)
        return name as String
    }
}

final class OutputPipeline {
    let engine = AVAudioEngine()
    let player = AVAudioPlayerNode()
    var delayMS: Int

    private let sourceFormat: AVAudioFormat
    private let outputFormat: AVAudioFormat

    init(deviceID: AudioDeviceID, sourceFormat: AVAudioFormat, delayMS: Int) throws {
        self.sourceFormat = sourceFormat
        self.delayMS = delayMS

        engine.attach(player)
        try engine.outputNode.auAudioUnit.setDeviceID(deviceID)
        outputFormat = engine.outputNode.inputFormat(forBus: 0)
        engine.connect(player, to: engine.outputNode, format: outputFormat)
        try engine.start()
        player.play()
    }

    func enqueue(buffer: AVAudioPCMBuffer) {
        guard let converted = convert(buffer) else { return }
        let delaySeconds = Double(delayMS) / 1000.0
        let hostTime = mach_absolute_time() + AVAudioTime.hostTime(forSeconds: delaySeconds)
        player.scheduleBuffer(converted, at: AVAudioTime(hostTime: hostTime), options: [], completionHandler: nil)
    }

    func stop() {
        player.stop()
        engine.stop()
    }

    private func convert(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        if sourceFormat == outputFormat { return buffer }
        guard let converter = AVAudioConverter(from: sourceFormat, to: outputFormat),
              let converted = AVAudioPCMBuffer(pcmFormat: outputFormat,
                                               frameCapacity: AVAudioFrameCount(Double(buffer.frameLength) * outputFormat.sampleRate / sourceFormat.sampleRate) + 1) else { return nil }
        var didProvideInput = false
        let status = converter.convert(to: converted, error: nil) { _, outStatus in
            if didProvideInput {
                outStatus.pointee = .noDataNow
                return nil
            }
            didProvideInput = true
            outStatus.pointee = .haveData
            return buffer
        }
        return status == .haveData ? converted : nil
    }
}

private extension AUAudioUnit {
    func setDeviceID(_ deviceID: AudioDeviceID) throws {
        var mutableID = deviceID
        let status = AudioUnitSetProperty(audioUnit,
                                          kAudioOutputUnitProperty_CurrentDevice,
                                          kAudioUnitScope_Global,
                                          0,
                                          &mutableID,
                                          UInt32(MemoryLayout<AudioDeviceID>.size))
        guard status == noErr else {
            throw NSError(domain: NSOSStatusErrorDomain,
                          code: Int(status),
                          userInfo: [NSLocalizedDescriptionKey: "Could not select Core Audio device \(deviceID) (OSStatus \(status))."])
        }
    }
}
