// The Swift Programming Language
// https://docs.swift.org/swift-book

@attached(member, names: named(Builder), named(init(with:)))
public macro AutoValue() = #externalMacro(module: "AutoValueMacros", type: "AutoValueMacro")
