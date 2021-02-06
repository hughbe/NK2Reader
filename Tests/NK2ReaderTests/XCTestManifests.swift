import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(DumpFileTests.allTests),
        testCase(NK2FileTests.allTests),
    ]
}
#endif
