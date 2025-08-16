import SwiftUI

struct AddSMBConfigurationView: View {
    @ObservedObject var configurationManager: SMBConfigurationManager
    @ObservedObject var discoveryManager: SMBDiscoveryManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTab: ConfigurationTab = .manual
    @State private var name = ""
    @State private var host = ""
    @State private var shareName = "recordings"
    @State private var username = ""
    @State private var password = ""
    @State private var port = "445"
    @State private var isTestingConnection = false
    @State private var testResult: Bool?
    @State private var showPassword = false
    
    enum ConfigurationTab: String, CaseIterable {
        case manual = "手动配置"
        case discovered = "发现的服务"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 标签页选择
            Picker("配置方式", selection: $selectedTab) {
                ForEach(ConfigurationTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            // 主要内容区域，占据剩余空间
            Group {
                if selectedTab == .manual {
                    ManualConfigurationView(
                        name: $name,
                        host: $host,
                        shareName: $shareName,
                        username: $username,
                        password: $password,
                        port: $port,
                        showPassword: $showPassword,
                        isTestingConnection: $isTestingConnection,
                        testResult: $testResult
                    )
                } else {
                    DiscoveredServicesView(
                        discoveryManager: discoveryManager,
                        configurationManager: configurationManager
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // 底部按钮
            HStack {
                Button("取消") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                if selectedTab == .manual {
                    Button("测试连接") {
                        testConnection()
                    }
                    .buttonStyle(.bordered)
                    .disabled(host.isEmpty || isTestingConnection)
                    
                    Button("添加") {
                        addConfiguration()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(name.isEmpty || host.isEmpty)
                }
            }
            .padding()
        }
        .frame(minWidth: 500, minHeight: 400)
        .navigationTitle("添加SMB服务器")
    }
    
    private func testConnection() {
        guard let portInt = Int(port) else { return }
        
        isTestingConnection = true
        testResult = nil
        
        let testConfig = SMBConfiguration(
            name: name.isEmpty ? "测试配置" : name,
            host: host,
            shareName: shareName,
            username: username.isEmpty ? nil : username,
            password: password.isEmpty ? nil : password,
            port: portInt
        )
        
        Task {
            let result = await configurationManager.testConfiguration(testConfig)
            await MainActor.run {
                testResult = result
                isTestingConnection = false
            }
        }
    }
    
    private func addConfiguration() {
        guard let portInt = Int(port) else { return }
        
        let config = SMBConfiguration(
            name: name,
            host: host,
            shareName: shareName,
            username: username.isEmpty ? nil : username,
            password: password.isEmpty ? nil : password,
            port: portInt
        )
        
        configurationManager.addConfiguration(config)
        dismiss()
    }
}

struct ManualConfigurationView: View {
    @Binding var name: String
    @Binding var host: String
    @Binding var shareName: String
    @Binding var username: String
    @Binding var password: String
    @Binding var port: String
    @Binding var showPassword: Bool
    @Binding var isTestingConnection: Bool
    @Binding var testResult: Bool?
    
    var body: some View {
        Form {
            Section {
                TextField("服务器名称", text: $name)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                TextField("主机地址", text: $host)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disableAutocorrection(true)
                
                HStack {
                    TextField("端口", text: $port)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 80)
                    
                    Text("共享名称")
                    TextField("共享名称", text: $shareName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
            } header: {
                Text("服务器信息")
            } footer: {
                Text("输入SMB服务器的基本连接信息")
            }
            
            Section {
                TextField("用户名 (可选)", text: $username)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disableAutocorrection(true)
                
                HStack {
                    if showPassword {
                        TextField("密码 (可选)", text: $password)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    } else {
                        SecureField("密码 (可选)", text: $password)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    Button {
                        showPassword.toggle()
                    } label: {
                        Image(systemName: showPassword ? "eye.slash" : "eye")
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("认证信息")
            } footer: {
                Text("如果服务器需要认证，请输入用户名和密码")
            }
            
            // 连接测试结果
            if isTestingConnection {
                Section {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("正在测试连接...")
                    }
                }
            } else if let result = testResult {
                Section {
                    HStack {
                        Image(systemName: result ? "checkmark.circle" : "xmark.circle")
                            .foregroundColor(result ? .green : .red)
                        Text(result ? "连接成功" : "连接失败")
                            .foregroundColor(result ? .green : .red)
                    }
                }
            }
        }
    }
}

struct DiscoveredServicesView: View {
    @ObservedObject var discoveryManager: SMBDiscoveryManager
    @ObservedObject var configurationManager: SMBConfigurationManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack {
            if discoveryManager.discoveredServices.isEmpty && !discoveryManager.isDiscovering {
                VStack(spacing: 16) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    
                    Text("未发现SMB服务")
                        .font(.headline)
                    
                    Text("点击下方按钮扫描网络中的SMB服务器")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("开始扫描") {
                        discoveryManager.startDiscovery()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    if discoveryManager.isDiscovering {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("正在扫描网络...")
                        }
                        .padding()
                    }
                    
                    ForEach(discoveryManager.discoveredServices, id: \.id) { service in
                        DiscoveredServiceRow(
                            service: service,
                            configurationManager: configurationManager,
                            onAdd: {
                                dismiss()
                            }
                        )
                    }
                }
                
                HStack {
                    Button("重新扫描") {
                        discoveryManager.startDiscovery()
                    }
                    .buttonStyle(.bordered)
                    .disabled(discoveryManager.isDiscovering)
                    
                    Spacer()
                    
                    Button("手动添加") {
                        // 切换到手动配置模式的逻辑
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            }
        }
    }
}

struct DiscoveredServiceRow: View {
    let service: DiscoveredSMBService
    @ObservedObject var configurationManager: SMBConfigurationManager
    let onAdd: () -> Void
    
    @State private var shareName = "recordings"
    @State private var showingDetails = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text(service.displayName)
                        .font(.headline)
                    Text("\(service.host):\(service.port)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("添加") {
                    let config = configurationManager.createConfigurationFromService(
                        service,
                        shareName: shareName
                    )
                    configurationManager.addConfiguration(config)
                    onAdd()
                }
                .buttonStyle(.borderedProminent)
            }
            
            if showingDetails {
                VStack(alignment: .leading, spacing: 4) {
                    TextField("共享名称", text: $shareName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Text("发现时间: \(service.discoveredAt, style: .relative)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if !service.addresses.isEmpty {
                        Text("地址: \(service.addresses.joined(separator: ", "))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Button(showingDetails ? "收起" : "展开") {
                withAnimation {
                    showingDetails.toggle()
                }
            }
            .font(.caption)
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
    }
}