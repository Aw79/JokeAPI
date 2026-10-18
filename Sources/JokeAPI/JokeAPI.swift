//
//  JokeAPI.swift
//
//  Created by Andreas Wörner on 18.10.26.
//

import Foundation

@available(iOS 15.0, macOS 12.0, *)
public final class JokeAPI: Sendable {
    private let url = URL(string: "https://v2.jokeapi.dev/joke/Any?blacklistFlags=nsfw,religious,racist,sexist,explicit")!
    private let urlSession: URLSession
    private let decoder: JSONDecoder
    
    public init(urlSession: URLSession = .shared,
                decoder: JSONDecoder = JSONDecoder()) {
        self.urlSession = urlSession
        self.decoder = decoder
    }
    
    public func loadJoke() async throws(JokeError) -> Joke {
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await urlSession.data(from: url)
        } catch {
            throw .underlying(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw .underlying(URLError(.badServerResponse))
        }

        // Check JokeAPI's own error payload first.
        if let apiError = try? JSONDecoder().decode(
            JokeAPIError.self,
            from: data
        ), apiError.error {
            throw .api(apiError)
        }

        // Handle HTTP errors without a decodable JokeAPI error payload.
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw .httpStatus(httpResponse.statusCode)
        }

        do {
            return try JSONDecoder().decode(Joke.self, from: data)
        } catch {
            throw .underlying(error)
        }
    }
}

public struct JokeAPIError: Decodable, Equatable, Sendable {
    public let error: Bool
    public let internalError: Bool
    public let code: Int
    public let message: String
    public let causedBy: [String]
    public let additionalInfo: String?
    public let timestamp: Int64
}

public enum JokeError: Error, CustomDebugStringConvertible {
    case api(JokeAPIError)
    case httpStatus(Int)
    case underlying(Error)

    public var debugDescription: String {
        switch self {
        case .api(let error):
            return """
            JokeAPI error \(error.code): \(error.message)
            Causes: \(error.causedBy.joined(separator: ", "))
            Additional info: \(error.additionalInfo ?? "none")
            """
        case .httpStatus(let statusCode):
            return "HTTP error: \(statusCode)"
        case .underlying(let error):
            return String(describing: error)
        }
    }
}

public struct Joke: Decodable, Identifiable, Equatable, Sendable {
    let error: Bool
    public let category: String
    public let content: Content
    let flags: [String: Bool]
    public let id: Int
    let safe: Bool
    let lang: String

    public enum Content: Equatable, Sendable {
        case single(String)
        case twoPart(setup: String, delivery: String)
    }

    private enum CodingKeys: String, CodingKey {
        case error
        case category
        case type
        case joke
        case setup
        case delivery
        case flags
        case id
        case safe
        case lang
    }

    private enum JokeType: String, Decodable {
        case single
        case twopart
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        error = try container.decode(Bool.self, forKey: .error)
        category = try container.decode(String.self, forKey: .category)
        flags = try container.decode([String: Bool].self, forKey: .flags)
        id = try container.decode(Int.self, forKey: .id)
        safe = try container.decode(Bool.self, forKey: .safe)
        lang = try container.decode(String.self, forKey: .lang)

        let type = try container.decode(JokeType.self, forKey: .type)
        switch type {
        case .single:
            let joke = try container.decode(String.self, forKey: .joke)
            content = .single(joke)

        case .twopart:
            let setup = try container.decode(String.self, forKey: .setup)
            let delivery = try container.decode(String.self, forKey: .delivery)
            content = .twoPart(setup: setup, delivery: delivery)
        }
    }
}

