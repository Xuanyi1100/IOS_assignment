import Foundation

/// Decides which engine the app uses.
///
/// MockEngine is the default and the only path that needs no download or device, so it is
/// what the instructor's Simulator run uses. The on-device model is opt-in
/// (`AppSettings.engineIndex == 1`) and only compiled in when the LiteRT package is present.
enum EngineResolver {
    static func current() -> InferenceEngine {
        #if canImport(LiteRTFoundation)
        if AppSettings.engineIndex == 1 {
            return LiteRTEngine.shared
        }
        #endif
        return MockEngine()
    }
}
