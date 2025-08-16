import CoreFoundation
import Foundation

// MARK: - Time Formatting Utilities

enum TimeFormatter {
    static func formatTime(_ seconds: Double) -> String {
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60

        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%02d:%02d", minutes, secs)
        }
    }

    static func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter.string(from: date)
    }

    static func formatLocal(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }

    static func formatDuration(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d小时%d分钟", hours, minutes)
        } else if minutes > 0 {
            return String(format: "%d分钟%d秒", minutes, secs)
        } else {
            return String(format: "%d秒", secs)
        }
    }
}

// MARK: - File Reading Utilities

enum FileDecoder {
    /// 多编码尝试解码文本（UTF-8/UTF-16/UTF-32/ASCII/GB18030/GBK）
    static func decodeText(data: Data) -> String? {
        let standardEncodings: [String.Encoding] = [
            .utf8, .utf16LittleEndian, .utf16BigEndian,
            .utf32LittleEndian, .utf32BigEndian, .ascii,
        ]

        // 首先尝试标准编码
        for encoding in standardEncodings {
            if let string = String(data: data, encoding: encoding) {
                return string
            }
        }

        // 然后尝试中文编码
        let cfEncodings: [CFStringEncodings] = [.GB_18030_2000, .GBK_95]
        for cfEncoding in cfEncodings {
            let nsEncoding = CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(cfEncoding.rawValue))
            let encoding = String.Encoding(rawValue: nsEncoding)
            if let string = String(data: data, encoding: encoding) {
                return string
            }
        }

        return nil
    }

    static func readTextFile(at path: String) throws -> String {
        let url = URL(fileURLWithPath: (path as NSString).standardizingPath)

        guard FileManager.default.fileExists(atPath: url.path) else {
            throw AnalysisError.fileNotFound(url.path)
        }

        let data = try Data(contentsOf: url)

        if let text = decodeText(data: data) {
            return text
        } else {
            // 最后兜底按 UTF-8 解读（可能出现替换字符）
            return String(decoding: data, as: UTF8.self)
        }
    }
}

// MARK: - Date Utilities

enum DateUtils {
    /// 根据时间戳和录播分界规则（凌晨4点）计算所属日期
    static func calculateStreamingDate(from timestamp: Double) -> String {
        let date = Date(timeIntervalSince1970: timestamp / 1000.0)
        let calendar = Calendar.current
        var dateComponents = calendar.dateComponents([.year, .month, .day, .hour], from: date)

        // 如果是凌晨0-4点，算作前一天
        if let hour = dateComponents.hour, hour < 4 {
            let previousDay = calendar.date(byAdding: .day, value: -1, to: date) ?? date
            dateComponents = calendar.dateComponents([.year, .month, .day], from: previousDay)
        }

        return String(
            format: "%04d-%02d-%02d",
            dateComponents.year ?? 0,
            dateComponents.month ?? 0,
            dateComponents.day ?? 0
        )
    }

    static func displayDate(from dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let date = formatter.date(from: dateString) ?? Date()

        formatter.dateFormat = "MM月dd日"
        return formatter.string(from: date)
    }
}

// MARK: - Debug Logging

actor DebugLogger {
    private var logs: [String] = []

    func log(_ message: String) {
        logs.append(message)
    }

    func getLogs() -> [String] {
        return logs
    }

    func clearLogs() {
        logs.removeAll()
    }
}
