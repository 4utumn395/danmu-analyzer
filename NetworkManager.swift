import Foundation
import Network

// MARK: - 通知常量
extension Notification.Name {
    static let scheduleConfigurationChanged = Notification.Name("scheduleConfigurationChanged")
}

// MARK: - 网络管理器

@MainActor
class NetworkManager: ObservableObject {
    @Published var networkStatus: NetworkStatus = .disconnected
    @Published var lastError: String?
    @Published var connectionRetryCount: Int = 0

    private let configurationManager: SMBConfigurationManager
    private let activityManager: ActivityManager?
    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "NetworkMonitor")

    // SMB 挂载信息
    private var mountedPath: String?
    private var mountTask: Process?

    init(configurationManager: SMBConfigurationManager? = nil, activityManager: ActivityManager? = nil) {
        self.configurationManager = configurationManager ?? SMBConfigurationManager()
        self.activityManager = activityManager
        setupNetworkMonitoring()
    }
    
    var configuration: SMBConfiguration {
        return configurationManager.getCurrentConfiguration()
    }

    deinit {
        monitor.cancel()
        Task { @MainActor [weak self] in
            self?.unmountSMB()
        }
    }

    // MARK: - 网络监控

    private func setupNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                if path.status == .satisfied {
                    self?.handleNetworkAvailable()
                } else {
                    self?.handleNetworkUnavailable()
                }
            }
        }
        monitor.start(queue: monitorQueue)
    }

    private func handleNetworkAvailable() {
        print("🟢 网络连接可用")
        if networkStatus == .disconnected {
            Task {
                await connectToSMB()
            }
        }
    }

    private func handleNetworkUnavailable() {
        print("🔴 网络连接不可用")
        networkStatus = .disconnected
        unmountSMB()
    }

    // MARK: - SMB 连接管理
    
    /// 检查是否已存在相关的 SMB 挂载
    private func checkExistingMount() -> String? {
        let possiblePaths = [
            "/Volumes/\(configuration.shareName)",  // /Volumes/录播
            "/Volumes/\(configuration.shareName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? configuration.shareName)"
        ]
        
        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                // 验证这确实是一个 SMB 挂载
                if isValidSMBMount(at: path) {
                    print("🔍 发现现有挂载: \(path)")
                    return path
                }
            }
        }
        
        return nil
    }
    
    /// 验证路径是否是有效的 SMB 挂载
    private func isValidSMBMount(at path: String) -> Bool {
        // 检查是否可以访问目录
        guard FileManager.default.fileExists(atPath: path) else { return false }
        
        // 尝试列出内容来验证可访问性
        do {
            let _ = try FileManager.default.contentsOfDirectory(atPath: path)
            return true
        } catch {
            print("⚠️ 无法访问挂载点 \(path): \(error)")
            return false
        }
    }

    func connectToSMB() async {
        guard networkStatus != .connecting else { return }

        networkStatus = .connecting
        lastError = nil
        
        activityManager?.logActivity(
            type: .networkConnection,
            title: "开始连接SMB服务器",
            description: "尝试连接到 \(configuration.host)",
            status: .inProgress,
            details: ["服务器": configuration.host, "端口": "\(configuration.port)"]
        )

        do {
            // 首先检查是否已经有现有的挂载
            if let existingMount = checkExistingMount() {
                mountedPath = existingMount
                networkStatus = .connected
                connectionRetryCount = 0
                print("✅ 发现已有 SMB 挂载: \(existingMount)")
                
                activityManager?.logActivity(
                    type: .networkConnection,
                    title: "SMB连接成功",
                    description: "发现现有挂载点",
                    status: .success,
                    details: ["挂载点": existingMount]
                )
                return
            }
            
            // 如果没有现有挂载，尝试创建新的挂载
            let mountPath = try await mountSMBShare()
            mountedPath = mountPath
            networkStatus = .connected
            connectionRetryCount = 0
            print("✅ SMB 连接成功: \(mountPath)")
            
            activityManager?.logActivity(
                type: .networkConnection,
                title: "SMB连接成功",
                description: "成功挂载SMB共享",
                status: .success,
                details: ["挂载点": mountPath, "服务器": configuration.host]
            )
        } catch {
            networkStatus = .error(error.localizedDescription)
            lastError = error.localizedDescription
            connectionRetryCount += 1
            print("❌ SMB 连接失败: \(error)")
            
            activityManager?.logActivity(
                type: .networkConnection,
                title: "SMB连接失败",
                description: error.localizedDescription,
                status: .error,
                details: ["重试次数": "\(connectionRetryCount)", "错误": error.localizedDescription]
            )

            // 自动重试（最多3次）
            if connectionRetryCount < 3 {
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5秒后重试
                await connectToSMB()
            }
        }
    }

    private func mountSMBShare() async throws -> String {
        // 创建临时挂载点
        let mountPoint = "/tmp/danmu_smb_\(UUID().uuidString.prefix(8))"
        try FileManager.default.createDirectory(atPath: mountPoint, withIntermediateDirectories: true)

        return try await withCheckedThrowingContinuation { continuation in
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/sbin/mount_smbfs")

            // 构建 SMB URL，使用正确的格式
            var smbURL: String
            if let username = configuration.username {
                if let password = configuration.password {
                    smbURL = "//\(username):\(password)@\(configuration.host)/\(configuration.shareName)"
                } else {
                    smbURL = "//\(username)@\(configuration.host)/\(configuration.shareName)"
                }
            } else {
                // 无认证，尝试 guest 访问
                smbURL = "//guest@\(configuration.host)/\(configuration.shareName)"
            }

            // URL 编码中文字符
            let encodedShareName = configuration.shareName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? configuration.shareName
            smbURL = smbURL.replacingOccurrences(of: configuration.shareName, with: encodedShareName)

            print("🔗 尝试连接 SMB: \(smbURL)")
            task.arguments = [smbURL, mountPoint]

            let errorPipe = Pipe()
            let outputPipe = Pipe()
            task.standardError = errorPipe
            task.standardOutput = outputPipe

            task.terminationHandler = { process in
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                
                let errorMessage = String(data: errorData, encoding: .utf8) ?? ""
                let outputMessage = String(data: outputData, encoding: .utf8) ?? ""
                
                print("📋 mount_smbfs 退出码: \(process.terminationStatus)")
                if !errorMessage.isEmpty {
                    print("❌ 错误输出: \(errorMessage)")
                }
                if !outputMessage.isEmpty {
                    print("📝 标准输出: \(outputMessage)")
                }

                if process.terminationStatus == 0 {
                    continuation.resume(returning: mountPoint)
                } else {
                    let fullError = !errorMessage.isEmpty ? errorMessage : "退出码: \(process.terminationStatus)"
                    let error = NetworkError.mountFailed(fullError)
                    continuation.resume(throwing: error)
                }
            }

            do {
                try task.run()
                self.mountTask = task
            } catch {
                print("❌ 启动 mount_smbfs 失败: \(error)")
                continuation.resume(throwing: error)
            }
        }
    }

    func unmountSMB() {
        guard let mountPath = mountedPath else { return }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/sbin/umount")
        task.arguments = [mountPath]

        do {
            try task.run()
            task.waitUntilExit()

            // 清理挂载点
            try? FileManager.default.removeItem(atPath: mountPath)

            mountedPath = nil
            mountTask = nil
            print("🔓 SMB 已卸载")
        } catch {
            print("⚠️ SMB 卸载失败: \(error)")
        }
    }

    // MARK: - 文件访问

    func listRecordingFiles() async throws -> [RecordingFile] {
        guard networkStatus.isConnected, let mountPath = mountedPath else {
            throw NetworkError.notConnected
        }

        activityManager?.logActivity(
            type: .fileScanning,
            title: "开始扫描录播文件",
            description: "扫描SMB共享中的录播文件",
            status: .inProgress,
            details: ["路径": mountPath]
        )

        let recordings = try await scanRecordingDirectories(at: mountPath)
        
        activityManager?.logActivity(
            type: .fileScanning,
            title: "文件扫描完成",
            description: "发现录播文件",
            status: .success,
            details: ["文件数量": "\(recordings.count)", "路径": mountPath]
        )
        
        return recordings
    }

    private func scanRecordingDirectories(at basePath: String) async throws -> [RecordingFile] {
        let fileManager = FileManager.default
        var recordings: [RecordingFile] = []

        // 扫描目录结构: 录播/频道/录制文件夹/
        let channelDirs = try fileManager.contentsOfDirectory(atPath: basePath)
            .filter { !$0.hasPrefix(".") }
            .map { (basePath as NSString).appendingPathComponent($0) }
            .filter { isDirectory($0) }

        for channelDir in channelDirs {
            let channelName = URL(fileURLWithPath: channelDir).lastPathComponent

            // 扫描录制文件夹
            let recordingDirs = try fileManager.contentsOfDirectory(atPath: channelDir)
                .filter { !$0.hasPrefix(".") && $0.hasPrefix("录制-") }
                .map { (channelDir as NSString).appendingPathComponent($0) }
                .filter { isDirectory($0) }

            for recordingDir in recordingDirs {
                // 查找 XML 文件
                let xmlFiles = try fileManager.contentsOfDirectory(atPath: recordingDir)
                    .filter { $0.hasSuffix(".xml") }

                for xmlFile in xmlFiles {
                    let xmlPath = (recordingDir as NSString).appendingPathComponent(xmlFile)

                    if XMLDanmakuParser.validateXMLFile(at: xmlPath) {
                        let recording = createRecordingFile(
                            from: xmlPath,
                            channelName: channelName,
                            recordingDir: recordingDir
                        )
                        recordings.append(recording)
                    }
                }
            }
        }

        return recordings.sorted { $0.date > $1.date }
    }

    private func createRecordingFile(from xmlPath: String, channelName: String, recordingDir: String) -> RecordingFile {
        let url = URL(fileURLWithPath: xmlPath)
        let filename = url.deletingPathExtension().lastPathComponent

        // 解析日期和标题
        var date = Date()
        var title = "未知录制"

        if filename.hasPrefix("录制-") {
            let components = filename.split(separator: "-")
            if components.count >= 2 {
                // 解析日期
                let dateString = String(components[1])
                if dateString.count >= 8 {
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyyMMdd"
                    date = dateFormatter.date(from: String(dateString.prefix(8))) ?? Date()
                }

                // 解析标题
                if components.count > 2 {
                    title = components.dropFirst(2).joined(separator: "-")
                }
            }
        }

        return RecordingFile(
            id: filename,
            name: url.lastPathComponent,
            path: recordingDir,
            xmlPath: xmlPath,
            date: date,
            channel: channelName,
            title: title
        )
    }

    private func isDirectory(_ path: String) -> Bool {
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: path, isDirectory: &isDir)
        return isDir.boolValue
    }

    enum NetworkError: Error, LocalizedError {
        case notConnected
        case mountFailed(String)
        case invalidConfiguration
        case timeout
        case accessDenied

        var errorDescription: String? {
            switch self {
            case .notConnected:
                return "未连接到网络"
            case let .mountFailed(message):
                return "SMB 挂载失败: \(message)"
            case .invalidConfiguration:
                return "网络配置无效"
            case .timeout:
                return "连接超时"
            case .accessDenied:
                return "访问被拒绝"
            }
        }
    }
}

