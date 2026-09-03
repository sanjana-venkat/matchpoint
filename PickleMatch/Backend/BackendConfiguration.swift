import Foundation
import Supabase

enum BackendConfigurationError: LocalizedError {
    case missingValue(String)
    case invalidURL(String)

    var errorDescription: String? {
        switch self {
        case .missingValue(let key): "Missing backend configuration value: \(key)"
        case .invalidURL(let value): "Invalid Supabase project URL: \(value)"
        }
    }
}

struct BackendConfiguration: Sendable {
    static let authCallbackURL = URL(string: "com.picklematch.app://auth-callback")!

    let projectURL: URL
    let publishableKey: String

    static func load(bundle: Bundle = .main) throws -> BackendConfiguration {
        let urlValue = try configuredValue(named: "SUPABASE_URL", bundle: bundle)
        let key = try configuredValue(named: "SUPABASE_PUBLISHABLE_KEY", bundle: bundle)
        guard let url = URL(string: urlValue), url.scheme == "https", url.host != nil else {
            throw BackendConfigurationError.invalidURL(urlValue)
        }
        guard key.hasPrefix("sb_publishable_") else {
            throw BackendConfigurationError.missingValue("SUPABASE_PUBLISHABLE_KEY")
        }
        return BackendConfiguration(projectURL: url, publishableKey: key)
    }

    private static func configuredValue(named key: String, bundle: Bundle) throws -> String {
        let value = (bundle.object(forInfoDictionaryKey: key) as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value, !value.isEmpty, !value.contains("$(") else {
            throw BackendConfigurationError.missingValue(key)
        }
        return value
    }
}

final class BackendDependencies: @unchecked Sendable {
    static let shared = BackendDependencies()

    let configuration: BackendConfiguration?
    let configurationError: Error?
    let client: SupabaseClient?
    let profiles: ProfileRepository?
    let production: ProductionRepository?

    private init() {
        do {
            let configuration = try BackendConfiguration.load()
            let client = SupabaseClient(
                supabaseURL: configuration.projectURL,
                supabaseKey: configuration.publishableKey
            )
            self.configuration = configuration
            self.configurationError = nil
            self.client = client
            self.profiles = SupabaseProfileRepository(client: client)
            self.production = SupabaseProductionRepository(client: client)
        } catch {
            self.configuration = nil
            self.configurationError = error
            self.client = nil
            self.profiles = nil
            self.production = nil
        }
    }
}
