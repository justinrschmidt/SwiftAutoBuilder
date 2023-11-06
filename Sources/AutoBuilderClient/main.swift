import AutoBuilder

@Buildable
struct Foo {
    let a: Int
}

@Buildable
enum Bar {
    case one(a: Int)
    case two(b: Double, c: String)
    case three(Int, Double, String)
    case four
    case five(d: [Int], [Int])
    case six(e: [String: Int], [String: Int])
    case seven(f: Set<Int>, Set<Int>)
}
