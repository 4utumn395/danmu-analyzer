import SwiftUI
import AppKit

@main
struct DanmakuSchedulerApp: App {
    var body: some Scene {
        WindowGroup {
            MainView()
        }
        .windowStyle(DefaultWindowStyle())
    }
}

struct MainView: View {
    @StateObject private var activityManager = ActivityManager()
    @StateObject private var networkManager: NetworkManager
    @StateObject private var scheduleManager: ScheduleManager
    @StateObject private var scheduleConfigurationManager = ScheduleConfigurationManager()
    @StateObject private var analysisManager = AnalysisResultManager()
    @State private var selectedTab: MainTab = .dashboard

    init() {
        let activityManager = ActivityManager()
        let scheduleConfigurationManager = ScheduleConfigurationManager()
        let networkManager = NetworkManager(activityManager: activityManager)
        let scheduleManager = ScheduleManager(configurationManager: scheduleConfigurationManager, networkManager: networkManager, activityManager: activityManager)
        _activityManager = StateObject(wrappedValue: activityManager)
        _networkManager = StateObject(wrappedValue: networkManager)
        _scheduleManager = StateObject(wrappedValue: scheduleManager)
        _scheduleConfigurationManager = StateObject(wrappedValue: scheduleConfigurationManager)
    }

    var body: some View {
        NavigationSplitView {
            SidebarView(selectedTab: $selectedTab)
        } detail: {
            DetailView(
                selectedTab: selectedTab,
                networkManager: networkManager,
                scheduleManager: scheduleManager,
                scheduleConfigurationManager: scheduleConfigurationManager,
                analysisManager: analysisManager,
                activityManager: activityManager
            )
        }
        .frame(minWidth: 1000, minHeight: 700)
        .onAppear {
            // 启动时自动连接网络
            Task {
                await networkManager.connectToSMB()
            }
            
            // 添加初始活动记录以演示功能
            activityManager.logActivity(
                type: .system,
                title: "应用启动",
                description: "弹幕分析器启动完成",
                status: .success,
                details: ["版本": "2.0.0", "平台": "macOS"]
            )
        }
    }
}

enum MainTab: String, CaseIterable {
    case dashboard
    case recordings
    case schedule
    case analysis
    case settings

    var title: String {
        switch self {
        case .dashboard: return "仪表盘"
        case .recordings: return "录播管理"
        case .schedule: return "定时任务"
        case .analysis: return "分析结果"
        case .settings: return "设置"
        }
    }

    var icon: String {
        switch self {
        case .dashboard: return "chart.pie.fill"
        case .recordings: return "video.fill"
        case .schedule: return "calendar.clock.fill"
        case .analysis: return "chart.bar.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

struct SidebarView: View {
    @Binding var selectedTab: MainTab

    var body: some View {
        List(selection: $selectedTab) {
            Section("主要功能") {
                ForEach([MainTab.dashboard, .recordings, .schedule, .analysis], id: \.self) { tab in
                    NavigationLink(value: tab) {
                        Label(tab.title, systemImage: tab.icon)
                    }
                }
            }

            Section("其他") {
                ForEach([MainTab.settings], id: \.self) { tab in
                    NavigationLink(value: tab) {
                        Label(tab.title, systemImage: tab.icon)
                    }
                }
            }
        }
        .listStyle(SidebarListStyle())
        .frame(minWidth: 200)
    }
}

struct DetailView: View {
    let selectedTab: MainTab
    let networkManager: NetworkManager
    let scheduleManager: ScheduleManager
    let scheduleConfigurationManager: ScheduleConfigurationManager
    let analysisManager: AnalysisResultManager
    let activityManager: ActivityManager

    var body: some View {
        Group {
            switch selectedTab {
            case .dashboard:
                DashboardView(networkManager: networkManager, scheduleManager: scheduleManager, activityManager: activityManager)
            case .recordings:
                RecordingsView(networkManager: networkManager, analysisManager: analysisManager)
            case .schedule:
                ScheduleView(scheduleManager: scheduleManager)
            case .analysis:
                AnalysisView(analysisManager: analysisManager)
            case .settings:
                SettingsView(networkManager: networkManager, scheduleManager: scheduleManager, scheduleConfigurationManager: scheduleConfigurationManager, activityManager: activityManager)
            }
        }
        .navigationTitle(selectedTab.title)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NetworkStatusView(networkManager: networkManager)
            }
        }
    }
}

struct NetworkStatusView: View {
    @ObservedObject var networkManager: NetworkManager

