import AppKit
import Foundation

@MainActor
final class DeviceLocationService: ObservableObject {
    enum ConnectionState: Equatable {
        case checking
        case ready(deviceName: String)
        case missingTool
        case noDevice
        case error(String)
    }

    @Published private(set) var connectionState: ConnectionState = .checking
    @Published private(set) var isWorking = false
    @Published private(set) var isSimulating = false
    @Published private(set) var lastMessage = "Watching for a USB iPhone…"
    @Published private(set) var setupProgress: Double?
    @Published private(set) var setupStatus = ""
    @Published private(set) var deviceDetails = ""
    @Published private(set) var diagnosticDetails = "No diagnostics yet."

    private let toolName = "pymobiledevice3"
    private var lastDetectedDevice: String?

    func monitorConnection() async {
        while !Task.isCancelled {
            if !isWorking {
                await checkConnection(showProgress: connectionState == .checking)
            }
            try? await Task.sleep(for: .seconds(3))
        }
    }

    func checkConnection(showProgress: Bool = true) async {
        if showProgress {
            isWorking = true
            connectionState = .checking
        }
        defer {
            if showProgress { isWorking = false }
        }

        guard let tool = findExecutable(toolName) else {
            connectionState = .missingTool
            lastMessage = "The iPhone bridge is not installed yet. Use Setup below."
            lastDetectedDevice = nil
            return
        }

        let result = await run(tool, arguments: ["usbmux", "list"])
        diagnosticDetails = result.output
        guard result.exitCode == 0 else {
            connectionState = .error(cleanError(result.output))
            lastMessage = "Could not query the connected iPhone."
            lastDetectedDevice = nil
            deviceDetails = ""
            return
        }

        guard result.output.contains("DeviceName") || result.output.contains("UniqueDeviceID") else {
            connectionState = .noDevice
            if lastDetectedDevice != nil {
                lastMessage = "iPhone disconnected. Watching USB for it to return…"
            } else {
                lastMessage = "Watching USB. Plug in the iPhone, unlock it, and accept Trust."
            }
            lastDetectedDevice = nil
            deviceDetails = ""
            return
        }

        let name = capture(#"[\"']?DeviceName[\"']?\s*:\s*[\"']([^\"']+)"#, in: result.output) ?? "iPhone"
        let model = capture(#"[\"']?ProductType[\"']?\s*:\s*[\"']([^\"']+)"#, in: result.output) ?? "iPhone"
        let version = capture(#"[\"']?ProductVersion[\"']?\s*:\s*[\"']([^\"']+)"#, in: result.output) ?? "iOS"
        let connection = capture(#"[\"']?ConnectionType[\"']?\s*:\s*[\"']([^\"']+)"#, in: result.output) ?? "USB"
        connectionState = .ready(deviceName: name)
        deviceDetails = "\(model) · iOS \(version) · \(connection)"
        if lastDetectedDevice != name {
            lastMessage = "\(name) connected automatically over USB."
        }
        lastDetectedDevice = name
    }

    @discardableResult
    func setLocation(latitude: Double, longitude: Double) async -> Bool {
        guard (-90...90).contains(latitude), (-180...180).contains(longitude) else {
            lastMessage = "Enter a valid latitude and longitude."
            return false
        }
        guard let tool = findExecutable(toolName) else {
            connectionState = .missingTool
            lastMessage = "Install the iPhone bridge first."
            return false
        }

        isWorking = true
        lastMessage = "Sending the simulated location… Keep the iPhone unlocked."
        defer { isWorking = false }

        let coordinateArguments = [String(format: "%.7f", latitude), String(format: "%.7f", longitude)]
        let result = await runLocationCommand(tool, action: "set", values: coordinateArguments)

        if result.exitCode == 0 {
            isSimulating = true
            lastMessage = "Location applied. Open Snapchat on the iPhone, then refresh Snap Map."
            await checkConnection(showProgress: false)
            return true
        } else {
            diagnosticDetails = result.output
            lastMessage = humanReadableFailure(result.output)
            return false
        }
    }

    func restoreRealLocation() async {
        guard let tool = findExecutable(toolName) else {
            connectionState = .missingTool
            lastMessage = "Install the iPhone bridge first."
            return
        }

        isWorking = true
        lastMessage = "Restoring the iPhone’s real location…"
        defer { isWorking = false }

        let result = await runLocationCommand(tool, action: "clear")

        if result.exitCode == 0 {
            isSimulating = false
            lastMessage = "Real GPS restored."
            await checkConnection(showProgress: false)
        } else {
            diagnosticDetails = result.output
            lastMessage = humanReadableFailure(result.output)
        }
    }

    func installOrRepairRuntime() async {
        guard !isWorking else { return }
        guard let python = findPython() else {
            setupStatus = "Python is unavailable. Install Apple’s Command Line Tools or Xcode, then retry."
            lastMessage = setupStatus
            return
        }

        isWorking = true
        setupProgress = 0.08
        setupStatus = "Creating GeoShift’s private runtime…"
        defer { isWorking = false }

        let runtime = managedRuntimeDirectory
        do {
            try FileManager.default.createDirectory(at: runtime.deletingLastPathComponent(), withIntermediateDirectories: true)
        } catch {
            setupProgress = nil
            setupStatus = "Could not create Application Support: \(error.localizedDescription)"
            return
        }

        if !FileManager.default.fileExists(atPath: runtime.appendingPathComponent("bin/python3").path) {
            let venv = await run(python, arguments: ["-m", "venv", runtime.path], timeout: 120)
            guard venv.exitCode == 0 else {
                setupProgress = nil
                diagnosticDetails = venv.output
                setupStatus = "Runtime creation failed. \(cleanError(venv.output))"
                return
            }
        }

        setupProgress = 0.35
        setupStatus = "Downloading the iPhone connection components…"
        let pip = runtime.appendingPathComponent("bin/pip").path
        let install = await run(pip, arguments: ["install", "--disable-pip-version-check", "--upgrade", "pymobiledevice3"], timeout: 600)
        diagnosticDetails = install.output
        guard install.exitCode == 0 else {
            setupProgress = nil
            setupStatus = "Setup failed. Check the internet connection and click Repair Setup."
            lastMessage = cleanError(install.output)
            return
        }

        setupProgress = 0.82
        setupStatus = "Verifying the phone bridge…"
        let tool = runtime.appendingPathComponent("bin/pymobiledevice3").path
        let verify = await run(tool, arguments: ["--version"], timeout: 30)
        guard verify.exitCode == 0 else {
            setupProgress = nil
            diagnosticDetails = verify.output
            setupStatus = "The bridge installed but verification failed. Click Repair Setup."
            return
        }

        setupProgress = 1
        setupStatus = "Setup complete—no Terminal required."
        lastMessage = "Phone bridge ready. Watching USB for your iPhone…"
        try? await Task.sleep(for: .milliseconds(500))
        setupProgress = nil
        await checkConnection()
    }

    func copyDiagnostics() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(diagnosticDetails, forType: .string)
        lastMessage = "Diagnostics copied."
    }

    private func findExecutable(_ name: String) -> String? {
        let candidates = [
            managedRuntimeDirectory.appendingPathComponent("bin/\(name)").path,
            "/opt/homebrew/bin/\(name)",
            "/usr/local/bin/\(name)",
            NSString(string: "~/.local/bin/\(name)").expandingTildeInPath,
            NSString(string: "~/Library/Python/3.13/bin/\(name)").expandingTildeInPath,
            NSString(string: "~/Library/Python/3.12/bin/\(name)").expandingTildeInPath
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    private var managedRuntimeDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("GeoShift/runtime", isDirectory: true)
    }

    private func findPython() -> String? {
        let candidates = [
            "/usr/bin/python3",
            "/opt/homebrew/bin/python3",
            "/usr/local/bin/python3",
            "/Library/Frameworks/Python.framework/Versions/3.13/bin/python3",
            "/Library/Frameworks/Python.framework/Versions/3.12/bin/python3"
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    private func capture(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[range])
    }

    private func humanReadableFailure(_ raw: String) -> String {
        let lower = raw.lowercased()
        if lower.contains("developer mode") { return "Developer Mode is off. Enable it in iPhone Settings › Privacy & Security, restart, and try again." }
        if lower.contains("locked") { return "The iPhone is locked. Unlock it, keep the screen on, and try again." }
        if lower.contains("trust") || lower.contains("pair") { return "The Mac is not trusted yet. Unlock the iPhone, reconnect USB, and tap Trust." }
        if lower.contains("no device") || lower.contains("not connected") { return "No iPhone was found over USB. Check the cable and tap Check connection." }
        if lower.contains("developer disk") || lower.contains("ddi") || lower.contains("image") { return "Developer support is not ready. Open Xcode once with the unlocked iPhone connected, then retry." }
        return cleanError(raw)
    }

    private func cleanError(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "The command failed without details. Reconnect the iPhone and try again." }
        return String(trimmed.suffix(500))
    }

    private struct CommandResult: Sendable {
        let exitCode: Int32
        let output: String
    }

    private func runLocationCommand(_ tool: String, action: String, values: [String] = []) async -> CommandResult {
        // Let pymobiledevice3 choose its preferred macOS transport first. If the
        // native path is temporarily unavailable, explicitly retry via userspace.
        let automatic = ["developer", "dvt", "simulate-location", action, "--"] + values
        let userspace = ["developer", "dvt", "simulate-location", action, "--userspace", "--"] + values
        var lastResult = CommandResult(exitCode: -1, output: "Connection did not start.")

        for attempt in 0..<3 {
            let arguments = attempt == 0 ? automatic : userspace
            lastResult = await run(tool, arguments: arguments, timeout: 90)
            if lastResult.exitCode == 0 { return lastResult }

            let lower = lastResult.output.lowercased()
            if attempt == 0 && (lower.contains("developer disk") || lower.contains("ddi") || lower.contains("image")) {
                _ = await run(tool, arguments: ["mounter", "auto-mount"], timeout: 120)
            }
            if attempt < 2 {
                lastMessage = "Connection hiccup—retrying automatically (\(attempt + 2)/3)…"
                try? await Task.sleep(for: .seconds(1))
            }
        }
        return lastResult
    }

    private func run(_ executable: String, arguments: [String], timeout: TimeInterval = 30) async -> CommandResult {
        await Task.detached(priority: .userInitiated) {
            let process = Process()
            let pipe = Pipe()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            process.standardOutput = pipe
            process.standardError = pipe
            var environment = ProcessInfo.processInfo.environment
            environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:\(NSHomeDirectory())/.local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
            process.environment = environment

            do {
                try process.run()
            } catch {
                return CommandResult(exitCode: -1, output: error.localizedDescription)
            }

            let deadline = Date().addingTimeInterval(timeout)
            while process.isRunning && Date() < deadline {
                try? await Task.sleep(for: .milliseconds(120))
            }
            if process.isRunning {
                process.terminate()
                return CommandResult(exitCode: -2, output: "Timed out while talking to the iPhone. Keep it unlocked and retry.")
            }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return CommandResult(exitCode: process.terminationStatus, output: String(decoding: data, as: UTF8.self))
        }.value
    }
}
