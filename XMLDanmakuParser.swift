import Foundation

// MARK: - XML 弹幕解析器

class XMLDanmakuParser: NSObject {
    private var currentMessages: [DanmakuMessage] = []
    private var currentRecording: RecordingFile?
    private var parsingStartTime: Date = .init()

    // XML 解析状态
    private var currentElement: String = ""
    private var currentAttributes: [String: String] = [:]
    private var currentText: String = ""

    // 录播信息解析
    private var recordingTitle: String = ""
    private var recordingChannel: String = ""
    private var recordingDate: Date = .init()
    private var recordingDuration: TimeInterval = 0

    /// 解析 XML 文件并返回弹幕结果
    func parseXMLFile(at path: String) async throws -> XMLDanmakuResult {
        parsingStartTime = Date()
        currentMessages.removeAll()

        // 首先尝试从文件路径解析录播信息
        parseRecordingInfoFromPath(path)

        // 读取并解析 XML 文件
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        return try await parseXMLData(data, filePath: path)
    }

    /// 解析 XML 数据
    private func parseXMLData(_ data: Data, filePath: String) async throws -> XMLDanmakuResult {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: ParseError.parserNotAvailable)
                    return
                }

                let parser = XMLParser(data: data)
                parser.delegate = self

                if parser.parse() {
                    let recordingFile = self.createRecordingFile(from: filePath)
                    let result = XMLDanmakuResult(
                        recordingFile: recordingFile,
                        messages: self.currentMessages,
                        totalCount: self.currentMessages.count,
                        duration: self.recordingDuration,
                        parseTime: Date()
                    )
                    continuation.resume(returning: result)
                } else {
                    let error = parser.parserError ?? ParseError.invalidXMLFormat
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// 从文件路径解析录播信息
    private func parseRecordingInfoFromPath(_ path: String) {
        let url = URL(fileURLWithPath: path)
        let pathComponents = url.pathComponents

        // 解析路径: .../recordings/channel_name/recording_folder/recording_file.xml
        for (_, component) in pathComponents.enumerated() {
            if component.contains("-"), component.contains("Channel") || component.contains("channel") {
                // 解析频道名称
                if let channelPart = component.split(separator: "-").last {
                    recordingChannel = String(channelPart)
                }
            } else if component.hasPrefix("录制-"), component.contains("-") {
                // 解析录制信息
                parseRecordingComponent(component)
            }
        }

        // 从文件名解析最终信息
        let filename = url.deletingPathExtension().lastPathComponent
        if filename.hasPrefix("录制-") {
            parseRecordingComponent(filename)
        }
    }

    private func parseRecordingComponent(_ component: String) {
        let parts = component.split(separator: "-")

        if parts.count >= 2 {
            // 解析日期: 录制-20250813
            if
                let datePart = parts.dropFirst().first,
                datePart.count == 8,
                let year = Int(datePart.prefix(4)),
                let month = Int(datePart.dropFirst(4).prefix(2)),
                let day = Int(datePart.suffix(2))
            {
                var components = DateComponents()
                components.year = year
                components.month = month
                components.day = day

                if let date = Calendar.current.date(from: components) {
                    recordingDate = date
                }
            }

            // 解析标题（取最后的部分）
            if parts.count > 2 {
                recordingTitle = parts.dropFirst(2).joined(separator: "-")
                // 移除可能的文件扩展名和特殊字符
                recordingTitle = recordingTitle.replacingOccurrences(of: " ！", with: "")
                recordingTitle = recordingTitle.replacingOccurrences(of: ".xml", with: "")
            }
        }
    }

    private func createRecordingFile(from path: String) -> RecordingFile {
        let url = URL(fileURLWithPath: path)
        let id = url.deletingPathExtension().lastPathComponent

        return RecordingFile(
            id: id,
            name: url.lastPathComponent,
            path: path,
            xmlPath: path,
            date: recordingDate,
            channel: recordingChannel.isEmpty ? "未知频道" : recordingChannel,
            title: recordingTitle.isEmpty ? "未知标题" : recordingTitle
        )
    }

    enum ParseError: Error, LocalizedError {
        case invalidXMLFormat
        case parserNotAvailable
        case missingRequiredFields
        case invalidTimestamp
        case invalidDanmakuData

        var errorDescription: String? {
            switch self {
            case .invalidXMLFormat:
                return "XML 格式无效"
            case .parserNotAvailable:
                return "解析器不可用"
            case .missingRequiredFields:
                return "缺少必需字段"
            case .invalidTimestamp:
                return "时间戳格式无效"
            case .invalidDanmakuData:
                return "弹幕数据无效"
            }
        }
    }
}

// MARK: - XMLParserDelegate

extension XMLDanmakuParser: XMLParserDelegate {
    func parser(
        _: XMLParser,
        didStartElement elementName: String,
        namespaceURI _: String?,
        qualifiedName _: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        currentElement = elementName
        currentAttributes = attributeDict
        currentText = ""

        // 解析不同的 XML 元素
        switch elementName.lowercased() {
        case "d": // 弹幕元素
            parseDanmakuElement(attributes: attributeDict)
        case "video", "recording": // 视频/录制信息
            parseVideoInfo(attributes: attributeDict)
        case "chatserver", "server": // 服务器信息
            parseServerInfo(attributes: attributeDict)
        default:
            break
        }
    }