    var body: some View {
        HStack {
            Text(networkManager.networkStatus.emoji)
            Text(networkManager.networkStatus.description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
        .onTapGesture {
            if !networkManager.networkStatus.isConnected {
                Task {
                    await networkManager.connectToSMB()
                }
            }
        }
    }
}

struct DashboardView: View {
    @ObservedObject var networkManager: NetworkManager
    @ObservedObject var scheduleManager: ScheduleManager
    @ObservedObject var activityManager: ActivityManager

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                // 系统状态卡片
                SystemStatusCard(networkManager: networkManager, scheduleManager: scheduleManager)

                // 统计信息卡片
                StatisticsCard(scheduleManager: scheduleManager)

                // 实时活动卡片
                ActivityLogCard(activityManager: activityManager)
            }
            .padding()
        }
    }
}

struct SystemStatusCard: View {
    @ObservedObject var networkManager: NetworkManager
    @ObservedObject var scheduleManager: ScheduleManager

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("系统状态")
                .font(.headline)
                .fontWeight(.bold)

            HStack(spacing: 20) {
                StatusItem(
                    title: "网络连接",
                    value: networkManager.networkStatus.description,
                    emoji: networkManager.networkStatus.emoji
                )

                StatusItem(
                    title: "定时任务",
                    value: scheduleManager.taskStatus.description,
                    emoji: scheduleManager.taskStatus.emoji
                )

                StatusItem(
                    title: "运行状态",
                    value: scheduleManager.isEnabled ? "运行中" : "已停止",
                    emoji: scheduleManager.isEnabled ? "🟢" : "🔴"
                )
            }

