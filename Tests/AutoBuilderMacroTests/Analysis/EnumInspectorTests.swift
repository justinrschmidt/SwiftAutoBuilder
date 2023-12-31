import SwiftParser
import SwiftSyntax
import SwiftSyntaxBuilder
import XCTest
@testable import AutoBuilderMacros

final class EnumInspectorTests: XCTestCase {
    func testGetCases_simple() {
        assertGetCases("case one(a: Int)", [
            ("one", [
                ("a", .explicit(typeNode: "Int"), .uninitialized)
            ])
        ])
    }

    func testGetCases_casesListInline() {
        assertGetCases("case one(a: Int), two(b: Double)", [
            ("one", [
                ("a", .explicit(typeNode: "Int"), .uninitialized)
            ]),
            ("two", [
                ("b", .explicit(typeNode: "Double"), .uninitialized)
            ])
        ])
    }

    func testGetCases_valuesListInline() {
        assertGetCases("case one(a: Int, b: Double)", [
            ("one", [
                ("a", .explicit(typeNode: "Int"), .uninitialized),
                ("b", .explicit(typeNode: "Double"), .uninitialized)
            ])
        ])
    }

    func testGetCases_noValues() {
        assertGetCases("case one", [
            ("one", [])
        ])
    }

    func testGetCases_noIdentifier() {
        assertGetCases("case one(Int)", [
            ("one", [
                (0, .explicit(typeNode: "Int"), .uninitialized)
            ])
        ])
    }

    func testGetCases_valuesListInline_noIdentifiers() {
        assertGetCases("case one(Int, Double, String)", [
            ("one", [
                (0, .explicit(typeNode: "Int"), .uninitialized),
                (1, .explicit(typeNode: "Double"), .uninitialized),
                (2, .explicit(typeNode: "String"), .uninitialized)
            ])
        ])
    }

    func testGetCases_mixedIdentifiers() {
        assertGetCases("case one(Int, b: Double)", [
            ("one", [
                (0, .explicit(typeNode: "Int"), .uninitialized),
                ("b", .explicit(typeNode: "Double"), .uninitialized)
            ])
        ])
    }

    func testGetCases_init() {
        assertGetCases("case one(a: Int = 1)", [
            ("one", [
                ("a", .explicit(typeNode: "Int"), .initialized)
            ])
        ])
    }

    func testGetCases_init_noIdentifier() {
        assertGetCases("case one(Int = 1)", [
            ("one", [
                (0, .explicit(typeNode: "Int"), .initialized)
            ])
        ])
    }

    // MARK: - Util

    private func assertGetCases(
        _ caseSource: String,
        _ cases: [(
            caseIdentifier: IdentifierPatternSyntax,
            associatedValues: [(
                label: AssociatedValue.Label,
                type: VariableTypeDescriptor,
                initialized: InitializedStatus
            )]
        )],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        assertGetCases([caseSource], cases, file: file, line: line)
    }

    private func assertGetCases(
        _ caseSources: [String],
        _ cases: [(
            caseIdentifier: IdentifierPatternSyntax,
            associatedValues: [(
                label: AssociatedValue.Label,
                type: VariableTypeDescriptor,
                initialized: InitializedStatus
            )]
        )],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let memberList = Self.createMemberList(caseSources)
        let actualCases = EnumInspector.getCases(from: memberList)
        let expectedCases = cases.map({ EnumUnionCase(
            caseIdentifierPattern: $0.caseIdentifier,
            associatedValues: $0.associatedValues.map({
                let firstNameToken: TokenSyntax?
                if case let .identifierPattern(pattern) = $0.label {
                    firstNameToken = pattern.identifier
                } else {
                    firstNameToken = nil
                }
                return AssociatedValue(
                    label: $0.label,
                    variableType: $0.type.variableType,
                    isInitialized: $0.initialized.isInitialized,
                    firstNameToken: firstNameToken)
            }))
        })
        XCTAssertEqual(actualCases, expectedCases, file: file, line: line)
    }

    private static func createMemberList(_ caseSources: [String]) -> MemberBlockItemListSyntax {
        return MemberBlockItemListSyntax {
            for source in caseSources {
                EnumCaseDeclSyntax(declString: source)
            }
        }
    }
}

extension EnumCaseDeclSyntax {
    init(declString: String) {
        var parser = Parser(declString)
        self.init(DeclSyntax.parse(from: &parser))!
    }
}

extension AssociatedValue.Label: ExpressibleByStringLiteral {
    public init(stringLiteral value: StringLiteralType) {
        self = .identifierPattern(IdentifierPatternSyntax(identifier: .identifier(value)))
    }
}

extension AssociatedValue.Label: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: IntegerLiteralType) {
        self = .index(value)
    }
}
