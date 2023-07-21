// The Swift Programming Language
// https://docs.swift.org/swift-book

@attached(conformance)
@attached(member, names: named(Builder), named(init(with:)), named(toBuilder))
public macro AutoBuilder() = #externalMacro(module: "AutoBuilderMacros", type: "AutoBuilderMacro")
