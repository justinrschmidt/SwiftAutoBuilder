import SwiftParser
import SwiftSyntax
import SwiftSyntaxBuilder
import XCTest
@testable import AutoBuilderMacros

enum VariableHelperTestsError: Error {
    case invalidDeclSyntax
}

final class VariableHelperTests: XCTestCase {

    // MARK: Get Stored Properties Constant Declarations

    func testConstantDeclaration_simple_getProperties() throws {
        try assertGetStoredProperties("let a: Int", [
            (.let, "a", "Int", .uninitialized)
        ])
    }

    func testConstantDeclaration_init_getProperties() throws {
        try assertGetStoredProperties("let a: Int = 0", [
            (.let, "a", "Int", .initialized)
        ])
    }

    func testConstantDeclaration_listInline_getProperties() throws {
        try assertGetStoredProperties("let a: Int, b: Double", [
            (.let, "a", "Int", .uninitialized),
            (.let, "b", "Double", .uninitialized)
        ])
    }

    func testConstantDeclaration_listTrailing_getProperties() throws {
        try assertGetStoredProperties("let a, b: Int", [
            (.let, "a", "Int", .uninitialized),
            (.let, "b", "Int", .uninitialized)
        ])
    }

    func testConstantDeclaration_initList_getProperties() throws {
        try assertGetStoredProperties("let a: Int = 1, b: Double = 2", [
            (.let, "a", "Int", .initialized),
            (.let, "b", "Double", .initialized)
        ])
    }

    func testConstantDeclaration_tuple_getProperties() throws {
        try assertGetStoredProperties("let (a, b): (Int, Double)", [
            (.let, "a", "Int", .uninitialized),
            (.let, "b", "Double", .uninitialized)
        ])
    }

    func testConstantDeclaration_initTuple_getProperties() throws {
        try assertGetStoredProperties("let (a, b): (Int, Double) = (1, 2.3)", [
            (.let, "a", "Int", .initialized),
            (.let, "b", "Double", .initialized)
        ])
    }

    func testConstantDeclaration_tupleType_getProperties() throws {
        try assertGetStoredProperties("let a: (Int, Double)", [
            (.let, "a", "(Int, Double)", .uninitialized)
        ])
    }

    func testConstantDeclaration_tupleWithComplexTypes_getProperties() throws {
        try assertGetStoredProperties("let (a, b): (Int, (Double, String))", [
            (.let, "a", "Int", .uninitialized),
            (.let, "b", "(Double, String)", .uninitialized)
        ])
    }

    func testConstantDeclaration_listMixedTrailingInline_getProperties() throws {
        try assertGetStoredProperties("let a, b: Int, c: Double", [
            (.let, "a", "Int", .uninitialized),
            (.let, "b", "Int", .uninitialized),
            (.let, "c", "Double", .uninitialized)
        ])
    }

    func testConstantDeclaration_initListMixedInlineTrailing_getProperties() throws {
        try assertGetStoredProperties("let a: Int = 0, b, c: Double", [
            (.let, "a", "Int", .initialized),
            (.let, "b", "Double", .uninitialized),
            (.let, "c", "Double", .uninitialized)
        ])
    }

    func testConstantDeclaration_listMixedTupleSimple_getProperties() throws {
        try assertGetStoredProperties("let (a, b): (Int, Double), c: String", [
            (.let, "a", "Int", .uninitialized),
            (.let, "b", "Double", .uninitialized),
            (.let, "c", "String", .uninitialized)
        ])
    }

    func testConstantDeclaration_nestedTuple_getProperties() throws {
        try assertGetStoredProperties("let (a, (b, c)): (Int, (Double, String))", [
            (.let, "a", "Int", .uninitialized),
            (.let, "b", "Double", .uninitialized),
            (.let, "c", "String", .uninitialized)
        ])
    }

