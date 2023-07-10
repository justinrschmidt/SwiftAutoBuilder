import AutoValue

let a = 17
let b = 25

let (result, code) = #stringify(a + b)

print("The value \(result) was produced by the code \"\(code)\"")

@AutoValue
struct Foo {
	let a: Int = 0
}
