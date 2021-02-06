import XCTest

import NK2ReaderTests

var tests = [XCTestCaseEntry]()
tests += DumpFileTests.allTests()
tests += NK2FileTests.allTests()
XCTMain(tests)