// MARK: - 定时任务管理器

@MainActor
class ScheduleManager: ObservableObject {
    @Published var isEnabled: Bool = false
    @Published var taskStatus: ScanTaskStatus = .idle
    @Published var lastScanTime: Date?
    @Published var nextScanTime: Date?
    @Published var processedToday: Int = 0
    @Published var errorCount: Int = 0

    private let configurationManager: ScheduleConfigurationManager
    private let networkManager: NetworkManager
    private let activityManager: ActivityManager?
    private var scanTimer: Timer?
    private var dailyResetTimer: Timer?

    init(configurationManager: ScheduleConfigurationManager = ScheduleConfigurationManager(), networkManager: NetworkManager, activityManager: ActivityManager? = nil) {
        self.configurationManager = configurationManager
        self.networkManager = networkManager
        self.activityManager = activityManager

        if configurationManager.configuration.enabled {
            startSchedule()
        }

        setupDailyReset()
        
        // 监听配置变化
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(configurationDidChange),
            name: .scheduleConfigurationChanged,
            object: nil
        )
    }
    
    /// 当前配置
    var configuration: ScheduleConfiguration {
        return configurationManager.configuration
    }

    deinit {
        Task { @MainActor [weak self] in
            self?.stopSchedule()
        }
    }

    // MARK: - 定时任务控制

    func startSchedule() {
        guard !isEnabled else { return }

        isEnabled = true
        calculateNextScanTime()

        // 创建定时器
        scanTimer = Timer.scheduledTimer(withTimeInterval: configuration.interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.performScheduledScan()
            }
        }

        print("⏰ 定时任务已启动，间隔: \(configuration.interval)秒")
    }

    func stopSchedule() {
        isEnabled = false
        scanTimer?.invalidate()
        scanTimer = nil
        nextScanTime = nil

        print("⏸️ 定时任务已停止")
    }

    private func calculateNextScanTime() {
        let now = Date()
        // 使用用户配置的间隔时间计算下次扫描时间
        nextScanTime = now.addingTimeInterval(configuration.interval)
    }

    private func setupDailyReset() {
        // 每天午夜重置计数器
        let calendar = Calendar.current
        let midnight = calendar.startOfDay(for: Date().addingTimeInterval(86400)) // 明天午夜

        dailyResetTimer = Timer(
            fireAt: midnight,
            interval: 86400,
            target: self,
            selector: #selector(resetDailyCounters),
            userInfo: nil,
            repeats: true
        )
        RunLoop.main.add(dailyResetTimer!, forMode: .common)
    }

    @objc private func resetDailyCounters() {
        processedToday = 0
        errorCount = 0
        print("🔄 每日计数器已重置")
    }

    // MARK: - 扫描执行

    func performScheduledScan() async {
        guard isEnabled, taskStatus == .idle else { return }

        print("🔍 开始定时扫描...")
        taskStatus = .scanning
        lastScanTime = Date()
        
        activityManager?.logActivity(
            type: .system,
            title: "开始定时任务",
            description: "执行定时扫描和分析任务",
            status: .inProgress
        )

        do {
            // 确保网络连接
            if !networkManager.networkStatus.isConnected {
                await networkManager.connectToSMB()
            }

            guard networkManager.networkStatus.isConnected else {
                throw NetworkManager.NetworkError.notConnected
            }

            // 获取录播文件列表
            let recordingFiles = try await networkManager.listRecordingFiles()
            print("📁 发现 \(recordingFiles.count) 个录播文件")

            if !recordingFiles.isEmpty {
                taskStatus = .processing
                await processRecordingFiles(recordingFiles)
            }

            taskStatus = .completed
            calculateNextScanTime()
            
            activityManager?.logActivity(
                type: .system,
                title: "定时任务完成",
                description: "定时扫描和分析任务执行完成",
                status: .success,
                details: ["处理文件": "\(recordingFiles.count)", "今日处理": "\(processedToday)"]
            )

        } catch {
            taskStatus = .failed(error)
            errorCount += 1
            print("❌ 定时扫描失败: \(error)")
            
            activityManager?.logActivity(
                type: .system,
                title: "定时任务失败",
                description: error.localizedDescription,
                status: .error,
                details: ["错误次数": "\(errorCount)"]
            )

            // 短暂延迟后重新计算下次扫描时间
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            calculateNextScanTime()
        }
    }

    private func processRecordingFiles(_ files: [RecordingFile]) async {
        for file in files {
            let startTime = Date()
            do {
                let parser = XMLDanmakuParser()
                let result = try await parser.parseXMLFile(at: file.xmlPath)

                // 生成弹幕峰值分析
                let analyzer = DanmakuAnalysisEngine()
                let peaks = await analyzer.analyzePeaks(from: result.messages)

                // 保存分析结果
                await saveAnalysisResult(file: file, result: result, peaks: peaks)

                processedToday += 1
                print("✅ 处理完成: \(file.displayName)")
                
                let duration = Date().timeIntervalSince(startTime)
                activityManager?.logActivity(
                    type: .analysis,
                    title: "分析完成: \(file.title)",
                    description: "弹幕峰值分析完成",
                    status: .success,
                    details: [
                        "频道": file.channel,
                        "峰值数量": "\(peaks.count)",
                        "弹幕数量": "\(result.messages.count)",
                        "处理时间": String(format: "%.1f秒", duration)
                    ]
                )

            } catch {
                errorCount += 1
                print("❌ 处理失败: \(file.displayName) - \(error)")
                
                activityManager?.logActivity(
                    type: .analysis,
                    title: "分析失败: \(file.title)",
                    description: error.localizedDescription,
                    status: .error,
                    details: ["频道": file.channel, "错误": error.localizedDescription]
                )
            }
        }
    }

    private func saveAnalysisResult(
        file: RecordingFile,
        result: XMLDanmakuResult,
        peaks: [AnalysisTaskResult.DanmakuPeak]
    ) async {
        // 保存分析结果到本地数据库或文件
        // 这里可以实现数据持久化逻辑

        let analysisResult = AnalysisTaskResult(
            id: UUID(),
            recordingFile: file,
            xmlResult: result,
            peaks: peaks,
            analysisTime: Date(),
            processingDuration: 0
        )

        // TODO: 实现数据存储
        print("💾 保存分析结果: \(analysisResult.id)")
    }

    // MARK: - 手动触发

    func triggerManualScan() async {
        guard taskStatus == .idle else { return }

        print("👆 触发手动扫描...")
        await performScheduledScan()
    }
    
    // MARK: - 配置管理
    
    /// 更新扫描间隔
    func updateScanInterval(_ interval: TimeInterval) {
        configurationManager.updateInterval(interval)
        
        // 如果定时器正在运行，重新启动以应用新间隔
        if isEnabled {
            stopSchedule()
            startSchedule()
        } else {
            // 即使定时器没有运行，也要更新下次扫描时间显示
            calculateNextScanTime()
        }
    }
    
    /// 更新启用状态
    func updateEnabled(_ enabled: Bool) {
        configurationManager.updateEnabled(enabled)
        
        if enabled && !isEnabled {
            startSchedule()
        } else if !enabled && isEnabled {
            stopSchedule()
        }
    }
    
    /// 获取配置管理器（供UI使用）
    var scheduleConfigurationManager: ScheduleConfigurationManager {
        return configurationManager
    }
    
    /// 处理配置变化
    @objc private func configurationDidChange() {
        // 重新计算下次扫描时间以反映新配置
        if isEnabled || nextScanTime != nil {
            calculateNextScanTime()
        }
    }
}

