import XCTest
import MAPI
@testable import NK2Reader

final class DumpFileTests: XCTestCase {
    static func dumpFile(accessor: String, file: NK2File) {
        var s = ""
        
        s += "XCTAssertEqual(\(file.rows.count), \(accessor).rows.count)\n"
        for (offset, element) in file.rows.enumerated() {
            s += propertiesTestString(accessor: "\(accessor).rows[\(offset)]", properties: element.properties, namedProperties: nil)
        }
        
        print(s)
    }
    
    func testDump() throws {
        for (name, fileExtension) in [
            ("hughbe_Outlook", "NK2"),
            ("Stream_Autocomplete_0_C46AC97B9CA2EF4197BE00D129BCCA43", "dat"),
            ("Stream_Autocomplete_0_DFE96F3C294B9243A8156DAF9CF76306", "dat"),
            ("plaso_Outlook", "NK2"),
        ] {
            let data = try getData(name: name, fileExtension: fileExtension)
            let file = try NK2File(data: data)
            DumpFileTests.dumpFile(accessor: "file", file: file)
        }
    }
    
    static var allTests = [
        ("testDump", testDump)
    ]
}
