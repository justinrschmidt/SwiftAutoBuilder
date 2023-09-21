extension String {
    var capitalized: String {
        guard !isEmpty else {
            return ""
        }
        return first!.uppercased() + self[index(after: startIndex)...]
    }
}
