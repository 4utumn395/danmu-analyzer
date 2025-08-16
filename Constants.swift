import Foundation

// MARK: - Application Constants

enum AppConstants {
    // MARK: - UI Constants

    enum UI {
        static let minWindowWidth: CGFloat = 900
        static let minWindowHeight: CGFloat = 700
        static let chartHeight: CGFloat = 160
        static let sidebarWidth: CGFloat = 250
        static let padding: CGFloat = 20
        static let cornerRadius: CGFloat = 10
    }

    // MARK: - Analysis Constants

    enum Analysis {
        static let defaultWindowSize: Double = 30.0
        static let minWindowSize: Double = 10.0
        static let maxWindowSize: Double = 120.0
        static let windowSizeStep: Double = 5.0

        static let defaultStepSize: Double = 5.0
        static let minStepSize: Double = 1.0
        static let maxStepSize: Double = 30.0
        static let stepSizeStep: Double = 1.0

        static let defaultMinThreshold: Int = 3
        static let minThreshold: Int = 1
        static let maxThreshold: Int = 20

        static let maxPeaksToDisplay: Int = 50
        static let defaultPeaksToShow: Int = 5
        static let maxTopPeaks: Int = 10

        static let densityMultiplier: Double = 1.5
        static let minDensityForPeak: Int = 2

        // 流边界时间（凌晨4点）
        static let streamBoundaryHour: Int = 4
    }

    // MARK: - File Constants

    enum Files {
        static let danmuFileName = "danmu.txt"
        static let defaultEncoding = String.Encoding.utf8
        static let bufferSize = 8192
        static let maxFileSize: Int64 = 100 * 1024 * 1024 // 100MB

        // 支持的编码格式
        static let supportedEncodings: [String.Encoding] = [
            .utf8, .utf16LittleEndian, .utf16BigEndian,
            .utf32LittleEndian, .utf32BigEndian, .ascii,
        ]

        // 中文编码格式
        static let chineseEncodings: [CFStringEncodings] = [
            .GB_18030_2000, .GBK_95,
        ]
    }

    // MARK: - Performance Constants

    enum Performance {
        static let batchSize = 1000
        static let maxConcurrentTasks = ProcessInfo.processInfo.activeProcessorCount
        static let memoryWarningThreshold: Double = 0.8 // 80%
        static let timeoutInterval: TimeInterval = 30.0

        // 重试配置
        static let maxRetryAttempts = 3
        static let baseRetryDelay: TimeInterval = 1.0
        static let maxRetryDelay: TimeInterval = 10.0
        static let retryBackoffMultiplier: Double = 2.0

        // 断路器配置
        static let circuitBreakerFailureThreshold = 5
        static let circuitBreakerResetTimeout: TimeInterval = 60.0
    }

    // MARK: - Format Constants

    enum Formats {
        static let timestampFormat = "MM-dd HH:mm"
        static let localTimeFormat = "MM-dd HH:mm:ss"
        static let dateFormat = "yyyy-MM-dd"
        static let displayDateFormat = "MM月dd日"

        // 时间格式化
        static let hourMinuteSecondFormat = "%02d:%02d:%02d"
        static let minuteSecondFormat = "%02d:%02d"
        static let dayKeyFormat = "%04d-%02d-%02d"
    }

    // MARK: - Chart Constants

    enum Chart {
        static let minTickInterval: Double = 10.0
        static let tickDivisor: Double = 6.0
        static let strokeWidth: CGFloat = 2.0
        static let pointRadius: CGFloat = 4.0
    }

    // MARK: - Debug Constants

    enum Debug {
        static let maxLogEntries = 1000
        static let logFlushInterval: TimeInterval = 5.0

        // 调试消息前缀
        static let errorPrefix = "❌"
        static let warningPrefix = "⚠️"
        static let infoPrefix = "ℹ️"
        static let successPrefix = "✅"
        static let peakPrefix = "⭐"
        static let densityPrefix = "📍"
        static let ideaPrefix = "💡"
        static let targetPrefix = "🎯"
        static let chartPrefix = "📊"
        static let searchPrefix = "🔍"
        static let folderPrefix = "📁"
        static let rocketPrefix = "🚀"
        static let calendarPrefix = "🗓️"
        static let homePrefix = "🏠"
        static let partyPrefix = "🎉"
        static let clockPrefix = "🕐"
    }
}

// MARK: - Application Configuration

struct AppConfiguration {
    let analysisParameters: AnalysisParameters
    let performanceSettings: PerformanceSettings
    let uiSettings: UISettings

    static let `default` = AppConfiguration(
        analysisParameters: .default,
        performanceSettings: .default,
        uiSettings: .default
    )
}

struct PerformanceSettings {
    let enableConcurrentProcessing: Bool
    let maxConcurrentTasks: Int
    let enableMemoryOptimization: Bool
    let enableCircuitBreaker: Bool

    static let `default` = PerformanceSettings(
        enableConcurrentProcessing: true,
        maxConcurrentTasks: AppConstants.Performance.maxConcurrentTasks,
        enableMemoryOptimization: true,
        enableCircuitBreaker: true
    )
}

struct UISettings {
    let enableAnimations: Bool
    let compactMode: Bool
    let showDetailedTimestamps: Bool

    static let `default` = UISettings(
        enableAnimations: true,
        compactMode: false,
        showDetailedTimestamps: true
    )
}

// MARK: - Version Information

enum AppVersion {
    static let current = "2.0.0"
    static let buildNumber = "1"
    static let releaseDate = "2024-12-19"

    static var fullVersion: String {
        return "\(current) (\(buildNumber))"
    }

    static var displayName: String {
        return "直播弹幕峰值分析器"
    }

    static var description: String {
        return "分析B站直播录播的弹幕分布模式"
    }
}
