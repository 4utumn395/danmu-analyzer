import Foundation
import Network

fileprivate class ResumeState {
    private var hasResumed = false
    private let lock = NSLock()
    
    func resumeOnce(_ block: () -> Void) {
        lock.lock()
        defer { lock.unlock() }
        
        if !hasResumed {
            hasResumed = true
            block()
        }
    }
}

// MARK: - SMB配置管理器

@MainActor
class SMBConfigurationManager: ObservableObject {
    @Published var configurations: [SMBConfiguration] = []
    @Published var selectedConfiguration: SMBConfiguration?
    
    private let configurationKey = "SMBConfigurations"
    private let selectedConfigKey = "SelectedSMBConfiguration"
    
    nonisolated init() {
        Task { @MainActor in
            loadConfigurations()
        }
    }
    
    /// 加载配置
    private func loadConfigurations() {
        if let data = UserDefaults.standard.data(forKey: configurationKey),
           let decoded = try? JSONDecoder().decode([SMBConfiguration].self, from: data) {
            configurations = decoded
        } else {
            // 如果没有保存的配置，添加默认配置
            configurations = [SMBConfiguration.placeholder]
        }
        
        // 加载选中的配置
        if let selectedId = UserDefaults.standard.string(forKey: selectedConfigKey),
           let config = configurations.first(where: { $0.id == selectedId }) {
            selectedConfiguration = config
        } else if !configurations.isEmpty {
            selectedConfiguration = configurations.first
        }
    }
    
    /// 保存配置
    private func saveConfigurations() {
        if let encoded = try? JSONEncoder().encode(configurations) {
            UserDefaults.standard.set(encoded, forKey: configurationKey)
        }
        
        if let selectedId = selectedConfiguration?.id {
            UserDefaults.standard.set(selectedId, forKey: selectedConfigKey)
        }
    }
    
    /// 添加配置
    func addConfiguration(_ configuration: SMBConfiguration) {
        // 检查是否已存在相同的配置
        if !configurations.contains(where: { $0.host == configuration.host && $0.port == configuration.port && $0.shareName == configuration.shareName }) {
            configurations.append(configuration)
            
            // 如果是第一个配置，自动选中
            if selectedConfiguration == nil {
                selectedConfiguration = configuration
            }
            
            saveConfigurations()
            print("✅ 添加SMB配置: \(configuration.displayInfo)")
        } else {
            print("⚠️ SMB配置已存在: \(configuration.displayInfo)")
        }
    }
    
    /// 更新配置
    func updateConfiguration(_ configuration: SMBConfiguration) {
        if let index = configurations.firstIndex(where: { $0.id == configuration.id }) {
            configurations[index] = configuration
            
            // 如果更新的是当前选中的配置，也要更新选中项
            if selectedConfiguration?.id == configuration.id {
                selectedConfiguration = configuration
            }
            
            saveConfigurations()
            print("✅ 更新SMB配置: \(configuration.displayInfo)")
        }
    }
    
    /// 删除配置
    func deleteConfiguration(_ configuration: SMBConfiguration) {
        configurations.removeAll { $0.id == configuration.id }
        
        // 如果删除的是当前选中的配置，选择其他配置
        if selectedConfiguration?.id == configuration.id {
            selectedConfiguration = configurations.first
        }
        
        saveConfigurations()
        print("🗑️ 删除SMB配置: \(configuration.displayInfo)")
    }
    
    /// 选择配置
    func selectConfiguration(_ configuration: SMBConfiguration) {
        selectedConfiguration = configuration
        saveConfigurations()
        print("📌 选择SMB配置: \(configuration.displayInfo)")
    }
    
    /// 从发现的服务创建配置
    func createConfigurationFromService(_ service: DiscoveredSMBService, shareName: String = "recordings") -> SMBConfiguration {
        return SMBConfiguration(from: service, shareName: shareName)
    }
    
    /// 创建手动配置
    func createManualConfiguration(
        name: String,
        host: String,
        shareName: String = "recordings",
        username: String? = nil,
        password: String? = nil,
        port: Int = 445
    ) -> SMBConfiguration {
        return SMBConfiguration(
            name: name,
            host: host,
            shareName: shareName,
            username: username,
            password: password,
            port: port
        )
    }
    
    /// 测试配置连接
    func testConfiguration(_ configuration: SMBConfiguration) async -> Bool {
        return await withCheckedContinuation { continuation in
            let connection = NWConnection(
                host: NWEndpoint.Host(configuration.host),
                port: NWEndpoint.Port(integerLiteral: UInt16(configuration.port)),
                using: .tcp
            )
            
            let resumeState = ResumeState()
            
            @Sendable func safeResume(with result: Bool) {
                resumeState.resumeOnce {
                    continuation.resume(returning: result)
                }
            }
            
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    connection.cancel()
                    safeResume(with: true)
                case .failed, .cancelled:
                    safeResume(with: false)
                default:
                    break
                }
            }
            
            connection.start(queue: DispatchQueue.global(qos: .userInitiated))
            
            // 超时机制
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                connection.cancel()
                safeResume(with: false)
            }
        }
    }
    
    /// 获取当前配置或默认配置
    func getCurrentConfiguration() -> SMBConfiguration {
        return selectedConfiguration ?? SMBConfiguration.placeholder
    }
    
    /// 重置为默认配置
    func resetToDefault() {
        configurations = [SMBConfiguration.placeholder]
        selectedConfiguration = SMBConfiguration.placeholder
        saveConfigurations()
        print("🔄 重置为默认SMB配置")
    }
}