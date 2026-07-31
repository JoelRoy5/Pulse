import XCTest
import SwiftUI
@testable import PulseShared

final class ColorHexTests: XCTestCase {
    func testHexParsingProducesExpectedComponents() {
        let gold = Color(hex: "#C9A96E")
        let resolved = gold.resolve(in: .init())
        XCTAssertEqual(resolved.red, 201.0/255.0, accuracy: 0.01)
        XCTAssertEqual(resolved.green, 169.0/255.0, accuracy: 0.01)
        XCTAssertEqual(resolved.blue, 110.0/255.0, accuracy: 0.01)
    }
    func testBadHexDoesNotCrash() {
        _ = Color(hex: "not-a-color")
    }
    func testEveryStateHasGradientAndPrimaryColor() {
        for state in BiometricState.allCases {
            _ = state.gradient
            _ = state.primaryColor
            XCTAssertTrue(state.primaryColorHex.hasPrefix("#"))
        }
    }
}
