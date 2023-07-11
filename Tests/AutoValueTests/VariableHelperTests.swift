import SwiftParser
import SwiftSyntax
import SwiftSyntaxBuilder
import XCTest
@testable import AutoValueMacros

enum VariableHelperTestsError: Error {
    case invalidDeclSyntax
}

extension VariableHelper.Property: CustomStringConvertible {
    public var description: String {
        return "(\(identifier), \(type))"
    }
}

final class VariableHelperTests: XCTestCase {

    // MARK: Get Stored Properties Constant Declarations

    func testConstantDeclaration_simple_getProperties() throws {
        try assertGetStoredProperties("let a: Int", [
            ("a", "Int")
        ])
    }

    func testConstantDeclaration_init_getProperties() throws {
        try assertGetStoredProperties("let a: Int = 0", [
            ("a", "Int")
        ])
    }

    func testConstantDeclaration_listInline_getProperties() throws {
        try assertGetStoredProperties("let a: Int, b: Double", [
            ("a", "Int"),
            ("b", "Double")
        ])
    }

    func testConstantDeclaration_listTrailing_getProperties() throws {
        try assertGetStoredProperties("let a, b: Int", [
            ("a", "Int"),
            ("b", "Int")
        ])
    }

    func testConstantDeclaration_initList_getProperties() throws {
        try assertGetStoredProperties("let a: Int = 1, b: Double = 2", [
            ("a", "Int"),
            ("b", "Double")
        ])
    }

    func testConstantDeclaration_tuple_getProperties() throws {
        try assertGetStoredProperties("let (a, b): (Int, Double)", [
            ("a", "Int"),
            ("b", "Double")
        ])
    }

    func testConstantDeclaration_listMixedTrailingInline_getProperties() throws {
        try assertGetStoredProperties("let a, b: Int, c: Double", [
            ("a", "Int"),
            ("b", "Int"),
            ("c", "Double")
        ])
    }

    func testConstantDeclaration_initListMixedInlineTrailing_getProperties() throws {
        try assertGetStoredProperties("let a: Int = 0, b, c: Double", [
            ("a", "Int"),
            ("b", "Double"),
            ("c", "Double")
        ])
    }

    func testConstantDeclaration_listMixedTupleSimple_getProperties() throws {
        try assertGetStoredProperties("let (a, b): (Int, Double), c: String", [
            ("a", "Int"),
            ("b", "Double"),
            ("c", "String")
        ])
    }

    func testConstantDeclaration_nestedTuple_getProperties() throws {
        try assertGetStoredProperties("let (a, (b, c)): (Int, (Double, String))", [
            ("a", "Int"),
            ("b", "Double"),
            ("c", "String")
        ])
    }

    // MARK: Get Stored Properties Variable Declarations

    func testVariableDeclaration_simple_getProperties() throws {
        try assertGetStoredProperties("var a: Int", [
            ("a", "Int")
        ])
    }

    func testVariableDeclaration_init_getProperties() throws {
        try assertGetStoredProperties("var a: Int = 0", [
            ("a", "Int")
        ])
    }

    func testVariableDeclaration_listInline_getProperties() throws {
        try assertGetStoredProperties("var a: Int, b: Double", [
            ("a", "Int"),
            ("b", "Double")
        ])
    }

    func testVariableDeclaration_listTrailing_getProperties() throws {
        try assertGetStoredProperties("var a, b: Int", [
            ("a", "Int"),
            ("b", "Int")
        ])
    }

    func testVariableDeclaration_initList_getProperties() throws {
        try assertGetStoredProperties("var a: Int = 1, b: Double = 2", [
            ("a", "Int"),
            ("b", "Double")
        ])
    }

    func testVariableDeclaration_tuple_getProperties() throws {
        try assertGetStoredProperties("var (a, b): (Int, Double)", [
            ("a", "Int"),
            ("b", "Double")
        ])
    }

    func testVariableDeclaration_willSetAccessorBlock_getProperties() throws {
        try assertGetStoredProperties("var a: Int { willSet { print(\"will set\") } }", [
            ("a", "Int")
        ])
    }

    func testVariableDeclaration_didSetAccessorBlock_getProperties() throws {
        try assertGetStoredProperties("var a: Int { didSet { print(\"did set\") }", [
            ("a", "Int")
        ])
    }

