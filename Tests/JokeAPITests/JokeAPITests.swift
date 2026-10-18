//
//  JokeAPITests.swift
//
//  Created by Andreas Wörner on 18.10.26.
//

import JokeAPI
import XCTest

@available(iOS 15.0, macOS 12.0, *)
final class JokeAPITests: XCTestCase {
    
    let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }()

    func testLoad_single() async throws {
        let rawData = """
        {
            "error": false,
            "category": "Misc",
            "type": "single",
            "joke": "A neutron walks into a bar and asks for a price on a drink. The barkeeper says: 'For you... no charge!'",
            "flags": {
                "nsfw": false,
                "religious": false,
                "political": false,
                "racist": false,
                "sexist": false,
                "explicit": false
            },
            "id": 72,
            "safe": true,
            "lang": "en"
        }
        """.data(using: .utf8)!
        
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!,
                                           statusCode: 200,
                                           httpVersion: nil,
                                           headerFields: nil)!
            return (response, rawData)
        }
        
        let jokeApi = JokeAPI(urlSession: session)
        
        let joke = try await jokeApi.loadJoke()
        
        XCTAssertEqual(joke.id, 72)
        XCTAssertEqual(joke.category, "Misc")
        XCTAssertEqual(joke.content, .single("A neutron walks into a bar and asks for a price on a drink. The barkeeper says: 'For you... no charge!'"))
    }

    func testLoad_twoPart() async throws {
        let rawData = """
        {
            "error": false,
            "category": "Pun",
            "type": "twopart",
            "setup": "What do you call a witch at the beach?",
            "delivery": "A Sandwich.",
            "flags": {
                "nsfw": false,
                "religious": false,
                "political": false,
                "racist": false,
                "sexist": false,
                "explicit": false
            },
            "id": 175,
            "safe": true,
            "lang": "en"
        }        
        """.data(using: .utf8)!
        
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!,
                                           statusCode: 200,
                                           httpVersion: nil,
                                           headerFields: nil)!
            return (response, rawData)
        }
        
        let jokeApi = JokeAPI(urlSession: session)
        
        let joke = try await jokeApi.loadJoke()
        
        XCTAssertEqual(joke.id, 175)
        XCTAssertEqual(joke.category, "Pun")
        XCTAssertEqual(joke.content, .twoPart(setup: "What do you call a witch at the beach?",
                                              delivery: "A Sandwich."))
    }
    
    func testLoad_error() async throws {
        let rawData = """
        {
            "error": true,
            "internalError": false,
            "code": 106,
            "message": "No matching joke found",
            "causedBy": [
                "No jokes were found that match your provided filter(s)"
            ],
            "additionalInfo": "The specified category is invalid.",
            "timestamp": 1579170794412
        }
        """.data(using: .utf8)!

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 400,
                httpVersion: nil,
                headerFields: nil
            )!

            return (response, rawData)
        }

        let jokeApi = JokeAPI(urlSession: session)

        do {
            _ = try await jokeApi.loadJoke()
            XCTFail("Expected JokeAPI error")
        } catch {
            guard case .api(let apiError) = error else {
                return XCTFail("Expected .api, got \(error)")
            }

            XCTAssertEqual(apiError.code, 106)
            XCTAssertEqual(apiError.message, "No matching joke found")
            XCTAssertFalse(apiError.internalError)
            XCTAssertEqual(apiError.causedBy, ["No jokes were found that match your provided filter(s)"])
            XCTAssertEqual(apiError.additionalInfo, "The specified category is invalid.")
            XCTAssertEqual(apiError.timestamp, 1579170794412)
        }
    }
}

final class MockURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool {
        true
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }
    
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    
    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            XCTFail("No request handler provided")
            return
        }
        
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            
        }
    }
    
    override func stopLoading() {
        
    }
}
