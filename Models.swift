import Foundation

// MARK: - Data Models

struct Platform: Hashable {
    let name: String
    let path: String
    let rooms: [Room]
}

struct Room: Hashable {
    let id: String
    let path: String
    let dayGroups: [DayGroup]
}

struct DayGroup: Hashable {
    let date: String // YYYY-MM-DD 格式
    let displayDate: String
    let recordings: [Recording]
}

struct Recording: Hashable {
    let timestamp: String
    let path: String
    let displayTime: String
    let hasValidDanmu: Bool
}

// MARK: - Analysis Models

struct DanmuEntry {
    let timestamp: Double
    let content: String
}

struct Peak: Identifiable {
    var id: String { String(format: "%.3f-%.3f", startTime, endTime) }
    let startTime: Double
    let endTime: Double
    let count: Int
}

struct DensityPoint: Hashable {
    let time: Double
    let count: Int
}

struct AnalysisParameters {
    let windowSize: Double
    let stepSize: Double
    let minThreshold: Int
    let debugMode: Bool

    static let `default` = AnalysisParameters(
        windowSize: AppConstants.Analysis.defaultWindowSize,
        stepSize: AppConstants.Analysis.defaultStepSize,
        minThreshold: AppConstants.Analysis.defaultMinThreshold,
        debugMode: false
    )

    /// 验证参数的有效性
    var isValid: Bool {
        return windowSize >= AppConstants.Analysis.minWindowSize &&
            windowSize <= AppConstants.Analysis.maxWindowSize &&
            stepSize >= AppConstants.Analysis.minStepSize &&
            stepSize <= AppConstants.Analysis.maxStepSize &&
            minThreshold >= AppConstants.Analysis.minThreshold &&
            minThreshold <= AppConstants.Analysis.maxThreshold
    }

    /// 创建验证过的参数
    static func validated(
        windowSize: Double,
        stepSize: Double,
        minThreshold: Int,
        debugMode: Bool = false
    ) -> AnalysisParameters {
        let validatedWindowSize = max(
            AppConstants.Analysis.minWindowSize,
            min(AppConstants.Analysis.maxWindowSize, windowSize)
        )
        let validatedStepSize = max(
            AppConstants.Analysis.minStepSize,
            min(AppConstants.Analysis.maxStepSize, stepSize)
        )
        let validatedThreshold = max(
            AppConstants.Analysis.minThreshold,
            min(AppConstants.Analysis.maxThreshold, minThreshold)
        )

        return AnalysisParameters(
            windowSize: validatedWindowSize,
            stepSize: validatedStepSize,
            minThreshold: validatedThreshold,
            debugMode: debugMode
        )
    }
}

struct AnalysisResult {
    let title: String
    let subtitle: String?
    let totalDanmu: Int
    let peaks: [Peak]
    let debugInfo: DebugInfo?
    let recordingInfo: RecordingInfo?
    let densitySeries: [DensityPoint]
    let filePath: String?
}

struct RecordingInfo {
    let startTime: Date
    let duration: TimeInterval
    let recordingCount: Int
}

struct DebugInfo {
    let windowSize: Double
    let stepSize: Double
    let threshold: Int
    let minTime: Double
    let maxTime: Double
    let densityCount: Int
    let avgDensity: Double
    let baseEpochSeconds: Double?
}

// MARK: - Enums

enum AnalysisMode: String, CaseIterable {
    case singleRecording = "单条录制"
    case singleDay = "单天汇总"
    case roomOverview = "直播间总览"

    var description: String {
        return rawValue
    }
}

enum AnalysisError: Error, LocalizedError {
    case noRecordingSelected
    case noDaySelected
    case noRoomSelected
    case invalidDirectoryStructure
    case noDanmuFiles
    case invalidFileFormat(String)
    case fileNotFound(String)

    var errorDescription: String? {
        switch self {
        case .noRecordingSelected:
            return "请选择要分析的录制"
        case .noDaySelected:
            return "请选择要分析的日期"
        case .noRoomSelected:
            return "请选择要分析的直播间"
        case .invalidDirectoryStructure:
            return "目录结构不符合预期"
        case .noDanmuFiles:
            return "未找到有效的弹幕文件"
        case let .invalidFileFormat(file):
            return "文件格式无效: \(file)"
        case let .fileNotFound(file):
            return "文件不存在: \(file)"
        }
    }
}
