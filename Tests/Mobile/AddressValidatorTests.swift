//
//  AddressValidatorTests.swift
//  Arke
//
//  Tests for Address Validator
//

import Testing
@testable import Shared

@Suite("Address Validator Tests")
struct AddressValidatorTests {
    
    @Test("Parse BIP-21 with lowercase parameters")
    func testBIP21WithLowercaseParameters() async throws {
        let bip21 = "bitcoin:BC1QLGRRREGY2ZLTHAL2VGM9WQSUPGZQ54EM3ZTNCT?amount=0.00005000&lightning=lnbc50u1p4zt043pp5zuzgwk3cxt2la8as6am3pvfnkgx68xjlepxh4ucly9vhvr7eeqwssp5fqad2zl3fza6pe7cffjylzpm0cd8r6rly7xqzu8s9vmdwepfa34sdq50f5kuut3ypmkzmrvv46qxqrrsscqzyjnp4qgyw03fg9lnp8k9yee0fvjkvzvsk98h0nktj8yavcxx0jc8crvqp59qy9qsqrzjqvkfcajgu3cma73dctgf8cy9fhgn3un33s9djw75gyfj3veaqu53szeepsqq8tcqqqqqqqqqqqqqqqqqfqsrr5t0s44eu49dw3cue6n8d0pzjql84khg2vrnsl8x2r34w0kqdrd7zc63dcjyw6d83u2mjpdcun9svleayt3tanchxdh0sjhf6dgacq589ce3"
        
        let paymentRequest = AddressValidator.parsePaymentRequest(bip21)
        
        #expect(paymentRequest != nil, "Should parse BIP-21 URI")
        #expect(paymentRequest?.destinations.count == 2, "Should have 2 destinations (onchain + lightning)")
        #expect(paymentRequest?.amount == 5000, "Amount should be 5000 sats (0.00005000 BTC)")
        
        // Check that we have both onchain and lightning destinations
        let hasOnchain = paymentRequest?.destinations.contains { $0.format == .bitcoin } ?? false
        let hasLightning = paymentRequest?.destinations.contains { $0.format == .lightningInvoice } ?? false
        
        #expect(hasOnchain, "Should have onchain destination")
        #expect(hasLightning, "Should have lightning destination")
    }
    
    @Test("Parse BIP-21 with uppercase parameters (QR code scenario)")
    func testBIP21WithUppercaseParameters() async throws {
        let bip21 = "BITCOIN:BC1QLGRRREGY2ZLTHAL2VGM9WQSUPGZQ54EM3ZTNCT?AMOUNT=0.00005000&LIGHTNING=LNBC50U1P4ZT043PP5ZUZGWK3CXT2LA8AS6AM3PVFNKGX68XJLEPXH4UCLY9VHVR7EEQWSSP5FQAD2ZL3FZA6PE7CFFJYLZPM0CD8R6RLY7XQZU8S9VMDWEPFA34SDQ50F5KUUT3YPMKZMRVV46QXQRRSSCQZYJNP4QGYW03FG9LNP8K9YEE0FVJKVZVSK98H0NKTJ8YAVCXX0JC8CRVQP59QY9QSQRZJQVKFCAJGU3CMA73DCTGF8CY9FHGN3UN33S9DJW75GYFJ3VEAQU53SZEEPSQQ8TCQQQQQQQQQQQQQQQQQFQSRR5T0S44EU49DW3CUE6N8D0PZJQL84KHG2VRNSL8X2R34W0KQDRD7ZC63DCJYW6D83U2MJPDCUN9SVLEAYT3TANCHXDH0SJHF6DGACQ589CE3"
        
        let paymentRequest = AddressValidator.parsePaymentRequest(bip21)
        
        #expect(paymentRequest != nil, "Should parse BIP-21 URI with uppercase parameters")
        #expect(paymentRequest?.destinations.count == 2, "Should have 2 destinations (onchain + lightning)")
        #expect(paymentRequest?.amount == 5000, "Amount should be 5000 sats (0.00005000 BTC)")
        
        // Check that we have both onchain and lightning destinations
        let hasOnchain = paymentRequest?.destinations.contains { $0.format == .bitcoin } ?? false
        let hasLightning = paymentRequest?.destinations.contains { $0.format == .lightningInvoice } ?? false
        
        #expect(hasOnchain, "Should have onchain destination")
        #expect(hasLightning, "Should have lightning destination")
    }
    
    @Test("Parse BIP-21 with mixed case parameters")
    func testBIP21WithMixedCaseParameters() async throws {
        let bip21 = "bitcoin:BC1QLGRRREGY2ZLTHAL2VGM9WQSUPGZQ54EM3ZTNCT?Amount=0.00005000&Lightning=lnbc50u1p4zt043pp5zuzgwk3cxt2la8as6am3pvfnkgx68xjlepxh4ucly9vhvr7eeqwssp5fqad2zl3fza6pe7cffjylzpm0cd8r6rly7xqzu8s9vmdwepfa34sdq50f5kuut3ypmkzmrvv46qxqrrsscqzyjnp4qgyw03fg9lnp8k9yee0fvjkvzvsk98h0nktj8yavcxx0jc8crvqp59qy9qsqrzjqvkfcajgu3cma73dctgf8cy9fhgn3un33s9djw75gyfj3veaqu53szeepsqq8tcqqqqqqqqqqqqqqqqqfqsrr5t0s44eu49dw3cue6n8d0pzjql84khg2vrnsl8x2r34w0kqdrd7zc63dcjyw6d83u2mjpdcun9svleayt3tanchxdh0sjhf6dgacq589ce3"
        
        let paymentRequest = AddressValidator.parsePaymentRequest(bip21)
        
        #expect(paymentRequest != nil, "Should parse BIP-21 URI with mixed case parameters")
        #expect(paymentRequest?.destinations.count == 2, "Should have 2 destinations (onchain + lightning)")
        #expect(paymentRequest?.amount == 5000, "Amount should be 5000 sats")
        
        // Check that we have both onchain and lightning destinations
        let hasOnchain = paymentRequest?.destinations.contains { $0.format == .bitcoin } ?? false
        let hasLightning = paymentRequest?.destinations.contains { $0.format == .lightningInvoice } ?? false
        
        #expect(hasOnchain, "Should have onchain destination")
        #expect(hasLightning, "Should have lightning destination")
    }
}
