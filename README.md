# NK2Reader

NK2Reader is a reader of Outlook autocomplete streams (nk2 files).

## Example Usage

Add the following line to your project's SwiftPM dependencies:
```swift
.package(url: "https://github.com/hughbe/NK2Reader", from: "1.0.0"),
```

```swift
import NK2Reader

let data = Data(contentsOfFile: "<path-to-file>.nk2")!
let file = try NK2File(data: data)
for row in files.rows {
    print(row.displayName!)
}
```
