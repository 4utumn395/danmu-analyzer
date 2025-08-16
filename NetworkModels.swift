import Foundation
import Network

// MARK: - 网络相关数据模型

/// 发现的SMB服务
struct DiscoveredSMBService {
    let id: String
    let name: String
    let host: String
    let port: Int
    let addresses: [String]
    let discoveredAt: Date
    
    var displayName: String {
        return name.isEmpty ? host : name
    }
}

/// SMB服务发现状态
enum SMBDiscoveryStatus {
    case idle
    case discovering
    case completed(services: [DiscoveredSMBService])
    case failed(Error)
}

/// SMB 连接配置
struct SMBConfiguration: Codable, Identifiable {
    let id: String
    let name: String
    let host: String
    let shareName: String
    let username: String?
    let password: String?
    let port: Int
    let isDefault: Bool
    let createdAt: Date
    
    init(id: String = UUID().uuidString,
         name: String,
         host: String,
         shareName: String = "recordings",
         username: String? = nil,
         password: String? = nil,
         port: Int = 445,
         isDefault: Bool = false,
         createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.host = host
        self.shareName = shareName
        self.username = username
        self.password = password
        self.port = port
        self.isDefault = isDefault
        self.createdAt = createdAt
    }
    
    /// 从发现的服务创建配置
    init(from service: DiscoveredSMBService, shareName: String = "recordings") {
        self.id = service.id
        self.name = service.displayName
        self.host = service.host
        self.shareName = shareName
        self.username = nil
        self.password = nil
        self.port = service.port
        self.isDefault = false
        self.createdAt = Date()
    }

    static let placeholder = SMBConfiguration(
        name: "示例SMB服务器",
        host: "localhost", // 用户需要在设置中配置实际的主机地址
        shareName: "recordings", // 用户需要在设置中配置实际的共享名称
        username: nil, // 用户可在设置中配置用户名
        password: nil, // 用户可在设置中配置密码
        port: 445,
        isDefault: true
    )

    var smbURL: URL? {
        var components = URLComponents()
        components.scheme = "smb"
        components.host = host
        components.port = port
        components.path = "/\(shareName)"
        return components.url
    }
    
    var displayInfo: String {
        return "\(name) (\(host):\(port)/\(shareName))"
    }
}

/// 录播文件信息
struct RecordingFile {
    let id: String
    let name: String
    let path: String
    let xmlPath: String
    let date: Date
    let channel: String
    let title: String

    var displayName: String {
        return "\(channel) - \(title)"
    }

    var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }
}

/// 弹幕消息（来自XML）
struct DanmakuMessage {
    let timestamp: Double // 相对时间（秒）
    let absoluteTime: Date // 绝对时间
    let userId: String? // 用户ID
    let username: String? // 用户名
    let content: String // 弹幕内容
    let color: String? // 颜色
    let fontSize: Int? // 字体大小
    let position: DanmakuPosition // 位置

    enum DanmakuPosition: String, CaseIterable {
        case scroll // 滚动
        case top // 顶部
        case bottom // 底部

        var displayName: String {
            switch self {
            case .scroll: return "滚动"
            case .top: return "顶部"
            case .bottom: return "底部"
            }
        }
    }
}

/// XML 弹幕解析结果
struct XMLDanmakuResult {
    let recordingFile: RecordingFile
    let messages: [DanmakuMessage]
    let totalCount: Int
    let duration: TimeInterval
    let parseTime: Date

    var messagesPerMinute: Double {
        return duration > 0 ? Double(totalCount) / (duration / 60.0) : 0
    }
}

/// 定时任务配置
struct ScheduleConfiguration: Codable {
    let enabled: Bool
    let interval: TimeInterval // 检查间隔（秒）
    let scanTime: DateComponents // 每天扫描时间
    let maxRetries: Int
    let timeout: TimeInterval

