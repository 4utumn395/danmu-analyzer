import Foundation

// MARK: - 定时任务配置管理器

@MainActor
class ScheduleConfigurationManager: ObservableObject {
    @Published var configuration: ScheduleConfiguration = .default
    
    private let configurationKey = "ScheduleConfiguration"
    
    nonisolated init() {
        Task { @MainActor in
            loadConfiguration()
        }
    }
    
    /// 加载配置
    private func loadConfiguration() {
        if let data = UserDefaults.standard.data(forKey: configurationKey),
           let decoded = try? JSONDecoder().decode(ScheduleConfiguration.self, from: data) {
            configuration = decoded
        } else {
            // 如果没有保存的配置，使用默认配置
            configuration = .default
            saveConfiguration()
        }
    }
    
    /// 保存配置
    private func saveConfiguration() {
        if let encoded = try? JSONEncoder().encode(configuration) {
            UserDefaults.standard.set(encoded, forKey: configurationKey)
            // 发送配置变化通知
            NotificationCenter.default.post(name: .scheduleConfigurationChanged, object: nil)
        }
    }
    
    /// 更新扫描间隔
    func updateInterval(_ interval: TimeInterval) {
        configuration = ScheduleConfiguration(
            enabled: configuration.enabled,
            interval: interval,
            scanTime: configuration.scanTime,
            maxRetries: configuration.maxRetries,
            timeout: configuration.timeout
        )
        saveConfiguration()
    }
    
    /// 更新启用状态
    func updateEnabled(_ enabled: Bool) {
        configuration = ScheduleConfiguration(
            enabled: enabled,
            interval: configuration.interval,
            scanTime: configuration.scanTime,
            maxRetries: configuration.maxRetries,
            timeout: configuration.timeout
        )
        saveConfiguration()
    }
    
    /// 更新扫描时间
    func updateScanTime(_ scanTime: DateComponents) {
        configuration = ScheduleConfiguration(
            enabled: configuration.enabled,
            interval: configuration.interval,
            scanTime: scanTime,
            maxRetries: configuration.maxRetries,
            timeout: configuration.timeout
        )
        saveConfiguration()
    }
    
    /// 重置为默认配置
    func resetToDefault() {
        configuration = .default
        saveConfiguration()
    }
}