            if let lastScan = scheduleManager.lastScanTime {
                Text("上次扫描: \(lastScan, style: .relative)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let nextScan = scheduleManager.nextScanTime {
                Text("下次扫描: \(nextScan, style: .relative)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

struct StatusItem: View {
    let title: String
    let value: String
    let emoji: String

    var body: some View {
        VStack(alignment: .center, spacing: 4) {
            Text(emoji)
                .font(.title2)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity)
    }
}

struct StatisticsCard: View {
    @ObservedObject var scheduleManager: ScheduleManager

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("今日统计")
                .font(.headline)
                .fontWeight(.bold)

            HStack(spacing: 20) {
                StatItem(title: "已处理", value: "\(scheduleManager.processedToday)", color: .green)
                StatItem(title: "错误数", value: "\(scheduleManager.errorCount)", color: .red)
                StatItem(title: "成功率", value: successRate, color: .blue)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }

    private var successRate: String {
        let total = scheduleManager.processedToday + scheduleManager.errorCount
        guard total > 0 else { return "0%" }
        let rate = Double(scheduleManager.processedToday) / Double(total) * 100
        return String(format: "%.1f%%", rate)
    }
}

struct StatItem: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}


// 其他视图的占位符实现
struct RecordingsView: View {
    @ObservedObject var networkManager: NetworkManager
    @ObservedObject var analysisManager: AnalysisResultManager
    @State private var recordings: [RecordingFile] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading) {
                    Text("录播管理")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("显示和管理网络上的录播文件")
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if networkManager.networkStatus.isConnected {
                    Button {
                        loadRecordings()
                    } label: {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                            Text(isLoading ? "加载中..." : "刷新列表")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isLoading)
                }
            }
            
            if !networkManager.networkStatus.isConnected {
                VStack {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)
                    Text("请先连接到网络")
                        .font(.headline)
                        .foregroundColor(.orange)
                    
                    Button("重新连接") {
                        Task {
                            await networkManager.connectToSMB()
                        }
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
            } else if let errorMessage = errorMessage {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(.red)
                    Text("加载失败")
                        .font(.headline)
                    Text(errorMessage)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("重试") {
                        loadRecordings()
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
            } else if recordings.isEmpty && !isLoading {
                VStack {
                    Image(systemName: "video.slash")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    Text("暂无录播文件")
                        .font(.headline)
                    Text("点击刷新按钮扫描网络上的录播文件")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(recordings, id: \.id) { recording in
                            RecordingRowView(recording: recording, analysisManager: analysisManager)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .padding()
        .onAppear {
            if networkManager.networkStatus.isConnected && recordings.isEmpty {
                loadRecordings()
            }
        }
    }
    
    private func loadRecordings() {
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let loadedRecordings = try await networkManager.listRecordingFiles()
                await MainActor.run {
                    self.recordings = loadedRecordings
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}

struct RecordingRowView: View {
    let recording: RecordingFile
    @ObservedObject var analysisManager: AnalysisResultManager
    @State private var isAnalyzing = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(recording.title)
                    .font(.headline)
                    .lineLimit(2)
                
                HStack {
                    Image(systemName: "tv")
                        .foregroundColor(.blue)
                    Text(recording.channel)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Image(systemName: "calendar")
                        .foregroundColor(.green)
                    Text(recording.dateString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Image(systemName: "doc.text")
                        .foregroundColor(.orange)
                    Text("XML: \(URL(fileURLWithPath: recording.xmlPath).lastPathComponent)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            VStack {
                Button {
                    analyzeRecording()
                } label: {
                    HStack {
                        if isAnalyzing {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "chart.bar.fill")
                        }
                        Text(isAnalyzing ? "分析中" : "分析")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isAnalyzing)
                
                Button {
                    openInFinder()
                } label: {
                    HStack {
                        Image(systemName: "folder")
                        Text("打开")
                    }
                }
                .buttonStyle(.borderless)
                .font(.caption)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    
    private func analyzeRecording() {
        isAnalyzing = true
        
        Task {
            let startTime = Date()
            
            do {
                let parser = XMLDanmakuParser()
                let result = try await parser.parseXMLFile(at: recording.xmlPath)
                
                let analyzer = DanmakuAnalysisEngine()
                let peaks = await analyzer.analyzePeaks(from: result.messages)
                
                let processingDuration = Date().timeIntervalSince(startTime)
                
                // 创建分析结果
                let analysisResult = AnalysisTaskResult(
                    id: UUID(),
                    recordingFile: recording,
                    xmlResult: result,
                    peaks: peaks,
                    analysisTime: Date(),
                    processingDuration: processingDuration
                )
                
                print("✅ 分析完成: \(recording.displayName)")
                print("📊 弹幕总数: \(result.totalCount)")
                print("🎯 发现峰值: \(peaks.count)")
                print("⏱️ 处理耗时: \(TimeFormatter.formatDuration(processingDuration))")
                
                await MainActor.run {
                    analysisManager.addResult(analysisResult)
                    isAnalyzing = false
                }
                
            } catch {
                print("❌ 分析失败: \(error)")
                await MainActor.run {
                    isAnalyzing = false
                }
            }
        }
    }
    
    private func openInFinder() {
        let url = URL(fileURLWithPath: recording.path)
        NSWorkspace.shared.open(url)
    }
}

struct ScheduleView: View {
    @ObservedObject var scheduleManager: ScheduleManager

    var body: some View {
        VStack {
            Text("定时任务管理")
                .font(.largeTitle)

            HStack {
                Button(scheduleManager.isEnabled ? "停止定时任务" : "启动定时任务") {
                    if scheduleManager.isEnabled {
                        scheduleManager.stopSchedule()
                    } else {
                        scheduleManager.startSchedule()
                    }
                }
                .buttonStyle(.borderedProminent)

                Button("手动扫描") {
                    Task {
                        await scheduleManager.triggerManualScan()
                    }
                }
                .buttonStyle(.bordered)
                .disabled(scheduleManager.taskStatus != .idle)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct AnalysisView: View {
    @ObservedObject var analysisManager: AnalysisResultManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading) {
                    Text("分析结果")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("查看弹幕峰值分析结果")
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button {
                    analysisManager.refreshResults()
                } label: {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("刷新")
                    }
                }
                .buttonStyle(.bordered)
            }
            
            if analysisManager.results.isEmpty {
                VStack {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    Text("暂无分析结果")
                        .font(.headline)
                    Text("在录播管理中分析录播文件后，结果将显示在这里")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(analysisManager.results, id: \.id) { result in
                            AnalysisResultRowView(result: result)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .padding()
        .onAppear {
            analysisManager.refreshResults()
        }
    }
}

struct AnalysisResultRowView: View {
    let result: AnalysisTaskResult
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 基本信息
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.recordingFile.title)
                        .font(.headline)
                        .lineLimit(2)
                    
                    HStack {
                        Image(systemName: "tv")
                            .foregroundColor(.blue)
                        Text(result.recordingFile.channel)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Image(systemName: "calendar")
                            .foregroundColor(.green)
                        Text(result.recordingFile.dateString)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // 录播时间范围
                    if let recordingTimeRange = getRecordingTimeRange(from: result) {
                        HStack {
                            Image(systemName: "clock")
                                .foregroundColor(.purple)
                            Text("录播时间: \(recordingTimeRange)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Button {
                        withAnimation {
                            isExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    }
                    .buttonStyle(.borderless)
                }
            }
            
            // 统计信息
            HStack(spacing: 20) {
                StatBox(title: "弹幕总数", value: "\(result.xmlResult.totalCount)", color: .blue)
                StatBox(title: "峰值数量", value: "\(result.peaks.count)", color: .orange)
                StatBox(title: "每分钟", value: String(format: "%.1f", result.xmlResult.messagesPerMinute), color: .green)
                StatBox(title: "处理时间", value: TimeFormatter.formatDuration(result.processingDuration), color: .purple)
            }
            
            // 展开的详细信息
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("弹幕峰值详情")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Spacer()
                        Text("分析时间: \(TimeFormatter.formatTimestamp(result.analysisTime))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if result.peaks.isEmpty {
                        Text("未发现明显的弹幕峰值")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        ExpandablePeaksView(peaks: result.peaks)
                    }
                }
                .padding(.top, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    // 计算录播时间范围
    private func getRecordingTimeRange(from result: AnalysisTaskResult) -> String? {
        let messages = result.xmlResult.messages
        guard !messages.isEmpty else { return nil }
        
        // 获取第一条和最后一条弹幕的绝对时间
        let sortedMessages = messages.sorted { $0.timestamp < $1.timestamp }
        guard let firstMessage = sortedMessages.first,
              let lastMessage = sortedMessages.last else { return nil }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        
        let startTime = formatter.string(from: firstMessage.absoluteTime)
        let endTime = formatter.string(from: lastMessage.absoluteTime)
        
        // 计算录播时长
        let duration = lastMessage.absoluteTime.timeIntervalSince(firstMessage.absoluteTime)
        let durationString = TimeFormatter.formatDuration(duration)
        
        return "\(startTime) - \(endTime) (\(durationString))"
    }
}

struct StatBox: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct PeakRowView: View {
    let peak: AnalysisTaskResult.DanmakuPeak
    let rank: Int
    
    var body: some View {
        HStack {
            // 排名
            Text("#\(rank)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(rankColor)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 6) {
                // 时间信息（相对时间 + 绝对时间）
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("录播时间:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(peak.relativeTimeDescription)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("(\(peak.durationDescription))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("实际时间:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(peak.absoluteTimeDescription)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                    }
                }
                
                // 统计信息（移除重复的弹幕数量显示）
                HStack(spacing: 16) {
                    HStack {
                        Image(systemName: "textformat.size")
                            .foregroundColor(.green)
                        Text(String(format: "%.1f 字", peak.averageLength))
                            .font(.caption)
                    }
                    
                    HStack {
                        Image(systemName: "location")
                            .foregroundColor(.orange)
                        Text(peak.dominantPosition.displayName)
                            .font(.caption)
                    }
                    
                    Spacer()
                    
                    // 弹幕数量作为重点信息放在右侧
                    HStack {
                        Text("\(peak.count)")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(rankColor)
                        Text("条弹幕")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
    }
    
    private var rankColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .brown
        default: return .blue
        }
    }
}

// 分析结果管理器
@MainActor
class AnalysisResultManager: ObservableObject {
    @Published var results: [AnalysisTaskResult] = []
    
    func addResult(_ result: AnalysisTaskResult) {
        results.insert(result, at: 0) // 添加到开头
        // 限制最多保存 50 个结果
        if results.count > 50 {
            results = Array(results.prefix(50))
        }
    }
    
    func refreshResults() {
        // 这里可以从持久化存储中加载结果
        // 目前我们保持内存中的结果
    }
    
    func clearResults() {
        results.removeAll()
    }
}

struct SettingsView: View {
    @ObservedObject var networkManager: NetworkManager
    @ObservedObject var scheduleManager: ScheduleManager
    @ObservedObject var scheduleConfigurationManager: ScheduleConfigurationManager
    @ObservedObject var activityManager: ActivityManager
    @StateObject private var configurationManager = SMBConfigurationManager()
    @StateObject private var discoveryManager = SMBDiscoveryManager()
    @State private var showingAddConfiguration = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 页面标题
                VStack(alignment: .leading, spacing: 8) {
                    Text("设置")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("配置网络连接和定时任务参数")
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                
                // SMB服务器配置卡片
                SMBConfigurationCard(
                    configurationManager: configurationManager,
                    discoveryManager: discoveryManager,
                    showingAddConfiguration: $showingAddConfiguration
                )
                .padding(.horizontal)
                
                // 定时任务配置卡片
                ScheduleConfigurationCard(scheduleManager: scheduleManager, scheduleConfigurationManager: scheduleConfigurationManager)
                    .padding(.horizontal)
                
                
                // 网络状态卡片
                NetworkStatusCard(networkManager: networkManager)
                    .padding(.horizontal)
                
                Spacer(minLength: 20)
            }
            .padding(.vertical)
        }
        .sheet(isPresented: $showingAddConfiguration) {
            AddSMBConfigurationView(
                configurationManager: configurationManager,
                discoveryManager: discoveryManager
            )
        }
    }
}

struct SMBConfigurationCard: View {
    @ObservedObject var configurationManager: SMBConfigurationManager
    @ObservedObject var discoveryManager: SMBDiscoveryManager
    @Binding var showingAddConfiguration: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 卡片标题
            HStack {
                Image(systemName: "server.rack")
                    .foregroundColor(.blue)
                    .font(.title2)
                Text("SMB服务器配置")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                
                // 状态指示
                if configurationManager.selectedConfiguration != nil {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text("1个已选择")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            
            // 配置说明
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.blue)
                    .font(.caption)
                Text("点击圆圈选择服务器，配置用于存储录播文件的SMB网络共享")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
            
            // 所有配置列表
            VStack(spacing: 12) {
                ForEach(configurationManager.configurations) { config in
                    SMBConfigurationRow(
                        configuration: config,
                        isSelected: config.id == configurationManager.selectedConfiguration?.id,
                        configurationManager: configurationManager
                    )
                }
            }
            
            // 操作按钮组
            HStack(spacing: 12) {
                Button {
                    showingAddConfiguration = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                        Text("添加服务器")
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                }
                .buttonStyle(.bordered)
                
                Button {
                    discoveryManager.startDiscovery()
                } label: {
                    HStack(spacing: 6) {
                        if discoveryManager.isDiscovering {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "magnifyingglass")
                        }
                        Text(discoveryManager.isDiscovering ? "扫描中..." : "扫描网络")
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                }
                .buttonStyle(.borderedProminent)
                .disabled(discoveryManager.isDiscovering)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

struct SMBConfigurationRow: View {
    let configuration: SMBConfiguration
    let isSelected: Bool
    @ObservedObject var configurationManager: SMBConfigurationManager
    @State private var isTesting = false
    @State private var testResult: Bool?
    @State private var showingDeleteAlert = false
    
    var body: some View {
        HStack {
            // 选择状态指示器
            VStack {
                Button {
                    if !isSelected {
                        configurationManager.selectConfiguration(configuration)
                    }
                } label: {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundColor(isSelected ? .green : .gray)
                }
                .buttonStyle(.plain)
                .help(isSelected ? "当前选中的服务器" : "点击选择此服务器")
            }
            .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(configuration.name)
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    if isSelected {
                        Text("当前使用")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.green)
                            .cornerRadius(12)
                    }
                }
                
                HStack {
                    Image(systemName: "server.rack")
                        .foregroundColor(.blue)
                        .font(.caption)
                    Text("\(configuration.host):\(configuration.port)")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }
                
                HStack {
                    Image(systemName: "folder.badge.gearshape")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text("共享: \(configuration.shareName)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let username = configuration.username {
                    HStack {
                        Image(systemName: "person.fill")
                            .foregroundColor(.purple)
                            .font(.caption)
                        Text("用户: \(username)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // 操作按钮组
            HStack(spacing: 8) {
                // 连接测试按钮
                Button {
                    testConnection()
                } label: {
                    HStack(spacing: 4) {
                        if isTesting {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: testResult == true ? "checkmark.circle.fill" : 
                                  testResult == false ? "xmark.circle.fill" : "network.badge.shield.half.filled")
                                .foregroundColor(testResult == true ? .green : 
                                               testResult == false ? .red : .blue)
                        }
                        if !isTesting {
                            Text(testResult == true ? "连接正常" : 
                                 testResult == false ? "连接失败" : "测试连接")
                                .font(.caption)
                        }
                    }
                    .frame(minWidth: 80)
                }
                .buttonStyle(.bordered)
                .disabled(isTesting)
                .help("测试与此SMB服务器的连接")
                
                // 删除按钮
                if configurationManager.configurations.count > 1 {
                    Button {
                        showingDeleteAlert = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.bordered)
                    .help("删除此SMB配置")
                }
            }
        }
        .padding()
        .background(isSelected ? Color.blue.opacity(0.08) : Color.gray.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 2)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if !isSelected {
                configurationManager.selectConfiguration(configuration)
            }
        }
        .alert("删除服务器配置", isPresented: $showingDeleteAlert) {
            Button("删除", role: .destructive) {
                configurationManager.deleteConfiguration(configuration)
            }
            Button("取消", role: .cancel) { }
        } message: {
            Text("确定要删除服务器配置 \"\(configuration.name)\" 吗？此操作无法撤销。")
        }
    }
    
    private func testConnection() {
        isTesting = true
        testResult = nil
        
        Task {
            let result = await configurationManager.testConfiguration(configuration)
            await MainActor.run {
                testResult = result
                isTesting = false
            }
        }
    }
}

struct ScheduleConfigurationCard: View {
    @ObservedObject var scheduleManager: ScheduleManager
    @ObservedObject var scheduleConfigurationManager: ScheduleConfigurationManager
    @State private var selectedInterval: TimeInterval
    
    init(scheduleManager: ScheduleManager, scheduleConfigurationManager: ScheduleConfigurationManager) {
        self.scheduleManager = scheduleManager
        self.scheduleConfigurationManager = scheduleConfigurationManager
        self._selectedInterval = State(initialValue: scheduleConfigurationManager.configuration.interval)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 卡片标题
            HStack {
                Image(systemName: "calendar.clock")
                    .foregroundColor(.orange)
                    .font(.title2)
                Text("定时任务设置")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
            }
            
            // 定时扫描开关
            HStack {
                VStack(alignment: .leading) {
                    Text("定时扫描")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("自动扫描和分析新的录播文件")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { scheduleManager.isEnabled },
                    set: { enabled in
                        scheduleManager.updateEnabled(enabled)
                    }
                ))
            }
            
            // 扫描间隔设置
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("扫描间隔")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Text(scheduleConfigurationManager.configuration.intervalDisplayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Picker("扫描间隔", selection: Binding(
                    get: { selectedInterval },
                    set: { newInterval in
                        selectedInterval = newInterval
                        scheduleManager.updateScanInterval(newInterval)
                    }
                )) {
                    ForEach(ScheduleConfiguration.intervalOptions, id: \.1) { name, interval in
                        Text(name).tag(interval)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .disabled(!scheduleManager.isEnabled)
            }
            .padding()
            .background(Color.orange.opacity(0.05))
            .cornerRadius(8)
            
            // 状态信息
            if scheduleManager.isEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    if let nextScan = scheduleManager.nextScanTime {
                        HStack {
                            Image(systemName: "clock")
                                .foregroundColor(.blue)
                            Text("下次扫描: \(nextScan, style: .relative)")
                                .font(.subheadline)
                        }
                    }
                    
                    if let lastScan = scheduleManager.lastScanTime {
                        HStack {
                            Image(systemName: "checkmark.circle")
                                .foregroundColor(.green)
                            Text("上次扫描: \(lastScan, style: .relative)")
                                .font(.subheadline)
                        }
                    }
                    
                    HStack {
                        Image(systemName: "timer")
                            .foregroundColor(.purple)
                        Text("扫描间隔: \(scheduleConfigurationManager.configuration.intervalDisplayName)")
                            .font(.subheadline)
                    }
                }
                .padding()
                .background(Color.blue.opacity(0.05))
                .cornerRadius(8)
            }
            
            // 立即扫描按钮
            Button {
                Task {
                    await scheduleManager.triggerManualScan()
                }
            } label: {
                HStack {
                    Image(systemName: scheduleManager.taskStatus == .idle ? "play.circle" : "hourglass")
                    Text(scheduleManager.taskStatus == .idle ? "立即扫描" : "扫描中...")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(scheduleManager.taskStatus != .idle)
            
            // 配置说明
            Text("配置弹幕分析的定时扫描任务，可自定义扫描间隔")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
        .onChange(of: scheduleConfigurationManager.configuration.interval) { newInterval in
            selectedInterval = newInterval
        }
    }
}

struct NetworkStatusCard: View {
    @ObservedObject var networkManager: NetworkManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 卡片标题
            HStack {
                Image(systemName: "network")
                    .foregroundColor(.green)
                    .font(.title2)
                Text("网络状态")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
            }
            
            // 连接状态
            HStack {
                VStack(alignment: .leading) {
                    Text("连接状态")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("SMB服务器连接状态")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                HStack {
                    Text(networkManager.networkStatus.emoji)
                        .font(.title2)
                    Text(networkManager.networkStatus.description)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
            
            // 错误信息和重试信息
            if networkManager.lastError != nil || networkManager.connectionRetryCount > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    if let error = networkManager.lastError {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.red)
                            Text("错误: \(error)")
                                .font(.subheadline)
                                .foregroundColor(.red)
                        }
                    }
                    
                    if networkManager.connectionRetryCount > 0 {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(.orange)
                            Text("重试次数: \(networkManager.connectionRetryCount)")
                                .font(.subheadline)
                                .foregroundColor(.orange)
                        }
                    }
                }
                .padding()
                .background(Color.red.opacity(0.05))
                .cornerRadius(8)
            }
            
            // 重新连接按钮
            Button {
                Task {
                    await networkManager.connectToSMB()
                }
            } label: {
                HStack {
                    Image(systemName: networkManager.networkStatus == .connecting ? "hourglass" : "arrow.clockwise")
                    Text(networkManager.networkStatus == .connecting ? "连接中..." : "重新连接")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(networkManager.networkStatus == .connecting)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

struct ActivityLogCard: View {
    @ObservedObject var activityManager: ActivityManager
    @State private var showingAllActivities = false
    
    private let maxDisplayActivities = 5
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 卡片标题
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundColor(.purple)
                    .font(.title2)
                Text("实时活动")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                
                // 活动数量指示
                if !activityManager.activities.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "dot.radiowaves.up.forward")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text("\(activityManager.activities.count)条记录")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            
            // 活动列表
            if activityManager.activities.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "moon.zzz")
                        .font(.system(size: 32))
                        .foregroundColor(.gray)
                    Text("暂无活动记录")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("执行任务后将在此显示活动记录")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                let displayActivities = showingAllActivities ? 
                    activityManager.activities : 
                    Array(activityManager.activities.prefix(maxDisplayActivities))
                
                VStack(spacing: 8) {
                    ForEach(displayActivities) { activity in
                        ActivityRowView(activity: activity)
                    }
                }
                
                // 展开/收起按钮
                if activityManager.activities.count > maxDisplayActivities {
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showingAllActivities.toggle()
                        }
                    } label: {
                        HStack {
                            Image(systemName: showingAllActivities ? "chevron.up" : "chevron.down")
                            Text(showingAllActivities ? 
                                 "收起" : 
                                 "显示更多 (\(activityManager.activities.count - maxDisplayActivities)条)")
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
                }
                
                // 清除按钮
                HStack {
                    Spacer()
                    Button("清除记录") {
                        activityManager.clearActivities()
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

struct ActivityRowView: View {
    let activity: ActivityLog
    
    var body: some View {
        HStack(spacing: 12) {
            // 类型图标
            Image(systemName: activity.type.icon)
                .foregroundColor(activity.type.color)
                .font(.caption)
                .frame(width: 16)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(activity.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text(activity.timeString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(activity.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                // 详细信息
                if let details = activity.details, !details.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(Array(details.prefix(2)), id: \.key) { key, value in
                            Text("\(key): \(value)")
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(4)
                        }
                        
                        if details.count > 2 {
                            Text("+\(details.count - 2)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            // 状态图标
            Image(systemName: activity.status.icon)
                .foregroundColor(activity.status.color)
                .font(.caption)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(Color.white.opacity(0.5))
        .cornerRadius(8)
    }
}

struct ExpandablePeaksView: View {
    let peaks: [AnalysisTaskResult.DanmakuPeak]
    @State private var showingAllPeaks = false
    
    private let defaultPeaksToShow = 5
    
    var body: some View {
        VStack(spacing: 8) {
            let displayPeaks = showingAllPeaks ? peaks : Array(peaks.prefix(defaultPeaksToShow))
            
            ForEach(Array(displayPeaks.enumerated()), id: \.offset) { index, peak in
                PeakRowView(peak: peak, rank: index + 1)
                    .opacity(index >= defaultPeaksToShow ? 0.8 : 1.0)
            }
            
            // 展开/收起按钮
            if peaks.count > defaultPeaksToShow {
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showingAllPeaks.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: showingAllPeaks ? "chevron.up" : "chevron.down")
                            .font(.caption)
                        
                        if showingAllPeaks {
                            Text("收起峰值列表")
                        } else {
                            Text("显示更多峰值 (\(peaks.count - defaultPeaksToShow)个)")
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(16)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
            }
            
            // 峰值统计信息
            if showingAllPeaks && peaks.count > defaultPeaksToShow {
                VStack(spacing: 4) {
                    Divider()
                        .padding(.horizontal, 16)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("峰值统计")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            
                            Text("共 \(peaks.count) 个峰值")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("平均强度")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            
                            let avgCount = peaks.isEmpty ? 0 : peaks.reduce(0) { $0 + $1.count } / peaks.count
                            Text("\(avgCount) 条/分钟")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(6)
                }
                .padding(.top, 8)
            }
        }
    }
}