    func testConstantDeclaration_arrayType_getProperties() throws {
        try assertGetStoredProperties("let a: [Int]", [
            (.let, "a", "[Int]", .uninitialized)
        ])
    }

    func testConstantDeclaration_dictionaryType_getProperties() throws {
        try assertGetStoredProperties("let a: [Int:Double]", [
            (.let, "a", "[Int:Double]", .uninitialized)
        ])
    }

    func testConstantDeclaration_genericType_getProperties() throws {
        try assertGetStoredProperties("let a: Set<Int>", [
            (.let, "a", "Set<Int>", .uninitialized)
        ])
    }

    // MARK: Get Stored Properties Variable Declarations

    func testVariableDeclaration_simple_getProperties() throws {
        try assertGetStoredProperties("var a: Int", [
            (.var, "a", "Int", .uninitialized)
        ])
    }

    func testVariableDeclaration_init_getProperties() throws {
        try assertGetStoredProperties("var a: Int = 0", [
            (.var, "a", "Int", .initialized)
        ])
    }

    func testVariableDeclaration_listInline_getProperties() throws {
        try assertGetStoredProperties("var a: Int, b: Double", [
            (.var, "a", "Int", .uninitialized),
            (.var, "b", "Double", .uninitialized)
        ])
    }

    func testVariableDeclaration_listTrailing_getProperties() throws {
        try assertGetStoredProperties("var a, b: Int", [
            (.var, "a", "Int", .uninitialized),
            (.var, "b", "Int", .uninitialized)
        ])
    }

    func testVariableDeclaration_initList_getProperties() throws {
        try assertGetStoredProperties("var a: Int = 1, b: Double = 2", [
            (.var, "a", "Int", .initialized),
            (.var, "b", "Double", .initialized)
        ])
    }

    func testVariableDeclaration_tuple_getProperties() throws {
        try assertGetStoredProperties("var (a, b): (Int, Double)", [
            (.var, "a", "Int", .uninitialized),
            (.var, "b", "Double", .uninitialized)
        ])
    }

    func testVariableDeclaration_initTuple_getProperties() throws {
        try assertGetStoredProperties("var (a, b): (Int, Double) = (1, 2.3)", [
            (.var, "a", "Int", .initialized),
            (.var, "b", "Double", .initialized)
        ])
    }

    func testVariableDeclaration_tupleType_getProperties() throws {
        try assertGetStoredProperties("var a: (Int, Double)", [
            (.var, "a", "(Int, Double)", .uninitialized)
        ])
    }

    func testVariableDeclaration_tupleWithComplexTypes_getProperties() throws {
        try assertGetStoredProperties("var (a, b): (Int, (Double, String))", [
            (.var, "a", "Int", .uninitialized),
            (.var, "b", "(Double, String)", .uninitialized)
        ])
    }

    func testVariableDeclaration_willSetAccessorBlock_getProperties() throws {
        try assertGetStoredProperties("var a: Int { willSet { print(\"will set\") } }", [
            (.var, "a", "Int", .uninitialized)
        ])
    }

    func testVariableDeclaration_didSetAccessorBlock_getProperties() throws {
        try assertGetStoredProperties("var a: Int { didSet { print(\"did set\") }", [
            (.var, "a", "Int", .uninitialized)
        ])
    }

    func testVariableDeclaration_willSetAndDidSetAccessorBlocks_getProperties() throws {
        try assertGetStoredProperties("var a: Int { willSet { print(\"willSet\") } didSet { print(\"did set\") } }", [
            (.var, "a", "Int", .uninitialized)
        ])
    }

    func testVariableDeclaration_listMixedTrailingInline_getProperties() throws {
        try assertGetStoredProperties("var a, b: Int, c: Double", [
            (.var, "a", "Int", .uninitialized),
            (.var, "b", "Int", .uninitialized),
            (.var, "c", "Double", .uninitialized)
        ])
    }

