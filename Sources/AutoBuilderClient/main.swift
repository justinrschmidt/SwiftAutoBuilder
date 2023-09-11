import AutoBuilder

@AutoBuilder
struct Foo {
	let a: Int
}

@AutoBuilder
enum Bar {
    case one(a: Int)
    case two(b: Double, c: String)
    case three(Int, Double, String)
    case four
    case five(d: [Int], [Int])
    case six(e: [String:Int])
    case seven(f: Set<Int>)
}
