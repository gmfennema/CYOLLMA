import Foundation
import Testing
@testable import CYOLLMA

struct OllamaParsingTests {
    @Test func turnPayloadDecodesFromNestedJSON() throws {
        let payloadBlob = """
        {"model":"llama3.1","response":"{\\n  \\"narrative\\": \\"You stand at a fork in the path...\\",\\n  \\"options\\": [ { \\"id\\": \\"A\\", \\"label\\": \\"Follow the lantern\\" }, { \\"id\\": \\"B\\", \\"label\\": \\"Take the narrow stairs\\" } ]\\n}"}
        """
        let data = try #require(payloadBlob.data(using: .utf8))

        struct RawResponse: Decodable { let response: String }

        let raw = try JSONDecoder().decode(RawResponse.self, from: data)
        let inner = try #require(raw.response.data(using: .utf8))
        let turn = try JSONDecoder().decode(OllamaClient.TurnPayload.self, from: inner)

        #expect(!turn.narrative.isEmpty)
        #expect(!turn.options.isEmpty)
    }
}