    func testVariableDeclaration_willSetAndDidSetAccessorBlocks_getProperties() throws {
        try assertGetStoredProperties("var a: Int { willSet { print(\"willSet\") } didSet { print(\"did set\") } }", [
            ("a", "Int")
        ])
    }

    func testVariableDeclaration_listMixedTrailingInline_getProperties() throws {
        try assertGetStoredProperties("var a, b: Int, c: Double", [
            ("a", "Int"),
            ("b", "Int"),
            ("c", "Double")
        ])
    }

    func testVariableDeclaration_initListMixedInlineTrailing_getProperties() throws {
        try assertGetStoredProperties("var a: Int = 0, b, c: Double", [
            ("a", "Int"),
            ("b", "Double"),
            ("c", "Double")
        ])
    }

    func testVariableDeclaration_listMixedTupleSimple_getProperties() throws {
        try assertGetStoredProperties("var (a, b): (Int, Double), c: Int", [
            ("a", "Int"),
            ("b", "Double"),
            ("c", "Int")
        ])
    }

    func testVariableDeclaration_nestedTuple_getProperties() throws {
        try assertGetStoredProperties("var (a, (b, c)): (Int, (Int, Double))", [
            ("a", "Int"),
            ("b", "Int"),
            ("c", "Double")
        ])
    }

    // MARK: Get Computed Properties Variable Declarations

    func testVariableDeclaration_codeBlock_getProperties() throws {
        try assertGetStoredProperties("var a: Int { return 0 }", [])
    }

    func testVariableDeclaration_getAccessorBlock_getProperties() throws {
        try assertGetStoredProperties("var a: Int { get { return b } }", [])
    }

    func testVariableDeclaration_getAndSetAccessorBlocks_getProperties() throws {
        try assertGetStoredProperties("var a: Int { get { return b } set { b = newValue } }", [])
    }

    // MARK: Get Stored and Computed Properties Mixed Declarations

    func testMixedDeclarations_getProperties() throws {
        try assertGetStoredProperties([
            "let a: Int",
            "var b: Double",
            "var c: String { return \"c\" }",
            "var d: Float"
        ], [
            ("a", "Int"),
            ("b", "Double"),
            ("d", "Float")
        ])
    }

    // MARK: -

    // MARK: Stored Property Constant Declarations

    func testConstantDeclaration_simple_isStoredProperty() throws {
        try assertIsStoredProperty("let a: Int")
    }

    func testConstantDeclaration_init_isStoredProperty() throws {
        try assertIsStoredProperty("let a: Int = 0")
    }

    func testConstantDeclaration_listInline_isStoredProperty() throws {
        try assertIsStoredProperty("let a: Int, b: Double")
    }

    func testConstantDeclaration_listTrailing_isStoredProperty() throws {
        try assertIsStoredProperty("let a, b: Int")
    }

    func testConstantDeclaration_initList_isStoredProperty() throws {
        try assertIsStoredProperty("let a: Int = 1, b: Double = 2")
    }

    func testConstantDeclaration_tuple_isStoredProperty() throws {
        try assertIsStoredProperty("let (a, b): (Int, Double)")
    }

    func testConstantDeclaration_listMixedTrailingInline_isStoredProperty() throws {
        try assertIsStoredProperty("let a, b: Int, c: Double")
    }

    func testConstantDeclaration_initListMixedInlineTrailing_isStoredProperty() throws {
        try assertIsStoredProperty("let a: Int = 0, b, c: Double")
    }

    func testConstantDeclaration_listMixedTupleSimple_isStoredProperty() throws {
        try assertIsStoredProperty("let (a, b): (Int, Double), c: Int")
    }

    func testConstantDeclaration_nestedTuple_isStoredProperty() throws {
        try assertIsStoredProperty("let (a, (b, c)): (Int, (Int, Double))")
    }

    // MARK: Stored Property Variable Declarations

    func testVariableDeclaration_simple_isStoredProperty() throws {
        try assertIsStoredProperty("var a: Int")
    }

    func testVariableDeclaration_init_isStoredProperty() throws {
        try assertIsStoredProperty("var a: Int = 0")
    }

