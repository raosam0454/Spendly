import Foundation

enum CurrencyError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case apiError(String)
    case missingAPIKey

    var errorDescription: String? {
        switch self {
        case .invalidURL:       return "Invalid API URL."
        case .networkError(let e): return "Network error: \(e.localizedDescription)"
        case .invalidResponse:  return "Received an invalid response from the exchange rate server."
        case .apiError(let msg): return "API error: \(msg)"
        case .missingAPIKey:    return "Exchange rate API key not configured. Add your key to Config.plist."
        }
    }
}

struct ExchangeRateResponse: Codable {
    let result: String
    let conversionRates: [String: Double]
    let errorType: String?

    enum CodingKeys: String, CodingKey {
        case result
        case conversionRates = "conversion_rates"
        case errorType = "error-type"
    }
}

struct CurrencyRate: Identifiable, Equatable {
    let id = UUID()
    let code: String
    let rate: Double
}

final class CurrencyService {
    static let shared = CurrencyService()
    private init() {}

    private var cachedRates: [String: Double] = [:]
    private var cacheDate: Date?
    private let cacheValiditySeconds: TimeInterval = 3600

    private var apiKey: String {
        guard let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path),
              let key = dict["ExchangeRateAPIKey"] as? String,
              !key.isEmpty else {
            return ""
        }
        return key
    }

    func fetchRates(base: String = "AUD") async throws -> [CurrencyRate] {
        // return cache if its still fresh
        if let cached = cacheDate,
           Date().timeIntervalSince(cached) < cacheValiditySeconds,
           !cachedRates.isEmpty {
            return cachedRates.map { CurrencyRate(code: $0.key, rate: $0.value) }
                .sorted { $0.code < $1.code }
        }

        guard !apiKey.isEmpty else { throw CurrencyError.missingAPIKey }

        let urlString = "https://v6.exchangerate-api.com/v6/\(apiKey)/latest/\(base)"
        guard let url = URL(string: urlString) else { throw CurrencyError.invalidURL }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(from: url)
        } catch {
            throw CurrencyError.networkError(error)
        }

        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw CurrencyError.invalidResponse
        }

        let decoded: ExchangeRateResponse
        do {
            decoded = try JSONDecoder().decode(ExchangeRateResponse.self, from: data)
        } catch {
            throw CurrencyError.invalidResponse
        }

        if decoded.result != "success" {
            throw CurrencyError.apiError(decoded.errorType ?? "Unknown error")
        }

        cachedRates = decoded.conversionRates
        cacheDate = Date()
        return cachedRates.map { CurrencyRate(code: $0.key, rate: $0.value) }
            .sorted { $0.code < $1.code }
    }

    func convert(amount: Double, from: String, to: String) async throws -> Double {
        let rates = try await fetchRates()
        guard let fromRate = rates.first(where: { $0.code == from })?.rate,
              let toRate = rates.first(where: { $0.code == to })?.rate else {
            throw CurrencyError.invalidResponse
        }
        let inAUD = amount / fromRate
        return inAUD * toRate
    }
}
