import SwiftParser
import SwiftSyntax
import SwiftSyntaxBuilder
import XCTest
@testable import AutoValueMacros

enum VariableHelperTestsError: Error {
    case invalidDeclSyntax
}

final class VariableHelperTests: XCTestCase {

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

    // MARK: Util

    private func assertIsStoredProperty(_ source: String, file: StaticString = #filePath, line: UInt = #line) throws {
        let variable = try Self.createVariable(source)
        XCTAssertTrue(VariableHelper.isStoredProperty(variable), file: file, line: line)
    }

    private func assertIsNotStoredProperty(_ source: String, file: StaticString = #filePath, line: UInt = #line) throws {
        let variable = try Self.createVariable(source)
        XCTAssertFalse(VariableHelper.isStoredProperty(variable), file: file, line: line)
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
