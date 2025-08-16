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

// MARK: - SMB服务发现管理器

@MainActor
class SMBDiscoveryManager: ObservableObject {
    @Published var discoveryStatus: SMBDiscoveryStatus = .idle
    @Published var discoveredServices: [DiscoveredSMBService] = []
    @Published var isDiscovering = false
    
    private var browser: NWBrowser?
    private let discoveryQueue = DispatchQueue(label: "SMBDiscovery", qos: .userInitiated)
    
    deinit {
        Task { @MainActor [weak self] in
            self?.stopDiscovery()
        }
    }
    
    /// 开始扫描SMB服务
    func startDiscovery() {
        guard !isDiscovering else { return }
        
        print("🔍 开始扫描SMB服务...")
        isDiscovering = true
        discoveryStatus = .discovering
        discoveredServices.removeAll()
        
        // 创建浏览器来扫描SMB服务 (_smb._tcp)
        let parameters = NWParameters()
        parameters.includePeerToPeer = true
        
        browser = NWBrowser(for: .bonjour(type: "_smb._tcp", domain: nil), using: parameters)
        
        browser?.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                self?.handleBrowserState(state)
            }
        }
        
        browser?.browseResultsChangedHandler = { [weak self] results, changes in
            DispatchQueue.main.async {
                self?.handleBrowseResults(results, changes: changes)
            }
        }
        
        browser?.start(queue: discoveryQueue)
        
        // 设置超时
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) { [weak self] in
            self?.completeDiscovery()
        }
    }
    
    /// 停止扫描
    func stopDiscovery() {
        browser?.cancel()
        browser = nil
        isDiscovering = false
    }
    
    /// 完成扫描
    private func completeDiscovery() {
        guard isDiscovering else { return }
        
        stopDiscovery()
        
        print("📡 SMB服务扫描完成，发现 \(discoveredServices.count) 个服务")
        
        if discoveredServices.isEmpty {
            // 尝试扫描本地网络的常见SMB服务
            scanLocalNetwork()
        } else {
            discoveryStatus = .completed(services: discoveredServices)
        }
    }
    
    /// 处理浏览器状态变化
    private func handleBrowserState(_ state: NWBrowser.State) {
        switch state {
        case .ready:
            print("🔍 SMB浏览器就绪")
        case .failed(let error):
            print("❌ SMB浏览器失败: \(error)")
            discoveryStatus = .failed(error)
            isDiscovering = false
        case .cancelled:
            print("⏹️ SMB浏览器已取消")
            isDiscovering = false
        default:
            break
        }
    }
    
    /// 处理浏览结果变化
    private func handleBrowseResults(_ results: Set<NWBrowser.Result>, changes: Set<NWBrowser.Result.Change>) {
        for change in changes {
            switch change {
            case .added(let result):
                addDiscoveredService(from: result)
            case .removed(let result):
                removeDiscoveredService(from: result)
            case .changed(let old, let new, _):
                removeDiscoveredService(from: old)
                addDiscoveredService(from: new)
            case .identical:
                break
            @unknown default:
                break
            }
        }
    }
    
    /// 添加发现的服务
    private func addDiscoveredService(from result: NWBrowser.Result) {
        let serviceName = result.endpoint.debugDescription
        let serviceId = UUID().uuidString
        
        var host = ""
        var port = 445
        var addresses: [String] = []
        
        switch result.endpoint {
        case .service(let name, let type, let domain, _):
            host = "\(name).\(type)\(domain)"
            
            // 尝试解析地址
            resolveEndpoint(result.endpoint) { [weak self] resolvedAddresses in
                DispatchQueue.main.async {
                    if let index = self?.discoveredServices.firstIndex(where: { $0.id == serviceId }) {
                        let _ = self?.discoveredServices[index]
                        // 更新地址信息
                    }
                }
            }
            
        case .hostPort(let hostEndpoint, let portEndpoint):
            host = hostEndpoint.debugDescription
            port = Int(portEndpoint.rawValue)
            addresses = [hostEndpoint.debugDescription]
            
        case .unix:
            return // 不处理Unix socket
            
        case .url:
            return // 不处理URL类型
            
        case .opaque:
            return // 不处理opaque类型
            
        @unknown default:
            return
        }
        
        let service = DiscoveredSMBService(
            id: serviceId,
            name: serviceName,
            host: host,
            port: port,
            addresses: addresses,
            discoveredAt: Date()
        )
        
        // 避免重复添加
        if !discoveredServices.contains(where: { $0.host == service.host && $0.port == service.port }) {
            discoveredServices.append(service)
            print("✅ 发现SMB服务: \(service.displayName) (\(service.host):\(service.port))")
        }
    }
    
    /// 删除发现的服务
    private func removeDiscoveredService(from result: NWBrowser.Result) {
        // 实现服务移除逻辑
        let serviceName = result.endpoint.debugDescription
        discoveredServices.removeAll { $0.name == serviceName }
    }
    
    /// 解析端点地址
    private func resolveEndpoint(_ endpoint: NWEndpoint, completion: @escaping ([String]) -> Void) {
        // 这里可以实现更详细的地址解析
        completion([])
    }
    
    /// 扫描本地网络的常见SMB服务
    private func scanLocalNetwork() {
        print("🔍 扫描本地网络常见SMB服务...")
        
        // 扫描常见的本地服务
        let commonHosts = [
            "router.local",
            "nas.local", 
            "diskstation.local",
            "synology.local",
            "qnap.local",
            "drobo.local"
        ]
        
        Task {
            var foundServices: [DiscoveredSMBService] = []
            
            for host in commonHosts {
                if await checkSMBService(host: host, port: 445) {
                    let service = DiscoveredSMBService(
                        id: UUID().uuidString,
                        name: host,
                        host: host,
                        port: 445,
                        addresses: [host],
                        discoveredAt: Date()
                    )
                    foundServices.append(service)
                }
            }
            
            await MainActor.run {
                discoveredServices.append(contentsOf: foundServices)
                discoveryStatus = .completed(services: discoveredServices)
                
                if foundServices.isEmpty {
                    print("⚠️ 未发现任何SMB服务，用户需要手动配置")
                }
            }
        }
    }
    
    /// 检查SMB服务是否可达
    private func checkSMBService(host: String, port: Int) async -> Bool {
        return await withCheckedContinuation { continuation in
            let connection = NWConnection(
                host: NWEndpoint.Host(host),
                port: NWEndpoint.Port(integerLiteral: UInt16(port)),
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
            
            connection.start(queue: discoveryQueue)
            
            // 超时机制
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                connection.cancel()
                safeResume(with: false)
            }
        }
    }
    
    /// 手动添加SMB服务
    func addManualService(name: String, host: String, port: Int = 445) {
        let service = DiscoveredSMBService(
            id: UUID().uuidString,
            name: name,
            host: host,
            port: port,
            addresses: [host],
            discoveredAt: Date()
        )
        
        // 避免重复添加
        if !discoveredServices.contains(where: { $0.host == service.host && $0.port == service.port }) {
            discoveredServices.append(service)
            print("✅ 手动添加SMB服务: \(service.displayName)")
        }
    }
}