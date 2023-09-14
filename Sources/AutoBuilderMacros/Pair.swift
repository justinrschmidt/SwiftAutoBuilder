struct Pair<T, U> {
    let a: T
    let b: U

    init(_ a: T, _ b: U) {
        self.a = a
        self.b = b
    }
}

extension Pair: Equatable where T: Equatable, U: Equatable {}
extension Pair: Hashable where T: Hashable, U: Hashable {}
