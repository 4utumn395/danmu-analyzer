import Foundation

// MARK: - Enhanced Error Handling

protocol ErrorReporting {
    func reportError(_ error: Error, context: String)
    func reportWarning(_ message: String, context: String)
    func reportInfo(_ message: String, context: String)
}

class ErrorReporter: ErrorReporting {
    private let isDebugMode: Bool
    private let callback: ((String) async -> Void)?

    init(debugMode: Bool = false, callback: ((String) async -> Void)? = nil) {
        isDebugMode = debugMode
        self.callback = callback
    }

    func reportError(_ error: Error, context: String) {
        let message = "❌ \(context): \(error.localizedDescription)"
        Task {
            await callback?(message)
        }
        print(message)
    }

    func reportWarning(_ message: String, context: String) {
        let warningMessage = "⚠️ \(context): \(message)"
        if isDebugMode {
            Task {
                await callback?(warningMessage)
            }
        }
        print(warningMessage)
    }

    func reportInfo(_ message: String, context: String) {
        let infoMessage = "ℹ️ \(context): \(message)"
        if isDebugMode {
            Task {
                await callback?(infoMessage)
            }
        }
        print(infoMessage)
    }
}

// MARK: - Result Types for Better Error Handling

enum ProcessingResult<Success> {
    case success(Success)
    case failure(AnalysisError)
    case partial(Success, [AnalysisError])

    var isSuccess: Bool {
        switch self {
        case .success: return true
        case .failure: return false
        case .partial: return true
        }
    }

    var value: Success? {
        switch self {
        case let .success(value), let .partial(value, _):
            return value
        case .failure:
            return nil
        }
    }

    var errors: [AnalysisError] {
        switch self {
        case .success:
            return []
        case let .failure(error):
            return [error]
        case let .partial(_, errors):
            return errors
        }
    }
}

// MARK: - Enhanced Error Types

extension AnalysisError {
    static func corruptedFile(_ path: String, reason: String) -> AnalysisError {
        return .invalidFileFormat("文件损坏: \(path) - \(reason)")
    }

    static func memoryPressure() -> AnalysisError {
        return .invalidFileFormat("内存不足，无法继续处理")
    }

    static func timeout(_ operation: String) -> AnalysisError {
        return .invalidFileFormat("操作超时: \(operation)")
    }

    var severity: ErrorSeverity {
        switch self {
        case .noRecordingSelected, .noDaySelected, .noRoomSelected:
            return .warning
        case .invalidDirectoryStructure, .noDanmuFiles:
            return .error
        case .invalidFileFormat, .fileNotFound:
            return .critical
        }
    }

    var recoveryAction: String {
        switch self {
        case .noRecordingSelected:
            return "请选择要分析的录制文件"
        case .noDaySelected:
            return "请选择要分析的日期"
        case .noRoomSelected:
            return "请选择要分析的直播间"
        case .invalidDirectoryStructure:
            return "请检查目录结构是否正确"
        case .noDanmuFiles:
            return "请确保目录中包含有效的弹幕文件"
        case .invalidFileFormat:
            return "请检查文件格式是否正确"
        case .fileNotFound:
            return "请确保文件路径正确"
        }
    }
}

enum ErrorSeverity {
    case info
    case warning
    case error
    case critical

    var emoji: String {
        switch self {
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        case .critical: return "🚨"
        }
    }
}

// MARK: - Retry Mechanism

struct RetryConfiguration {
    let maxAttempts: Int
    let baseDelay: TimeInterval
    let maxDelay: TimeInterval
    let backoffMultiplier: Double

    static let `default` = RetryConfiguration(
        maxAttempts: 3,
        baseDelay: 1.0,
        maxDelay: 10.0,
        backoffMultiplier: 2.0
    )
}

class RetryableOperation {
    private let config: RetryConfiguration
    private let errorReporter: ErrorReporting

    init(config: RetryConfiguration = .default, errorReporter: ErrorReporting) {
        self.config = config
        self.errorReporter = errorReporter
    }

    func execute<T>(
        operation: @escaping () async throws -> T,
        context: String
    ) async throws -> T {
        var lastError: Error?
        var currentDelay = config.baseDelay

        for attempt in 1 ... config.maxAttempts {
            do {
                let result = try await operation()
                if attempt > 1 {
                    errorReporter.reportInfo("重试成功", context: "\(context) (第\(attempt)次尝试)")
                }
                return result
            } catch {
                lastError = error

                if attempt < config.maxAttempts {
                    errorReporter.reportWarning(
                        "第\(attempt)次尝试失败，\(currentDelay)秒后重试: \(error.localizedDescription)",
                        context: context
                    )

                    try await Task.sleep(nanoseconds: UInt64(currentDelay * 1_000_000_000))
                    currentDelay = min(currentDelay * config.backoffMultiplier, config.maxDelay)
                } else {
                    errorReporter.reportError(error, context: "\(context) (重试\(config.maxAttempts)次后仍失败)")
                }
            }
        }

        throw lastError ?? AnalysisError.invalidFileFormat("未知错误")
    }
}

// MARK: - Circuit Breaker Pattern

actor CircuitBreaker {
    enum State {
        case closed
        case open
        case halfOpen
    }

    private var state: State = .closed
    private var failureCount = 0
    private var lastFailureTime: Date?
    private let failureThreshold: Int
    private let resetTimeout: TimeInterval

    init(failureThreshold: Int = 5, resetTimeout: TimeInterval = 60) {
        self.failureThreshold = failureThreshold
        self.resetTimeout = resetTimeout
    }

    func execute<T>(operation: () async throws -> T) async throws -> T {
        switch state {
        case .open:
            if
                let lastFailure = lastFailureTime,
                Date().timeIntervalSince(lastFailure) > resetTimeout
            {
                state = .halfOpen
                return try await attemptOperation(operation)
            } else {
                throw AnalysisError.invalidFileFormat("服务暂时不可用，请稍后重试")
            }

        case .halfOpen:
            return try await attemptOperation(operation)

        case .closed:
            return try await attemptOperation(operation)
        }
    }

    private func attemptOperation<T>(_ operation: () async throws -> T) async throws -> T {
        do {
            let result = try await operation()
            onSuccess()
            return result
        } catch {
            onFailure()
            throw error
        }
    }

    private func onSuccess() {
        failureCount = 0
        state = .closed
    }

    private func onFailure() {
        failureCount += 1
        lastFailureTime = Date()

        if failureCount >= failureThreshold {
            state = .open
        }
    }
}