    func testVariableDeclaration_initListMixedInlineTrailing_getProperties() throws {
        try assertGetStoredProperties("var a: Int = 0, b, c: Double", [
            (.var, "a", "Int", .initialized),
            (.var, "b", "Double", .uninitialized),
            (.var, "c", "Double", .uninitialized)
        ])
    }

    func testVariableDeclaration_listMixedTupleSimple_getProperties() throws {
        try assertGetStoredProperties("var (a, b): (Int, Double), c: Int", [
            (.var, "a", "Int", .uninitialized),
            (.var, "b", "Double", .uninitialized),
            (.var, "c", "Int", .uninitialized)
        ])
    }

    func testVariableDeclaration_nestedTuple_getProperties() throws {
        try assertGetStoredProperties("var (a, (b, c)): (Int, (Int, Double))", [
            (.var, "a", "Int", .uninitialized),
            (.var, "b", "Int", .uninitialized),
            (.var, "c", "Double", .uninitialized)
        ])
    }

    func testVariableDeclaration_arrayType_getProperties() throws {
        try assertGetStoredProperties("var a: [Int]", [
            (.var, "a", "[Int]", .uninitialized)
        ])
    }

    func testVariableDeclaration_dictionaryType_getProperties() throws {
        try assertGetStoredProperties("var a: [Int:Double]", [
            (.var, "a", "[Int:Double]", .uninitialized)
        ])
    }

    func testVariableDeclaration_genericType_getProperties() throws {
        try assertGetStoredProperties("var a: Set<Int>", [
            (.var, "a", "Set<Int>", .uninitialized)
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
            (.let, "a", "Int", .uninitialized),
            (.var, "b", "Double", .uninitialized),
            (.var, "d", "Float", .uninitialized)
        ])
    }

    // MARK: Get Stored Properties Implied Types

    func testVariableDeclaration_impliedSimpleTypeInit_getProperties() throws {
        try assertGetStoredProperties("var a = 0", [
            (.var, "a", .implicit, .initialized)
        ])
    }

    func testVariableDeclaration_impliedEnumTypeInit_getProperties() throws {
        try assertGetStoredProperties("var a = (1, 2.0)", [
            (.var, "a", .implicit, .initialized)
        ])
    }

    func testVariableDeclaration_impliedEnumDeclarationTypeInit_getProperties() throws {
        try assertGetStoredProperties("var (a, b) = (1, 2.0)", [
            (.var, "a", .implicit, .initialized),
            (.var, "b", .implicit, .initialized)
        ])
    }

    func testVariableDeclaration_impliedTypeList_getProperties() throws {
        try assertGetStoredProperties("var a = 0, b = 1.0", [
            (.var, "a", .implicit, .initialized),
            (.var, "b", .implicit, .initialized)
        ])
    }

