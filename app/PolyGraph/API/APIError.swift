import Foundation

/// Erorile clientului, cu mesaje în română care se pot afișa direct.
nonisolated enum APIError: LocalizedError {
    case invalidBaseURL
    case missingToken
    case invalidResponse
    case network(URLError)
    case http(status: Int, detail: String?)
    case decoding(String)

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            return "Adresa serverului nu e validă. Verificați-o în Setări."
        case .missingToken:
            return "Telefonul nu e încă asociat cu un pacient."
        case .invalidResponse:
            return "Serverul a trimis un răspuns neașteptat."
        case .network(let error):
            switch error.code {
            case .timedOut:
                return "Serverul răspunde greu. Încercați din nou peste câteva secunde."
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
                return "Telefonul nu e conectat la rețea."
            case .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed:
                return "Nu pot ajunge la server. Verificați adresa din Setări și că telefonul e în aceeași rețea Wi-Fi."
            case .cancelled:
                return "Cererea a fost anulată."
            default:
                return "Nu pot ajunge la server (cod \(error.code.rawValue))."
            }
        case .http(let status, let detail):
            if let detail, !detail.isEmpty { return detail }
            switch status {
            case 401: return "Telefonul nu mai are acces la acest pacient. Asociați-l din nou din Setări."
            case 404: return "Nu am găsit ce ați cerut pe server."
            case 422: return "Serverul nu a acceptat datele trimise."
            case 500...: return "Serverul are o problemă. Încercați din nou."
            default: return "Serverul a răspuns cu eroarea \(status)."
            }
        case .decoding:
            return "Nu am înțeles răspunsul serverului. Poate aplicația și serverul au versiuni diferite."
        }
    }

    /// FastAPI trimite `{"detail": "..."}` pentru erorile noastre și `{"detail": [{"msg": ...}]}` la validare.
    static func detail(from data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        if let text = object["detail"] as? String { return text }
        if let items = object["detail"] as? [[String: Any]] {
            let messages = items.compactMap { $0["msg"] as? String }
            return messages.isEmpty ? nil : messages.joined(separator: "; ")
        }
        return nil
    }
}
