import Testing

func expectEqual<T: Equatable>(_ lhs: @autoclosure () -> T, _ rhs: @autoclosure () -> T, _ message: @autoclosure () -> String = "") {
    let comment = message().isEmpty ? nil : Comment(rawValue: message())
    #expect(lhs() == rhs(), comment)
}

func expectTrue(_ condition: @autoclosure () -> Bool, _ message: @autoclosure () -> String = "") {
    let comment = message().isEmpty ? nil : Comment(rawValue: message())
    #expect(condition(), comment)
}

func expectFalse(_ condition: @autoclosure () -> Bool, _ message: @autoclosure () -> String = "") {
    let comment = message().isEmpty ? nil : Comment(rawValue: message())
    #expect(!condition(), comment)
}