    func testVariableDeclaration_listInline_isStoredProperty() throws {
        try assertIsStoredProperty("var a: Int, b: Double")
    }

    func testVariableDeclaration_listTrailing_isStoredProperty() throws {
        try assertIsStoredProperty("var a, b: Int")
    }

    func testVariableDeclaration_initList_isStoredProperty() throws {
        try assertIsStoredProperty("var a: Int = 1, b: Double = 2")
    }

    func testVariableDeclaration_tuple_isStoredProperty() throws {
        try assertIsStoredProperty("var (a, b): (Int, Double)")
    }

    func testVariableDeclaration_willSetAccessorBlock_isStoredProperty() throws {
        try assertIsStoredProperty("var a: Int { willSet { print(\"will set\") } }")
    }

    func testVariableDeclaration_didSetAccessorBlock_isStoredProperty() throws {
        try assertIsStoredProperty("var a: Int { didSet { print(\"did set\") }")
    }

    func testVariableDeclaration_willSetAndDidSetAccessorBlocks_isStoredProperty() throws {
        try assertIsStoredProperty("var a: Int { willSet { print(\"willSet\") } didSet { print(\"did set\") } }")
    }

    func testVariableDeclaration_listMixedTrailingInline_isStoredProperty() throws {
        try assertIsStoredProperty("var a, b: Int, c: Double")
    }

    func testVariableDeclaration_initListMixedInlineTrailing_isStoredProperty() throws {
        try assertIsStoredProperty("var a: Int = 0, b, c: Double")
    }

    func testVariableDeclaration_listMixedTupleSimple_isStoredProperty() throws {
        try assertIsStoredProperty("var (a, b): (Int, Double), c: Int")
    }

    func testVariableDeclaration_nestedTuple_isStoredProperty() throws {
        try assertIsStoredProperty("var (a, (b, c)): (Int, (Int, Double))")
    }

    // MARK: Computed Property Variable Declarations

    func testVariableDeclaration_codeBlock_isNotStoredProperty() throws {
        try assertIsNotStoredProperty("var a: Int { return 0 }")
    }

    func testVariableDeclaration_getAccessorBlock_isNotStoredProperty() throws {
        try assertIsNotStoredProperty("var a: Int { get { return b } }")
    }

    func testVariableDeclaration_getAndSetAccessorBlocks_isNotStoredProperty() throws {
        try assertIsNotStoredProperty("var a: Int { get { return b } set { b = newValue } }")
    }

    // MARK: - Util

    private func assertGetStoredProperties(
        _ variableSource: String,
        _ properties: [(identifier: String, type: String)],
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        try assertGetStoredProperties([variableSource], properties, file: file, line: line)
    }

    private func assertGetStoredProperties(
        _ variableSources: [String],
        _ properties: [(identifier: String, type: String)],
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let memberList = try Self.createMemberList(variableSources)
        let actualProperties = VariableHelper.getStoredProperties(from: memberList)
        let expectedProperties = properties.map({ VariableHelper.Property($0.0, $0.1) })
        XCTAssertEqual(actualProperties, expectedProperties, file: file, line: line)
    }

    private func assertIsStoredProperty(_ source: String, file: StaticString = #filePath, line: UInt = #line) throws {
        let variable = try Self.createVariable(source)
        XCTAssertTrue(VariableHelper.isStoredProperty(variable), file: file, line: line)
    }

    private func assertIsNotStoredProperty(_ source: String, file: StaticString = #filePath, line: UInt = #line) throws {
        let variable = try Self.createVariable(source)
        XCTAssertFalse(VariableHelper.isStoredProperty(variable), file: file, line: line)
    }

    private static func createMemberList(_ variableSources: [String]) throws -> MemberDeclListSyntax {
        return try MemberDeclListSyntax {
            for source in variableSources {
                try createVariable(source)
            }
        }
    }

    private static func createVariable(_ source: String) throws -> VariableDeclSyntax {
        let syntax = Parser.parse(source: source)
        guard case let CodeBlockItemSyntax.Item.decl(decl) = syntax.statements.first!.item else {
            throw VariableHelperTestsError.invalidDeclSyntax
        }
        guard let variable = decl.as(VariableDeclSyntax.self) else {
            throw VariableHelperTestsError.invalidDeclSyntax
        }
        return variable
    }
}