// MARK: - 弹幕分析引擎

actor DanmakuAnalysisEngine {
    func analyzePeaks(
        from messages: [DanmakuMessage],
        recordingStartTime: Date? = nil,
        windowSize: Double = 30.0,
        stepSize: Double = 5.0
    ) async -> [AnalysisTaskResult.DanmakuPeak] {
        guard !messages.isEmpty else { return [] }

        let sortedMessages = messages.sorted { $0.timestamp < $1.timestamp }
        let maxTime = sortedMessages.last?.timestamp ?? 0

        var peaks: [AnalysisTaskResult.DanmakuPeak] = []
        var densities: [(time: Double, count: Int, messages: [DanmakuMessage])] = []

        // 计算密度分布
        var currentTime: Double = 0
        while currentTime <= maxTime {
            let windowEnd = currentTime + windowSize
            let windowMessages = sortedMessages.filter {
                $0.timestamp >= currentTime && $0.timestamp < windowEnd
            }

            densities.append((time: currentTime, count: windowMessages.count, messages: windowMessages))
            currentTime += stepSize
        }

        // 计算动态阈值
        let avgDensity = densities.isEmpty ? 0 : Double(densities.reduce(0) { $0 + $1.count }) / Double(densities.count)
        let threshold = max(3, Int(avgDensity * 1.5))

        // 查找峰值 - 需要至少3个数据点才能查找峰值
        guard densities.count >= 3 else {
            print("⚠️ 数据点不足，无法分析峰值（需要至少3个数据点，当前: \(densities.count)）")
            return []
        }
        
        for i in 1 ..< densities.count - 1 {
            let current = densities[i]
            let prev = densities[i - 1]
            let next = densities[i + 1]

            if
                current.count > prev.count,
                current.count > next.count,
                current.count >= threshold
            {
                // 计算峰值统计信息
                let averageLength = current.messages.isEmpty ? 0 :
                    Double(current.messages.reduce(0) { $0 + $1.content.count }) / Double(current.messages.count)

                let positionCounts = Dictionary(grouping: current.messages, by: { $0.position })
                let dominantPosition = positionCounts.max { $0.value.count < $1.value.count }?.key ?? .scroll

                // 计算绝对时间 - 直接使用弹幕中的真实绝对时间
                let startAbsoluteTime: Date
                let endAbsoluteTime: Date
                
                if !current.messages.isEmpty {
                    // 使用时间窗口内弹幕的实际绝对时间
                    startAbsoluteTime = current.messages.first?.absoluteTime ?? Date()
                    endAbsoluteTime = current.messages.last?.absoluteTime ?? Date()
                } else if let recordingStart = recordingStartTime {
                    // 如果没有弹幕，回退到使用录制开始时间计算
                    startAbsoluteTime = recordingStart.addingTimeInterval(current.time)
                    endAbsoluteTime = recordingStart.addingTimeInterval(current.time + windowSize)
                } else {
                    // 最后的回退选项
                    startAbsoluteTime = Date()
                    endAbsoluteTime = Date()
                }

                let peak = AnalysisTaskResult.DanmakuPeak(
                    startTime: current.time,
                    endTime: current.time + windowSize,
                    startAbsoluteTime: startAbsoluteTime,
                    endAbsoluteTime: endAbsoluteTime,
                    count: current.count,
                    averageLength: averageLength,
                    dominantPosition: dominantPosition
                )

                peaks.append(peak)
            }
        }

        return peaks.sorted { $0.count > $1.count }.prefix(10).map { $0 }
    }
}
