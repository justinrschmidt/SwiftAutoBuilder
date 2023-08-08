import SwiftParser
import SwiftSyntax
import SwiftSyntaxBuilder
import XCTest
@testable import AutoBuilderMacros

enum VariableHelperTestsError: Error {
    case invalidDeclSyntax
}

final class VariableHelperTests: XCTestCase {

    // MARK: Stored Properties Declarations

    func testGetProperties_simple_constantDeclaration() {
        assertGetStoredProperties("let a: Int", [
            (.stored, .iVar, .let, "a", .explicit(typeNode: "Int"), .uninitialized)
        ])
    }

    func testGetProperties_simple_variableDeclaration() {
        assertGetStoredProperties("var a: Int", [
            (.stored, .iVar, .var, "a", .explicit(typeNode: "Int"), .uninitialized)
        ])
    }

    func testGetProperties_simpleStatic() {
        assertGetStoredProperties("static var a: Int", [
            (.stored, .static, .var, "a", .explicit(typeNode: "Int"), .uninitialized)
        ])
    }

    func testGetProperties_simpleClass() {
        assertGetStoredProperties("class var a: Int", [
            (.stored, .static, .var, "a", .explicit(typeNode: "Int"), .uninitialized)
        ])
    }

    func testGetProperties_init_constantDeclaration() {
        assertGetStoredProperties("let a: Int = 0", [
            (.stored, .iVar, .let, "a", .explicit(typeNode: "Int"), .initialized)
        ])
    }

    func testGetProperties_init_variableDeclaration() {
        assertGetStoredProperties("var a: Int = 0", [
            (.stored, .iVar, .var, "a", .explicit(typeNode: "Int"), .initialized)
        ])
    }

    func testGetProperties_listInline() {
        assertGetStoredProperties("var a: Int, b: Double", [
            (.stored, .iVar, .var, "a", .explicit(typeNode: "Int"), .uninitialized),
            (.stored, .iVar, .var, "b", .explicit(typeNode: "Double"), .uninitialized)
        ])
    }

    func testGetProperties_listTrailing() {
        assertGetStoredProperties("var a, b: Int", [
            (.stored, .iVar, .var, "a", .explicit(typeNode: "Int"), .uninitialized),
            (.stored, .iVar, .var, "b", .explicit(typeNode: "Int"), .uninitialized)
        ])
    }

    func testGetProperties_initList() {
        assertGetStoredProperties("var a: Int = 1, b: Double = 2", [
            (.stored, .iVar, .var, "a", .explicit(typeNode: "Int"), .initialized),
            (.stored, .iVar, .var, "b", .explicit(typeNode: "Double"), .initialized)
        ])
    }

    func testGetProperties_tuple() {
        assertGetStoredProperties("var (a, b): (Int, Double)", [
            (.stored, .iVar, .var, "a", .explicit(typeNode: "Int"), .uninitialized),
            (.stored, .iVar, .var, "b", .explicit(typeNode: "Double"), .uninitialized)
        ])
    }

    func testGetProperties_tupleStatic() {
        assertGetStoredProperties("static var (a, b): (Int, Double)", [
            (.stored, .static, .var, "a", .explicit(typeNode: "Int"), .uninitialized),
            (.stored, .static, .var, "b", .explicit(typeNode: "Double"), .uninitialized)
        ])
    }

    func testGetProperties_tupleClass() {
        assertGetStoredProperties("class var (a, b): (Int, Double)", [
            (.stored, .static, .var, "a", .explicit(typeNode: "Int"), .uninitialized),
            (.stored, .static, .var, "b", .explicit(typeNode: "Double"), .uninitialized)
        ])
    }

    func testGetProperties_initTuple() {
        assertGetStoredProperties("var (a, b): (Int, Double) = (1, 2.3)", [
            (.stored, .iVar, .var, "a", .explicit(typeNode: "Int"), .initialized),
            (.stored, .iVar, .var, "b", .explicit(typeNode: "Double"), .initialized)
        ])
    }

    func testGetProperties_tupleType() {
        assertGetStoredProperties("var a: (Int, Double)", [
            (.stored, .iVar, .var, "a", .explicit(typeNode: "(Int, Double)"), .uninitialized)
        ])
    }

    func testGetProperties_tupleWithComplexTypes() {
        assertGetStoredProperties("var (a, b): (Int, (Double, String))", [
            (.stored, .iVar, .var, "a", .explicit(typeNode: "Int"), .uninitialized),
            (.stored, .iVar, .var, "b", .explicit(typeNode: "(Double, String)"), .uninitialized)
        ])
    }

    func testGetProperties_willSetAccessorBlock() {
        assertGetStoredProperties("var a: Int { willSet { print(\"will set\") } }", [
            (.stored, .iVar, .var, "a", .explicit(typeNode: "Int"), .uninitialized)
        ])
    }

    func testGetProperties_didSetAccessorBlock() {
        assertGetStoredProperties("var a: Int { didSet { print(\"did set\") }", [
            (.stored, .iVar, .var, "a", .explicit(typeNode: "Int"), .uninitialized)
        ])
    }

    func testGetProperties_willSetAndDidSetAccessorBlocks() {
        assertGetStoredProperties("var a: Int { willSet { print(\"willSet\") } didSet { print(\"did set\") } }", [
            (.stored, .iVar, .var, "a", .explicit(typeNode: "Int"), .uninitialized)
        ])
    }

