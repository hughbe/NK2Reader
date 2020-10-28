# NK2Reader

NK2Reader is a reader of Outlook autocomplete streams (nk2 files).

Example Usage

```swift
let data = Data(contentsOfFile: "<path-to-file>.nk2")!
let file = try NK2File(data: data)
for row in files.rows {
    print(row.displayName!)
}
```