    static let `default` = ScheduleConfiguration(
        enabled: true,
        interval: 3600, // 1小时
        scanTime: DateComponents(hour: 2, minute: 0), // 凌晨2点
        maxRetries: 3,
        timeout: 30.0
    )
    
    /// 间隔选项
    static let intervalOptions: [(String, TimeInterval)] = [
        ("5分钟", 300),
        ("15分钟", 900),
        ("30分钟", 1800),
        ("1小时", 3600),
        ("2小时", 7200),
        ("6小时", 21600),
        ("12小时", 43200),
        ("24小时", 86400)
    ]
    
    var intervalDisplayName: String {
        for (name, value) in Self.intervalOptions {
            if abs(value - interval) < 1 {
                return name
            }
        }
        return "自定义 (\(Int(interval / 60))分钟)"
    }
}

/// 网络状态
enum NetworkStatus: Equatable {
    case disconnected
    case connecting
    case connected
    case error(String)

    var isConnected: Bool {
        switch self {
        case .connected: return true
        default: return false
        }
    }

    var description: String {
        switch self {
        case .disconnected: return "未连接"
        case .connecting: return "连接中"
        case .connected: return "已连接"
        case let .error(message): return "错误: \(message)"
        }
    }

    var emoji: String {
        switch self {
        case .disconnected: return "🔴"
        case .connecting: return "🟡"
        case .connected: return "🟢"
        case .error: return "❌"
        }
    }
}

/// 扫描任务状态
enum ScanTaskStatus: Equatable {
    case idle
    case scanning
    case processing
    case completed
    case failed(Error)

    static func == (lhs: ScanTaskStatus, rhs: ScanTaskStatus) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.scanning, .scanning), (.processing, .processing), (.completed, .completed):
            return true
        case (.failed, .failed):
            return true // 简化比较，不比较具体错误
        default:
            return false
        }
    }

    var description: String {
        switch self {
        case .idle: return "待机"
        case .scanning: return "扫描中"
        case .processing: return "处理中"
        case .completed: return "已完成"
        case .failed: return "失败"
        }
    }

    var emoji: String {
        switch self {
        case .idle: return "⏸️"
        case .scanning: return "🔍"
        case .processing: return "⚙️"
        case .completed: return "✅"
        case .failed: return "❌"
        }
    }
}

/// 分析任务结果
struct AnalysisTaskResult {
    let id: UUID
    let recordingFile: RecordingFile
    let xmlResult: XMLDanmakuResult
    let peaks: [DanmakuPeak]
    let analysisTime: Date
    let processingDuration: TimeInterval

    struct DanmakuPeak {
        let startTime: Double // 相对时间（秒）
        let endTime: Double // 相对时间（秒）
        let startAbsoluteTime: Date // 绝对开始时间
        let endAbsoluteTime: Date // 绝对结束时间
        let count: Int
        let averageLength: Double
        let dominantPosition: DanmakuMessage.DanmakuPosition

        var relativeTimeDescription: String {
            let start = TimeFormatter.formatTime(startTime)
            let end = TimeFormatter.formatTime(endTime)
            return "\(start)-\(end)"
        }
        
        var absoluteTimeDescription: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss"
            let start = formatter.string(from: startAbsoluteTime)
            let end = formatter.string(from: endAbsoluteTime)
            return "\(start)-\(end)"
        }
        
        var durationDescription: String {
            let duration = endTime - startTime
            return TimeFormatter.formatDuration(duration)
        }
    }
}

/// 系统监控信息
struct SystemMonitorInfo {
    let networkStatus: NetworkStatus
    let taskStatus: ScanTaskStatus
    let lastScanTime: Date?
    let nextScanTime: Date?
    let totalRecordings: Int
    let processedToday: Int
    let errorCount: Int
    let averageProcessingTime: TimeInterval

    var uptimeString: String {
        guard let lastScan = lastScanTime else { return "未知" }
        let uptime = Date().timeIntervalSince(lastScan)
        return TimeFormatter.formatDuration(uptime)
    }
}