    func testGetProperties_listMixedTrailingInline() {
        assertGetStoredProperties("var a, b: Int, c: Double", [
            (.stored, .iVar, .var, "a", .explicit(typeNode: "Int"), .uninitialized),
            (.stored, .iVar, .var, "b", .explicit(typeNode: "Int"), .uninitialized),
            (.stored, .iVar, .var, "c", .explicit(typeNode: "Double"), .uninitialized)
        ])
    }

    func testGetProperties_initListMixedInlineTrailing() {
        assertGetStoredProperties("var a: Int = 0, b, c: Double", [
            (.stored, .iVar, .var, "a", .explicit(typeNode: "Int"), .initialized),
            (.stored, .iVar, .var, "b", .explicit(typeNode: "Double"), .uninitialized),
            (.stored, .iVar, .var, "c", .explicit(typeNode: "Double"), .uninitialized)
        ])
    }

    func testGetProperties_listMixedTupleSimple() {
        assertGetStoredProperties("var (a, b): (Int, Double), c: Int", [
            (.stored, .iVar, .var, "a", .explicit(typeNode: "Int"), .uninitialized),
            (.stored, .iVar, .var, "b", .explicit(typeNode: "Double"), .uninitialized),
            (.stored, .iVar, .var, "c", .explicit(typeNode: "Int"), .uninitialized)
        ])
    }

    func testGetProperties_nestedTuple() {
        assertGetStoredProperties("var (a, (b, c)): (Int, (Int, Double))", [
            (.stored, .iVar, .var, "a", .explicit(typeNode: "Int"), .uninitialized),
            (.stored, .iVar, .var, "b", .explicit(typeNode: "Int"), .uninitialized),
            (.stored, .iVar, .var, "c", .explicit(typeNode: "Double"), .uninitialized)
        ])
    }

    func testGetProperties_genericType() {
        assertGetStoredProperties("var a: Foo<Int>", [
            (.stored, .iVar, .var, "a", .explicit(typeNode: "Foo<Int>"), .uninitialized)
        ])
    }

    func testGetProperties_arrayLiteralType() {
        assertGetStoredProperties("var a: [Int]", [
            (.stored, .iVar, .var, "a", .array(elementType: "Int"), .uninitialized)
        ])
    }

    func testGetProperties_arrayGenericType() {
        assertGetStoredProperties("var a: Array<Int>", [
            (.stored, .iVar, .var, "a", .array(elementType: "Int"), .uninitialized)
        ])
    }

    func testGetProperties_dictionaryLiteralType() {
        assertGetStoredProperties("var a: [Int:Double]", [
            (.stored, .iVar, .var, "a", .dictionary(keyType: "Int", valueType: "Double"), .uninitialized)
        ])
    }

    func testGetProperties_dictionaryGenericType() {
        assertGetStoredProperties("var a: Dictionary<Int, Double>", [
            (.stored, .iVar, .var, "a", .dictionary(keyType: "Int", valueType: "Double"), .uninitialized)
        ])
    }

    func testGetProperties_setGenericType() {
        assertGetStoredProperties("var a: Set<Int>", [
            (.stored, .iVar, .var, "a", .set(elementType: "Int"), .uninitialized)
        ])
    }

    // MARK: Computed Properties Declarations

    func testGetProperties_codeBlock() {
        assertGetStoredProperties("var a: Int { return 0 }", [
            (.computed, .iVar, .var, "a", .explicit(typeNode: "Int"), .uninitialized)
        ])
    }

    func testGetProperties_getAccessorBlock() {
        assertGetStoredProperties("var a: Int { get { return b } }", [
            (.computed, .iVar, .var, "a", .explicit(typeNode: "Int"), .uninitialized)
        ])
    }

    func testGetProperties_getAndSetAccessorBlocks() {
        assertGetStoredProperties("var a: Int { get { return b } set { b = newValue } }", [
            (.computed, .iVar, .var, "a", .explicit(typeNode: "Int"), .uninitialized)
        ])
    }

    // MARK: Stored and Computed Properties Mixed Declarations

    func testMixedDeclarations() {
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

    // MARK: Stored Properties Implied Types

    func testGetProperties_impliedSimpleTypeInit() {
        assertGetStoredProperties("var a = 0", [
            (.stored, .iVar, .var, "a", .implicit, .initialized)
        ])
    }

    func testGetProperties_impliedEnumTypeInit() {
        assertGetStoredProperties("var a = (1, 2.0)", [
            (.stored, .iVar, .var, "a", .implicit, .initialized)
        ])
    }

    func testGetProperties_impliedEnumDeclarationTypeInit() {
        assertGetStoredProperties("var (a, b) = (1, 2.0)", [
            (.stored, .iVar, .var, "a", .implicit, .initialized),
            (.stored, .iVar, .var, "b", .implicit, .initialized)
        ])
    }

    func testGetProperties_impliedTypeList() {
        assertGetStoredProperties("var a = 0, b = 1.0", [
            (.stored, .iVar, .var, "a", .implicit, .initialized),
            (.stored, .iVar, .var, "b", .implicit, .initialized)
        ])
    }

    func testGetProperties_impliedTypeListMixed() {
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