    func parser(_: XMLParser, foundCharacters string: String) {
        currentText += string.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func parser(_: XMLParser, didEndElement elementName: String, namespaceURI _: String?, qualifiedName _: String?) {
        defer {
            currentElement = ""
            currentText = ""
            currentAttributes.removeAll()
        }

        switch elementName.lowercased() {
        case "d": // 弹幕元素结束
            completeDanmakuParsing()
        case "title", "name": // 标题信息
            if !currentText.isEmpty {
                recordingTitle = currentText
            }
        case "duration": // 时长信息
            if let duration = Double(currentText) {
                recordingDuration = duration
            }
        default:
            break
        }
    }

    private func parseDanmakuElement(attributes: [String: String]) {
        // 解析弹幕属性
        // 常见格式: <d p="时间,模式,字号,颜色,时间戳,池,用户ID,行ID">弹幕内容</d>

        guard let pValue = attributes["p"] else { return }
        let components = pValue.split(separator: ",")

        guard components.count >= 5 else { return }

        // 解析弹幕参数
        let timestamp = Double(String(components[0])) ?? 0
        let mode = Int(String(components[1])) ?? 1
        let fontSize = Int(String(components[2])) ?? 12
        let color = String(components[3])
        let absoluteTimestamp = Double(String(components[4])) ?? 0

        let userId = components.count > 6 ? String(components[6]) : nil

        // 确定弹幕位置
        let position: DanmakuMessage.DanmakuPosition
        switch mode {
        case 4: position = .bottom
        case 5: position = .top
        default: position = .scroll
        }

        // 创建弹幕消息（内容将在 didEndElement 中设置）
        let message = DanmakuMessage(
            timestamp: timestamp,
            absoluteTime: Date(timeIntervalSince1970: absoluteTimestamp / 1000.0), // 时间戳是毫秒格式
            userId: userId,
            username: nil, // 通常 XML 中不包含用户名
            content: "", // 将在 completeDanmakuParsing 中设置
            color: color,
            fontSize: fontSize,
            position: position
        )

        // 临时存储，等待内容
        currentMessages.append(message)
    }

    private func completeDanmakuParsing() {
        // 设置最后一条弹幕的内容
        if !currentMessages.isEmpty, !currentText.isEmpty {
            let lastIndex = currentMessages.count - 1
            let lastMessage = currentMessages[lastIndex]

            let updatedMessage = DanmakuMessage(
                timestamp: lastMessage.timestamp,
                absoluteTime: lastMessage.absoluteTime,
                userId: lastMessage.userId,
                username: lastMessage.username,
                content: currentText,
                color: lastMessage.color,
                fontSize: lastMessage.fontSize,
                position: lastMessage.position
            )

            currentMessages[lastIndex] = updatedMessage
        }
    }

    private func parseVideoInfo(attributes: [String: String]) {
        // 解析视频信息
        if let duration = attributes["duration"] {
            recordingDuration = Double(duration) ?? 0
        }

        if let title = attributes["title"] {
            recordingTitle = title
        }

        if let channel = attributes["channel"] {
            recordingChannel = channel
        }
    }

    private func parseServerInfo(attributes _: [String: String]) {
        // 解析服务器信息（如果需要）
        // 可以用于获取弹幕服务器信息
    }

    func parserDidEndDocument(_: XMLParser) {
        // 解析完成，按时间戳排序弹幕
        currentMessages.sort { $0.timestamp < $1.timestamp }
    }

    func parser(_: XMLParser, parseErrorOccurred parseError: Error) {
        print("XML 解析错误: \(parseError.localizedDescription)")
    }
}

// MARK: - 工具扩展

extension XMLDanmakuParser {
    /// 从 XML 文件批量解析弹幕
    static func parseBatchXMLFiles(
        _ paths: [String],
        progressCallback: @escaping (Int, Int) -> Void = { _, _ in }
    ) async throws
        -> [XMLDanmakuResult]
    {
        var results: [XMLDanmakuResult] = []

        for (index, path) in paths.enumerated() {
            progressCallback(index, paths.count)

            do {
                let parser = XMLDanmakuParser()
                let result = try await parser.parseXMLFile(at: path)
                results.append(result)
            } catch {
                print("解析文件失败 \(path): \(error)")
                // 继续处理其他文件
            }
        }

        progressCallback(paths.count, paths.count)
        return results
    }

    /// 验证 XML 文件是否为有效的弹幕文件
    static func validateXMLFile(at path: String) -> Bool {
        guard FileManager.default.fileExists(atPath: path) else { return false }

        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))

            // 简单验证：检查是否包含弹幕相关的 XML 元素
            let content = String(data: data, encoding: .utf8) ?? ""
            return content.contains("<d ") || content.contains("<danmaku") || content.contains("bilibili")
        } catch {
            return false
        }
    }
}