    func testVariableDeclaration_impliedTypeListMixed_getProperties() throws {
        try assertGetStoredProperties("var a = 0, b: String", [
            (.var, "a", .implicit, .initialized),
            (.var, "b", "String", .uninitialized)
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

    func testConstantDeclaration_impliedTypeInit_isStoredProperty() throws {
        try assertIsStoredProperty("let a = 0")
    }

    func testConstantDeclaration_listInline_isStoredProperty() throws {
        try assertIsStoredProperty("let a: Int, b: Double")
    }

    func testConstantDeclaration_impliedTypeListInline_isStoredProperty() throws {
        try assertIsStoredProperty("let a = 0, b = 1.2")
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

    func testConstantDeclaration_initTuple_isStoredProperty() throws {
        try assertIsStoredProperty("let (a, b): (Int, Double) = (1, 2.3)")
    }

    func testConstantDeclaration_tupleType_isStoredProperty() throws {
        try assertIsStoredProperty("let a: (Int, Double)")
    }

    func testConstantDeclaration_tupleWithComplexTypes_isStoredProperty() throws {
        try assertIsStoredProperty("let (a, b): (Int, (Double, String))")
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

    func testConstantDeclaration_arrayType_isStoredProperty() throws {
        try assertIsStoredProperty("let a: [Int]")
    }

    func testConstantDeclaration_dictionaryType_isStoredProperty() throws {
        try assertIsStoredProperty("let a: [Int:Double]")
    }

    func testConstantDeclaration_genericType_isStoredProperty() throws {
        try assertIsStoredProperty("let a: Set<Int>")
    }

    // MARK: Stored Property Variable Declarations

    func testVariableDeclaration_simple_isStoredProperty() throws {
        try assertIsStoredProperty("var a: Int")
    }

    func testVariableDeclaration_init_isStoredProperty() throws {
        try assertIsStoredProperty("var a: Int = 0")
    }

    func testVariableDeclaration_impliedTypeInit_isStoredProperty() throws {
        try assertIsStoredProperty("var a = 0")
    }

    func testVariableDeclaration_listInline_isStoredProperty() throws {
        try assertIsStoredProperty("var a: Int, b: Double")
    }

    func testVariableDeclaration_impliedTypeListInline_isStoredProperty() throws {
        try assertIsStoredProperty("var a = 0, b = 1.2")
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

    func testVariableDeclaration_initTuple_isStoredProperty() throws {
        try assertIsStoredProperty("var (a, b): (Int, Double) = (1, 2.3)")
    }

    func testVariableDeclaration_tupleType_isStoredProperty() throws {
        try assertIsStoredProperty("var a: (Int, Double)")
    }

    func testVariableDeclaration_tupleWithComplexTypes_isStoredProperty() throws {
        try assertIsStoredProperty("var (a, b): (Int, (Double, String))")
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

    func testVariableDeclaration_arrayType_isStoredProperty() throws {
        try assertIsStoredProperty("var a: [Int]")
    }

    func testVariableDeclaration_dictionaryType_isStoredProperty() throws {
        try assertIsStoredProperty("var a: [Int:Double]")
    }

    func testVariableDeclaration_genericType_isStoredProperty() throws {
        try assertIsStoredProperty("var a: Set<Int>")
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

    private enum InitializedStatus {
        case initialized
        case uninitialized

        var isInitialized: Bool {
            switch self {
            case .initialized:
                return true
            case .uninitialized:
                return false
            }
        }
    }

    private func assertGetStoredProperties(
        _ variableSource: String,
        _ properties: [(bindingKeyword: Property.BindingKeyword, identifier: IdentifierPatternSyntax, type: Property.VariableType, initialized: InitializedStatus)],
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        try assertGetStoredProperties([variableSource], properties, file: file, line: line)
    }

    private func assertGetStoredProperties(
        _ variableSources: [String],
        _ properties: [(bindingKeyword: Property.BindingKeyword, identifier: IdentifierPatternSyntax, type: Property.VariableType, initialized: InitializedStatus)],
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let memberList = try Self.createMemberList(variableSources)
        let actualProperties = VariableHelper.getStoredProperties(from: memberList)
        let expectedProperties = properties.map({ Property(bindingKeyword: $0.0, identifierPattern: $0.1, type: $0.2, isInitialized: $0.3.isInitialized) })
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

    private static func assertThrowsError<T, ErrorType: Error & Equatable>(
        _ expression: @autoclosure () throws -> T,
        _ expectedError: ErrorType,
        file: StaticString = #filePath,
        line: UInt = #line) {
            var error: Error?
            XCTAssertThrowsError(try expression(), file: file, line: line) { error = $0 }
            guard let error = error as? ErrorType else {
                XCTFail("Thrown error does not match expected error type")
                return
            }
            XCTAssertEqual(error, expectedError)
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

extension IdentifierPatternSyntax: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.init(identifier: .identifier(value))
    }
}

extension Property.VariableType: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        var parser = Parser(value)
        self = .explicit(typeNode: TypeSyntax.parse(from: &parser))
    }
}
