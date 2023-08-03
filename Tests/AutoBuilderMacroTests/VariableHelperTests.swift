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

    func testConstantDeclaration_simple_getProperties() {
        assertGetStoredProperties("let a: Int", [
            (.stored, .iVar, .let, "a", .explicit(typeNode: "Int"), .uninitialized)
        ])
    }

    func testConstantDeclaration_simpleStatic_getProperties() {
        assertGetStoredProperties("static let a: Int", [
            (.stored, .static, .let, "a", .explicit(typeNode: "Int"), .uninitialized)
        ])
    }

    func testConstantDeclaration_simpleClass_getProperties() {
        assertGetStoredProperties("class let a: Int", [
            (.stored, .static, .let, "a", .explicit(typeNode: "Int"), .uninitialized)
        ])
    }

    func testConstantDeclaration_init_getProperties() {
        assertGetStoredProperties("let a: Int = 0", [
            (.stored, .iVar, .let, "a", .explicit(typeNode: "Int"), .initialized)
        ])
    }

    func testConstantDeclaration_listInline_getProperties() {
        assertGetStoredProperties("let a: Int, b: Double", [
            (.stored, .iVar, .let, "a", .explicit(typeNode: "Int"), .uninitialized),
            (.stored, .iVar, .let, "b", .explicit(typeNode: "Double"), .uninitialized)
        ])
    }

    func testConstantDeclaration_listTrailing_getProperties() {
        assertGetStoredProperties("let a, b: Int", [
            (.stored, .iVar, .let, "a", .explicit(typeNode: "Int"), .uninitialized),
            (.stored, .iVar, .let, "b", .explicit(typeNode: "Int"), .uninitialized)
        ])
    }

    func testConstantDeclaration_initList_getProperties() {
        assertGetStoredProperties("let a: Int = 1, b: Double = 2", [
            (.stored, .iVar, .let, "a", .explicit(typeNode: "Int"), .initialized),
            (.stored, .iVar, .let, "b", .explicit(typeNode: "Double"), .initialized)
        ])
    }

    func testConstantDeclaration_tuple_getProperties() {
        assertGetStoredProperties("let (a, b): (Int, Double)", [
            (.stored, .iVar, .let, "a", .explicit(typeNode: "Int"), .uninitialized),
            (.stored, .iVar, .let, "b", .explicit(typeNode: "Double"), .uninitialized)
        ])
    }

    func testConstantDeclaration_tupleStatic_getProperties() {
        assertGetStoredProperties("static let (a, b): (Int, Double)", [
            (.stored, .static, .let, "a", .explicit(typeNode: "Int"), .uninitialized),
            (.stored, .static, .let, "b", .explicit(typeNode: "Double"), .uninitialized)
        ])
    }

    func testConstantDeclaration_tupleClass_getProperties() {
        assertGetStoredProperties("class let (a, b): (Int, Double)", [
            (.stored, .static, .let, "a", .explicit(typeNode: "Int"), .uninitialized),
            (.stored, .static, .let, "b", .explicit(typeNode: "Double"), .uninitialized)
        ])
    }

    func testConstantDeclaration_initTuple_getProperties() {
        assertGetStoredProperties("let (a, b): (Int, Double) = (1, 2.3)", [
            (.stored, .iVar, .let, "a", .explicit(typeNode: "Int"), .initialized),
            (.stored, .iVar, .let, "b", .explicit(typeNode: "Double"), .initialized)
        ])
    }

    func testConstantDeclaration_tupleType_getProperties() {
        assertGetStoredProperties("let a: (Int, Double)", [
            (.stored, .iVar, .let, "a", .explicit(typeNode: "(Int, Double)"), .uninitialized)
        ])
    }

    func testConstantDeclaration_tupleWithComplexTypes_getProperties() {
        assertGetStoredProperties("let (a, b): (Int, (Double, String))", [
            (.stored, .iVar, .let, "a", .explicit(typeNode: "Int"), .uninitialized),
            (.stored, .iVar, .let, "b", .explicit(typeNode: "(Double, String)"), .uninitialized)
        ])
    }

    func testConstantDeclaration_listMixedTrailingInline_getProperties() {
        assertGetStoredProperties("let a, b: Int, c: Double", [
            (.stored, .iVar, .let, "a", .explicit(typeNode: "Int"), .uninitialized),
            (.stored, .iVar, .let, "b", .explicit(typeNode: "Int"), .uninitialized),
            (.stored, .iVar, .let, "c", .explicit(typeNode: "Double"), .uninitialized)
        ])
    }

    func testConstantDeclaration_initListMixedInlineTrailing_getProperties() {
        assertGetStoredProperties("let a: Int = 0, b, c: Double", [
            (.stored, .iVar, .let, "a", .explicit(typeNode: "Int"), .initialized),
            (.stored, .iVar, .let, "b", .explicit(typeNode: "Double"), .uninitialized),
            (.stored, .iVar, .let, "c", .explicit(typeNode: "Double"), .uninitialized)
        ])
    }

    func testConstantDeclaration_listMixedTupleSimple_getProperties() {
        assertGetStoredProperties("let (a, b): (Int, Double), c: String", [
            (.stored, .iVar, .let, "a", .explicit(typeNode: "Int"), .uninitialized),
            (.stored, .iVar, .let, "b", .explicit(typeNode: "Double"), .uninitialized),
            (.stored, .iVar, .let, "c", .explicit(typeNode: "String"), .uninitialized)
        ])
    }

    func testConstantDeclaration_nestedTuple_getProperties() {
        assertGetStoredProperties("let (a, (b, c)): (Int, (Double, String))", [
            (.stored, .iVar, .let, "a", .explicit(typeNode: "Int"), .uninitialized),
            (.stored, .iVar, .let, "b", .explicit(typeNode: "Double"), .uninitialized),
            (.stored, .iVar, .let, "c", .explicit(typeNode: "String"), .uninitialized)
        ])
    }

    func testConstantDeclaration_genericType_getProperties() {
        assertGetStoredProperties("let a: Foo<Int>", [
            (.stored, .iVar, .let, "a", .explicit(typeNode: "Foo<Int>"), .uninitialized)
        ])
    }

    func testConstantDeclaration_arrayLiteralType_getProperties() {
        assertGetStoredProperties("let a: [Int]", [
            (.stored, .iVar, .let, "a", .array(elementType: "Int"), .uninitialized)
        ])
    }

    func testConstantDeclaration_arrayGenericType_getProperties() {
        assertGetStoredProperties("let a: Array<Int>", [
            (.stored, .iVar, .let, "a", .array(elementType: "Int"), .uninitialized)
        ])
    }

    func testConstantDeclaration_dictionaryLiteralType_getProperties() {
        assertGetStoredProperties("let a: [Int:Double]", [
            (.stored, .iVar, .let, "a", .dictionary(keyType: "Int", valueType: "Double"), .uninitialized)
        ])
    }

    func testConstantDeclaration_dictionaryGenericType_getProperties() {
        assertGetStoredProperties("let a: Dictionary<Int, Double>", [
            (.stored, .iVar, .let, "a", .dictionary(keyType: "Int", valueType: "Double"), .uninitialized)
        ])
    }

    func testConstantDeclaration_setGenericType_getProperties() {
        assertGetStoredProperties("let a: Set<Int>", [
            (.stored, .iVar, .let, "a", .set(elementType: "Int"), .uninitialized)
        ])
    }

    // MARK: Get Stored Properties Variable Declarations

    func testVariableDeclaration_simple_getProperties() {
        assertGetStoredProperties("var a: Int", [
            (.stored, .iVar, .var, "a", .explicit(typeNode: "Int"), .uninitialized)
        ])
    }

    func testVariableDeclaration_simpleStatic_getProperties() {
        assertGetStoredProperties("static var a: Int", [
            (.stored, .static, .var, "a", .explicit(typeNode: "Int"), .uninitialized)
        ])
    }

    func testVariableDeclaration_simpleClass_getProperties() {
        assertGetStoredProperties("class var a: Int", [
            (.stored, .static, .var, "a", .explicit(typeNode: "Int"), .uninitialized)
        ])
    }

    func testVariableDeclaration_init_getProperties() {
        assertGetStoredProperties("var a: Int = 0", [
            (.stored, .iVar, .var, "a", .explicit(typeNode: "Int"), .initialized)
        ])
    }

    func testVariableDeclaration_listInline_getProperties() {
        assertGetStoredProperties("var a: Int, b: Double", [
            (.stored, .iVar, .var, "a", .explicit(typeNode: "Int"), .uninitialized),
            (.stored, .iVar, .var, "b", .explicit(typeNode: "Double"), .uninitialized)
        ])
    }

    func testVariableDeclaration_listTrailing_getProperties() {
        assertGetStoredProperties("var a, b: Int", [
            (.stored, .iVar, .var, "a", .explicit(typeNode: "Int"), .uninitialized),
            (.stored, .iVar, .var, "b", .explicit(typeNode: "Int"), .uninitialized)
        ])
    }

    func testVariableDeclaration_initList_getProperties() {
        assertGetStoredProperties("var a: Int = 1, b: Double = 2", [
            (.stored, .iVar, .var, "a", .explicit(typeNode: "Int"), .initialized),
            (.stored, .iVar, .var, "b", .explicit(typeNode: "Double"), .initialized)
        ])
    }

    func testVariableDeclaration_tuple_getProperties() {
        assertGetStoredProperties("var (a, b): (Int, Double)", [
            (.stored, .iVar, .var, "a", .explicit(typeNode: "Int"), .uninitialized),
            (.stored, .iVar, .var, "b", .explicit(typeNode: "Double"), .uninitialized)
        ])
    }

    func testVariableDeclaration_tupleStatic_getProperties() {
        assertGetStoredProperties("static var (a, b): (Int, Double)", [
            (.stored, .static, .var, "a", .explicit(typeNode: "Int"), .uninitialized),
            (.stored, .static, .var, "b", .explicit(typeNode: "Double"), .uninitialized)
        ])
    }

    func testVariableDeclaration_tupleClass_getProperties() {
        assertGetStoredProperties("class var (a, b): (Int, Double)", [
            (.stored, .static, .var, "a", .explicit(typeNode: "Int"), .uninitialized),
            (.stored, .static, .var, "b", .explicit(typeNode: "Double"), .uninitialized)
        ])
    }

    func testVariableDeclaration_initTuple_getProperties() {
        assertGetStoredProperties("var (a, b): (Int, Double) = (1, 2.3)", [
            (.stored, .iVar, .var, "a", .explicit(typeNode: "Int"), .initialized),
            (.stored, .iVar, .var, "b", .explicit(typeNode: "Double"), .initialized)
        ])
    }

    func testVariableDeclaration_tupleType_getProperties() {
        assertGetStoredProperties("var a: (Int, Double)", [
            (.stored, .iVar, .var, "a", .explicit(typeNode: "(Int, Double)"), .uninitialized)
        ])
    }

    func testVariableDeclaration_tupleWithComplexTypes_getProperties() {
        assertGetStoredProperties("var (a, b): (Int, (Double, String))", [
            (.stored, .iVar, .var, "a", .explicit(typeNode: "Int"), .uninitialized),
            (.stored, .iVar, .var, "b", .explicit(typeNode: "(Double, String)"), .uninitialized)
        ])
    }

    func testVariableDeclaration_willSetAccessorBlock_getProperties() {
        assertGetStoredProperties("var a: Int { willSet { print(\"will set\") } }", [
            (.stored, .iVar, .var, "a", .explicit(typeNode: "Int"), .uninitialized)
        ])
    }

    func testVariableDeclaration_didSetAccessorBlock_getProperties() {
        assertGetStoredProperties("var a: Int { didSet { print(\"did set\") }", [
            (.stored, .iVar, .var, "a", .explicit(typeNode: "Int"), .uninitialized)
        ])
    }

    func testVariableDeclaration_willSetAndDidSetAccessorBlocks_getProperties() {
        assertGetStoredProperties("var a: Int { willSet { print(\"willSet\") } didSet { print(\"did set\") } }", [
            (.stored, .iVar, .var, "a", .explicit(typeNode: "Int"), .uninitialized)
        ])
    }

    func testVariableDeclaration_listMixedTrailingInline_getProperties() {
        assertGetStoredProperties("var a, b: Int, c: Double", [
            (.stored, .iVar, .var, "a", .explicit(typeNode: "Int"), .uninitialized),
            (.stored, .iVar, .var, "b", .explicit(typeNode: "Int"), .uninitialized),
            (.stored, .iVar, .var, "c", .explicit(typeNode: "Double"), .uninitialized)
        ])
    }

    func testVariableDeclaration_initListMixedInlineTrailing_getProperties() {
        assertGetStoredProperties("var a: Int = 0, b, c: Double", [
            (.stored, .iVar, .var, "a", .explicit(typeNode: "Int"), .initialized),
            (.stored, .iVar, .var, "b", .explicit(typeNode: "Double"), .uninitialized),
            (.stored, .iVar, .var, "c", .explicit(typeNode: "Double"), .uninitialized)
        ])
    }

    func testVariableDeclaration_listMixedTupleSimple_getProperties() {
        assertGetStoredProperties("var (a, b): (Int, Double), c: Int", [
            (.stored, .iVar, .var, "a", .explicit(typeNode: "Int"), .uninitialized),
            (.stored, .iVar, .var, "b", .explicit(typeNode: "Double"), .uninitialized),
            (.stored, .iVar, .var, "c", .explicit(typeNode: "Int"), .uninitialized)
        ])
    }

    func testVariableDeclaration_nestedTuple_getProperties() {
        assertGetStoredProperties("var (a, (b, c)): (Int, (Int, Double))", [
            (.stored, .iVar, .var, "a", .explicit(typeNode: "Int"), .uninitialized),
            (.stored, .iVar, .var, "b", .explicit(typeNode: "Int"), .uninitialized),
            (.stored, .iVar, .var, "c", .explicit(typeNode: "Double"), .uninitialized)
        ])
    }

    func testVariableDeclaration_genericType_getProperties() {
        assertGetStoredProperties("var a: Foo<Int>", [
            (.stored, .iVar, .var, "a", .explicit(typeNode: "Foo<Int>"), .uninitialized)
        ])
    }

    func testVariableDeclaration_arrayLiteralType_getProperties() {
        assertGetStoredProperties("var a: [Int]", [
            (.stored, .iVar, .var, "a", .array(elementType: "Int"), .uninitialized)
        ])
    }

    func testVariableDeclaration_arrayGenericType_getProperties() {
        assertGetStoredProperties("var a: Array<Int>", [
            (.stored, .iVar, .var, "a", .array(elementType: "Int"), .uninitialized)
        ])
    }

    func testVariableDeclaration_dictionaryLiteralType_getProperties() {
        assertGetStoredProperties("var a: [Int:Double]", [
            (.stored, .iVar, .var, "a", .dictionary(keyType: "Int", valueType: "Double"), .uninitialized)
        ])
    }

    func testVariableDeclaration_dictionaryGenericType_getProperties() {
        assertGetStoredProperties("var a: Dictionary<Int, Double>", [
            (.stored, .iVar, .var, "a", .dictionary(keyType: "Int", valueType: "Double"), .uninitialized)
        ])
    }

    func testVariableDeclaration_setGenericType_getProperties() {
        assertGetStoredProperties("var a: Set<Int>", [
            (.stored, .iVar, .var, "a", .set(elementType: "Int"), .uninitialized)
        ])
    }

    // MARK: Get Computed Properties Variable Declarations

    func testVariableDeclaration_codeBlock_getProperties() {
        assertGetStoredProperties("var a: Int { return 0 }", [
            (.computed, .iVar, .var, "a", .explicit(typeNode: "Int"), .uninitialized)
        ])
    }

    func testVariableDeclaration_getAccessorBlock_getProperties() {
        assertGetStoredProperties("var a: Int { get { return b } }", [
            (.computed, .iVar, .var, "a", .explicit(typeNode: "Int"), .uninitialized)
        ])
    }

    func testVariableDeclaration_getAndSetAccessorBlocks_getProperties() {
        assertGetStoredProperties("var a: Int { get { return b } set { b = newValue } }", [
            (.computed, .iVar, .var, "a", .explicit(typeNode: "Int"), .uninitialized)
        ])
    }

    // MARK: Get Stored and Computed Properties Mixed Declarations

    func testMixedDeclarations_getProperties() {
        assertGetStoredProperties([
            "let a: Int",
            "var b: Double",
            "var c: String { return \"c\" }",
            "var d: Float"
        ], [
            (.stored, .iVar, .let, "a", .explicit(typeNode: "Int"), .uninitialized),
            (.stored, .iVar, .var, "b", .explicit(typeNode: "Double"), .uninitialized),
            (.computed, .iVar, .var, "c", .explicit(typeNode: "String"), .uninitialized),
            (.stored, .iVar, .var, "d", .explicit(typeNode: "Float"), .uninitialized)
        ])
    }

    // MARK: Get Stored Properties Implied Types

    func testVariableDeclaration_impliedSimpleTypeInit_getProperties() {
        assertGetStoredProperties("var a = 0", [
            (.stored, .iVar, .var, "a", .implicit, .initialized)
        ])
    }

    func testVariableDeclaration_impliedEnumTypeInit_getProperties() {
        assertGetStoredProperties("var a = (1, 2.0)", [
            (.stored, .iVar, .var, "a", .implicit, .initialized)
        ])
    }

    func testVariableDeclaration_impliedEnumDeclarationTypeInit_getProperties() {
        assertGetStoredProperties("var (a, b) = (1, 2.0)", [
            (.stored, .iVar, .var, "a", .implicit, .initialized),
            (.stored, .iVar, .var, "b", .implicit, .initialized)
        ])
    }

    func testVariableDeclaration_impliedTypeList_getProperties() {
        assertGetStoredProperties("var a = 0, b = 1.0", [
            (.stored, .iVar, .var, "a", .implicit, .initialized),
            (.stored, .iVar, .var, "b", .implicit, .initialized)
        ])
    }

    func testVariableDeclaration_impliedTypeListMixed_getProperties() {
        assertGetStoredProperties("var a = 0, b: String", [
            (.stored, .iVar, .var, "a", .implicit, .initialized),
            (.stored, .iVar, .var, "b", .explicit(typeNode: "String"), .uninitialized)
        ])
    }

    // MARK: - Util

    private func assertGetStoredProperties(
        _ variableSource: String,
        _ properties: [(
            storedStatus: StoredStatus,
            iVarStatus: IVarStatus,
            bindingKeyword: Property.BindingKeyword,
            identifier: IdentifierPatternSyntax,
            type: VariableTypeDescriptor,
            initialized: InitializedStatus)],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        assertGetStoredProperties([variableSource], properties, file: file, line: line)
    }

    private func assertGetStoredProperties(
        _ variableSources: [String],
        _ properties: [(
            storedStatus: StoredStatus,
            iVarStatus: IVarStatus,
            bindingKeyword: Property.BindingKeyword,
            identifier: IdentifierPatternSyntax,
            type: VariableTypeDescriptor,
            initialized: InitializedStatus)],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let memberList = Self.createMemberList(variableSources)
        let actualProperties = VariableHelper.getProperties(from: memberList)
        let expectedProperties = properties.map({ Property(
            isStoredProperty: $0.0.isStored,
            isIVar: $0.1.isIVar,
            bindingKeyword: $0.2,
            identifierPattern: $0.3,
            type: $0.4.variableType,
            isInitialized: $0.5.isInitialized)
        })
        XCTAssertEqual(actualProperties, expectedProperties, file: file, line: line)
    }

    private static func createMemberList(_ variableSources: [String]) -> MemberDeclListSyntax {
        return MemberDeclListSyntax {
            for source in variableSources {
                VariableDeclSyntax(declString: source)
            }
        }
    }

    private enum StoredStatus {
        case stored
        case computed

        var isStored: Bool {
            switch self {
            case .stored:
                return true
            case .computed:
                return false
            }
        }
    }

    private enum IVarStatus {
        case iVar
        case `static`

        var isIVar: Bool {
            switch self {
            case .iVar:
                return true
            case .static:
                return false
            }
        }
    }

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

    private enum VariableTypeDescriptor {
        case implicit
        case array(elementType: String)
        case dictionary(keyType: String, valueType: String)
        case set(elementType: String)
        case explicit(typeNode: String)

        var variableType: Property.VariableType {
            switch self {
            case .implicit:
                return .implicit
            case let .array(elementType):
                return .array(elementType: TypeSyntax(typeString: elementType))
            case let .dictionary(keyType, valueType):
                return .dictionary(keyType: TypeSyntax(typeString: keyType), valueType: TypeSyntax(typeString: valueType))
            case let .set(elementType):
                return .set(elementType: TypeSyntax(typeString: elementType))
            case let .explicit(typeNode):
                return .explicit(typeNode: TypeSyntax(typeString: typeNode))
            }
        }
    }
}

extension IdentifierPatternSyntax: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.init(identifier: .identifier(value))
    }
}

extension TypeSyntax {
    init(typeString: String) {
        var parser = Parser(typeString)
        self.init(TypeSyntax.parse(from: &parser))
    }
}

extension VariableDeclSyntax {
    init(declString: String) {
        var parser = Parser(declString)
        self.init(DeclSyntax.parse(from: &parser))!
    }
}
