import Foundation
import SwiftUI

// MARK: - 活动日志模型

struct ActivityLog: Identifiable, Codable {
    let id = UUID()
    let timestamp: Date
    let type: ActivityType
    let title: String
    let description: String
    let status: ActivityStatus
    let details: [String: String]?
    
    enum ActivityType: String, Codable, CaseIterable {
        case networkConnection = "network"
        case fileScanning = "scan"
        case analysis = "analysis"
        case configuration = "config"
        case system = "system"
        
        var icon: String {
            switch self {
            case .networkConnection:
                return "network"
            case .fileScanning:
                return "magnifyingglass"
            case .analysis:
                return "chart.line.uptrend.xyaxis"
            case .configuration:
                return "gearshape"
            case .system:
                return "computer"
            }
        }
        
        var color: Color {
            switch self {
            case .networkConnection:
                return .blue
            case .fileScanning:
                return .purple
            case .analysis:
                return .green
            case .configuration:
                return .orange
            case .system:
                return .gray
            }
        }
    }
    
    enum ActivityStatus: String, Codable {
        case success = "success"
        case warning = "warning"
        case error = "error"
        case inProgress = "in_progress"
        
        var icon: String {
            switch self {
            case .success:
                return "checkmark.circle.fill"
            case .warning:
                return "exclamationmark.triangle.fill"
            case .error:
                return "xmark.circle.fill"
            case .inProgress:
                return "hourglass"
            }
        }
        
        var color: Color {
            switch self {
            case .success:
                return .green
            case .warning:
                return .orange
            case .error:
                return .red
            case .inProgress:
                return .blue
            }
        }
    }
    
    var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: timestamp)
    }
    
    var relativeDateString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
}

// MARK: - 活动管理器

@MainActor
class ActivityManager: ObservableObject {
    @Published var activities: [ActivityLog] = []
    
    private let maxActivities = 100
    private let userDefaultsKey = "ActivityLogs"
    
    init() {
        loadActivities()
    }
    
    /// 添加新活动
    func logActivity(
        type: ActivityLog.ActivityType,
        title: String,
        description: String,
        status: ActivityLog.ActivityStatus,
        details: [String: String]? = nil
    ) {
        let activity = ActivityLog(
            timestamp: Date(),
            type: type,
            title: title,
            description: description,
            status: status,
            details: details
        )
        
        activities.insert(activity, at: 0)
        
        // 限制活动数量
        if activities.count > maxActivities {
            activities = Array(activities.prefix(maxActivities))
        }
        
        saveActivities()
        print("📝 活动记录: \(title) - \(status.rawValue)")
    }
    
    /// 获取最近的活动
    func getRecentActivities(limit: Int = 10) -> [ActivityLog] {
        return Array(activities.prefix(limit))
    }
    
    /// 按类型获取活动
    func getActivities(ofType type: ActivityLog.ActivityType, limit: Int = 10) -> [ActivityLog] {
        return Array(activities.filter { $0.type == type }.prefix(limit))
    }
    
    /// 清除所有活动
    func clearActivities() {
        activities.removeAll()
        saveActivities()
    }
    
    /// 清除旧活动 (保留最近24小时)
    func clearOldActivities() {
        let cutoffDate = Calendar.current.date(byAdding: .hour, value: -24, to: Date()) ?? Date()
        activities = activities.filter { $0.timestamp > cutoffDate }
        saveActivities()
    }
    
    // MARK: - 持久化
    
    private func saveActivities() {
        do {
            let data = try JSONEncoder().encode(activities)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        } catch {
            print("⚠️ 保存活动记录失败: \(error)")
        }
    }
    
    private func loadActivities() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else { return }
        
        do {
            activities = try JSONDecoder().decode([ActivityLog].self, from: data)
            // 清理超过7天的活动
            let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            activities = activities.filter { $0.timestamp > weekAgo }
        } catch {
            print("⚠️ 加载活动记录失败: \(error)")
            activities = []
        }
    }
}

// MARK: - 便利扩展

extension ActivityManager {
    /// 记录网络连接活动
    func logNetworkActivity(title: String, success: Bool, details: [String: String]? = nil) {
        logActivity(
            type: .networkConnection,
            title: title,
            description: success ? "网络连接操作成功" : "网络连接操作失败",
            status: success ? .success : .error,
            details: details
        )
    }
    
    /// 记录文件扫描活动
    func logScanActivity(title: String, fileCount: Int? = nil, details: [String: String]? = nil) {
        var activityDetails = details ?? [:]
        if let count = fileCount {
            activityDetails["文件数量"] = "\(count)"
        }
        
        logActivity(
            type: .fileScanning,
            title: title,
            description: "扫描录播文件",
            status: .success,
            details: activityDetails
        )
    }
    
    /// 记录分析活动
    func logAnalysisActivity(title: String, peakCount: Int? = nil, duration: TimeInterval? = nil) {
        var details: [String: String] = [:]
        if let count = peakCount {
            details["峰值数量"] = "\(count)"
        }
        if let duration = duration {
            details["分析时长"] = String(format: "%.1f秒", duration)
        }
        
        logActivity(
            type: .analysis,
            title: title,
            description: "弹幕峰值分析完成",
            status: .success,
            details: details
        )
    }
    
    /// 记录配置活动
    func logConfigurationActivity(title: String, details: [String: String]? = nil) {
        logActivity(
            type: .configuration,
            title: title,
            description: "配置更改",
            status: .success,
            details: details
        )
    }
}