import Testing
import Foundation
@testable import DICOMWeb

@Suite("DICOMWeb Configuration Tests")
struct DICOMWebConfigurationTests {
    
    @Test("Basic configuration creation")
    func testBasicConfiguration() throws {
        let baseURL = URL(string: "https://pacs.hospital.com/dicomweb")!
        let config = DICOMWebConfiguration(baseURL: baseURL)
        
        #expect(config.baseURL == baseURL)
        #expect(config.timeout == 60)
        #expect(config.maxConcurrentRequests == 4)
        #expect(config.validateCertificates == true)
        #expect(config.customHeaders.isEmpty)
        #expect(config.defaultSearchLimit == 100)
    }
    
    @Test("Configuration with custom values")
    func testCustomConfiguration() throws {
        let baseURL = URL(string: "https://pacs.hospital.com/dicomweb")!
        let config = DICOMWebConfiguration(
            baseURL: baseURL,
            authentication: .bearer(token: "test-token"),
            timeout: 120,
            maxConcurrentRequests: 8,
            validateCertificates: false,
            customHeaders: ["X-Custom-Header": "custom-value"],
            maxPartSize: 20 * 1024 * 1024,
            defaultSearchLimit: 50
        )
        
        #expect(config.timeout == 120)
        #expect(config.maxConcurrentRequests == 8)
        #expect(config.validateCertificates == false)
        #expect(config.customHeaders["X-Custom-Header"] == "custom-value")
        #expect(config.maxPartSize == 20 * 1024 * 1024)
        #expect(config.defaultSearchLimit == 50)
    }
    
    @Test("No authentication headers")
    func testNoAuthentication() {
        let auth = DICOMWebAuthentication.none
        #expect(auth.headers.isEmpty)
    }
    
    @Test("Basic authentication headers")
    func testBasicAuthentication() {
        let auth = DICOMWebAuthentication.basic(username: "user", password: "pass")
        let headers = auth.headers
        
        #expect(headers["Authorization"] != nil)
        let expectedBase64 = Data("user:pass".utf8).base64EncodedString()
        #expect(headers["Authorization"] == "Basic \(expectedBase64)")
    }
    
    @Test("Bearer token authentication headers")
    func testBearerAuthentication() {
        let auth = DICOMWebAuthentication.bearer(token: "my-token")
        let headers = auth.headers
        
        #expect(headers["Authorization"] == "Bearer my-token")
    }
    
    @Test("API key authentication headers")
    func testAPIKeyAuthentication() {
        let auth = DICOMWebAuthentication.apiKey(headerName: "X-API-Key", value: "secret-key")
        let headers = auth.headers
        
        #expect(headers["X-API-Key"] == "secret-key")
    }
    
    @Test("Custom authentication headers")
    func testCustomAuthentication() {
        let customHeaders = ["X-Auth-Token": "token123", "X-Auth-User": "admin"]
        let auth = DICOMWebAuthentication.custom(headers: customHeaders)
        let headers = auth.headers
        
        #expect(headers["X-Auth-Token"] == "token123")
        #expect(headers["X-Auth-User"] == "admin")
    }
    
    @Test("OAuth2 configuration")
    func testOAuth2Configuration() throws {
        let tokenEndpoint = URL(string: "https://auth.hospital.com/oauth/token")!
        let config = OAuth2Configuration(
            tokenEndpoint: tokenEndpoint,
            clientID: "client123",
            clientSecret: "secret456",
            scopes: ["read", "write"],
            grantType: .clientCredentials
        )
        
        #expect(config.tokenEndpoint == tokenEndpoint)
        #expect(config.clientID == "client123")
        #expect(config.clientSecret == "secret456")
        #expect(config.scopes == ["read", "write"])
        #expect(config.grantType == .clientCredentials)
    }
    
    @Test("Default transfer syntaxes")
    func testDefaultTransferSyntaxes() {
        let defaults = DICOMWebConfiguration.defaultTransferSyntaxes
        
        #expect(defaults.contains("1.2.840.10008.1.2.1")) // Explicit VR Little Endian
        #expect(defaults.contains("1.2.840.10008.1.2"))   // Implicit VR Little Endian
    }
    
    @Test("Media type with parameters")
    func testMediaTypeWithParameters() {
        let mediaType = DICOMWebMediaType.dicom
        let withParams = mediaType.withParameters(["transfer-syntax": "1.2.840.10008.1.2.1"])
        
        #expect(withParams.contains("application/dicom"))
        #expect(withParams.contains("transfer-syntax"))
        #expect(withParams.contains("1.2.840.10008.1.2.1"))
    }
    
    @Test("Media type without parameters")
    func testMediaTypeWithoutParameters() {
        let mediaType = DICOMWebMediaType.dicomJSON
        let result = mediaType.withParameters([:])
        
        #expect(result == "application/dicom+json")
    }
    
    @Test("WADO request options defaults")
    func testWADORequestOptionsDefaults() {
        let options = WADORequestOptions.default
        
        #expect(options.acceptMediaTypes == [.dicom])
        #expect(options.transferSyntaxUIDs.isEmpty)
        #expect(options.includePrivateTags == true)
    }
    
    @Test("WADO metadata only options")
    func testWADOMetadataOnlyOptions() {
        let options = WADORequestOptions.metadataOnly
        
        #expect(options.acceptMediaTypes == [.dicomJSON])
    }
    
    @Test("Viewport creation")
    func testViewport() {
        let viewport = Viewport(width: 512, height: 512)
        
        #expect(viewport.width == 512)
        #expect(viewport.height == 512)
    }
    
    @Test("QIDO request options")
    func testQIDORequestOptions() {
        let options = QIDORequestOptions(
            limit: 50,
            offset: 100,
            fuzzyMatching: true
        )
        
        #expect(options.limit == 50)
        #expect(options.offset == 100)
        #expect(options.fuzzyMatching == true)
    }
    
    @Test("STOW request options")
    func testSTOWRequestOptions() {
        let options = STOWRequestOptions(
            allowCoercion: true,
            studyInstanceUID: "1.2.3.4.5"
        )
        
        #expect(options.allowCoercion == true)
        #expect(options.studyInstanceUID == "1.2.3.4.5")
    }
}
