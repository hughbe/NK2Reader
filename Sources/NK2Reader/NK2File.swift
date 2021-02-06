//
//  NK2FileTests.swift
//  
//
//  Created by Hugh Bellamy on 27/10/2020.
//

import DataStream
import Foundation
import MAPI
import WindowsDataTypes

/// https://docs.microsoft.com/en-us/office/client-developer/outlook/mapi/autocomplete-stream
public struct NK2File {
    private let metadata: UInt32
    private let majorVersionNumber: UInt32
    private let minorVersionNumber: UInt32
    private let rowSet: RowSet
    private let extraInformation: [UInt8]
    private let lastModificationTime: Date
    public var rows: [Row] {
        return rowSet.rows
    }
    
    public init(data: Data) throws {
        var dataStream = DataStream(data)
        try self.init(dataStream: &dataStream)
    }
    
    public init(dataStream: inout DataStream) throws {
        /// Metadata 4
        self.metadata = try dataStream.read(endianess: .littleEndian)
        guard self.metadata == 0xBAADF00D else {
            throw NK2ReadError.invalidSignature(signature: self.metadata)
        }
        
        /// Major Version Number 4
        self.majorVersionNumber = try dataStream.read(endianess: .littleEndian)
        
        /// Minor Version Number 4
        self.minorVersionNumber = try dataStream.read(endianess: .littleEndian)

        /// Row-set Variable
        self.rowSet = try RowSet(dataStream: &dataStream)

        /// Extra information byte count EI 4
        let extraInformationByteCount: UInt32 = try dataStream.read(endianess: .littleEndian)
        
        /// Extra information EI
        self.extraInformation = try dataStream.readBytes(count: Int(extraInformationByteCount))
        
        /// Metadata 8
        /// Last written/modification date and time
        self.lastModificationTime = try FILETIME(dataStream: &dataStream).date
    }
    
    /// https://docs.microsoft.com/en-us/office/client-developer/outlook/mapi/autocomplete-stream
    /// Row-set Layout
    /// The row-set layout is as follows:
    /// The number of rows identifies how many rows come in the next part of the binary stream sequence.
    private struct RowSet {
        public let rows: [Row]
        
        public init(dataStream: inout DataStream) throws {
            /// Number of rows 4
            let numberOfRows: UInt32 = try dataStream.read(endianess: .littleEndian)
            
            var rows: [Row] = []
            rows.reserveCapacity(Int(numberOfRows))
            for _ in 0..<numberOfRows {
                let row = try Row(dataStream: &dataStream)
                rows.append(row)
            }
            
            self.rows = rows
        }
    }

    /// https://docs.microsoft.com/en-us/office/client-developer/outlook/mapi/autocomplete-stream
    /// Row Layout
    /// Each row is of the following format:
    /// The number of properties identifies how many properties come in the next part of the binary stream sequence.
    /// http://portalvhds6gyn3khqwmgzd.blob.core.windows.net/files/NK2/NK2WithBinaryExample.pdf
    public struct Row: MessageStorage {
        internal let properties: [UInt16: Any?]
        
        fileprivate init(dataStream: inout DataStream) throws {            
            /// Number of properties 4
            let numberOfProperties: UInt32 = try dataStream.read(endianess: .littleEndian)
            
            /// Properties Variable
            var properties: [UInt16: Any?] = [:]
            properties.reserveCapacity(Int(numberOfProperties))
            for _ in 0..<numberOfProperties {
                let property = try Property(dataStream: &dataStream)
                properties[property.tag.id] = property.value
            }
            
            self.properties = properties
        }
        
        public func getProperty<T>(id: UInt16) -> T? {
            return properties[id] as? T
        }

        public func getProperty<T>(name: NamedProperty) -> T? {
            fatalError("Named properties are not supported in NK2 files")
        }
    }
    
    /// https://docs.microsoft.com/en-us/office/client-developer/outlook/mapi/autocomplete-stream
    /// Property Layout
    /// Each property is of the following format:
    private struct Property {
        public let tag: PropertyTag
        public let value: Any?
        
        public init(dataStream: inout DataStream) throws {
            /// Property Tag 4
            /// The Property Value Union and the Value Data are to be interpreted based on the property tag in the first 4 bytes of the property
            /// block. This property tag is in the same format as a MAPI property tag. Bits 0 through 15 of the property tag are the property's
            /// type. Bits 16 through 31 are the property's identifier. The property type determines how the rest of the property should be read.
            let tag = try PropertyTag(dataStream: &dataStream)
            self.tag = tag
            
            /// Reserved Data 4
            let _: UInt32 = try dataStream.read(endianess: .littleEndian)
            
            /// Property Value Union 8
            let propertyValueUnion: UInt64 = try dataStream.read(endianess: .littleEndian)
            
            func reinterpret_cast<T>(to: T.Type) -> T {
                var data = propertyValueUnion
                return withUnsafePointer(to: &data) {
                    $0.withMemoryRebound(to: to, capacity: 1) {
                        $0.pointee
                    }
                }
            }
            
            /// Static Value
            /// Some properties have no Value Data and only have data in the union. The following property types (which come from the
            /// Property Tag) should interpret the 8-byte Property Union data as follows:
            /// Dynamic Values
            /// Other properties have data in a Value Data block after the first 16 bytes that contain the Property Tag, the Reserved Data,
            /// and the Property Value Union. Unlike static values, the data that is stored in the 8-byte Property Value union is irrelevant on
            /// reading. When writing, make sure that you fill these 8 bytes with something. However, the content of the 8 bytes is not
            /// important. In dynamic values, the property tag's type determines how to interpret the Value Data.
            switch self.tag.type {
            case .integer16:
                /// PT_I2
                /// short int
                self.value = reinterpret_cast(to: UInt16.self)
            case .integer32:
                /// PT_LONG
                /// long
                self.value = reinterpret_cast(to: UInt32.self)
            case .floating32:
                /// PT_R4
                /// float
                self.value = reinterpret_cast(to: Float.self)
            case .floating64:
                /// PT_DOUBLE
                /// double
                self.value = reinterpret_cast(to: Double.self)
            case .boolean:
                /// PT_BOOLEAN
                /// short int
                self.value = reinterpret_cast(to: UInt16.self) != 00
            case .time:
                /// PT_SYSTIME
                /// FILETIME
                self.value = reinterpret_cast(to: FILETIME.self).date
            case .integer64:
                /// PT_I8
                /// LARGE_INTEGER
                self.value = propertyValueUnion
            case .string8:
                /// PT_STRING8
                /// Number of bytes n 4
                let numberOfBytes: UInt32 = try dataStream.read(endianess: .littleEndian)
                
                /// Bytes to be interpreted as an ANSI string (includes NULL terminator) n
                self.value = try dataStream.readString(count: Int(numberOfBytes) - 1, encoding: .ascii)!
                dataStream.position += 1
            case .string:
                /// PT_UNICODE
                /// Number of bytes n 4
                let numberOfBytes: UInt32 = try dataStream.read(endianess: .littleEndian)
                
                /// Bytes to be interpreted as an UNICODE string (includes NULL terminator) n
                self.value = try dataStream.readString(count: Int(numberOfBytes) - 2, encoding: .utf16LittleEndian)!
                dataStream.position += 2
            case .guid:
                /// PT_CLSID
                /// Bytes to be interpreted as a GUID 16
                self.value = try GUID(dataStream: &dataStream)
            case .binary:
                /// PT_BINARY
                /// Number of bytes n 4
                let numberOfBytes: UInt32 = try dataStream.read(endianess: .littleEndian)
                
                /// Bytes to be interpreted as a byte array n
                self.value = Data(try dataStream.readBytes(count: Int(numberOfBytes)))
            case .errorCode:
                self.value = reinterpret_cast(to: UInt32.self)
            case .multipleBinary:
                /// PT_MV_BINARY
                /// Number of binary arrays X 4
                let numberOfBinaryArrays: UInt32 = try dataStream.read(endianess: .littleEndian)
                
                /// A run of bytes that contains X binary arrays. Each array should be interpreted exactly like the PT_BINARY byte run.
                var results: [Data] = []
                results.reserveCapacity(Int(numberOfBinaryArrays))
                for _ in 0..<numberOfBinaryArrays {
                    /// PT_BINARY
                    /// Number of bytes n 4
                    let numberOfBytes: UInt32 = try dataStream.read(endianess: .littleEndian)
                    
                    /// Bytes to be interpreted as a byte array n
                    let result = Data(try dataStream.readBytes(count: Int(numberOfBytes)))
                    results.append(result)
                }
                
                self.value = results
            case .multipleString8:
                /// PT_MV_STRING8 (Outlook 2007, Outlook 2010, and Outlook 2013)
                /// Number of ANSI strings X 4
                let numberOfAnsiStrings: UInt32 = try dataStream.read(endianess: .littleEndian)
                
                /// A run of bytes that contains X ANSI strings. Each string should be interpreted exactly like the PT_STRING8 byte run.
                var results: [String] = []
                results.reserveCapacity(Int(numberOfAnsiStrings))
                for _ in 0..<numberOfAnsiStrings {
                    /// PT_STRING8
                    /// Number of bytes n 4
                    let numberOfBytes: UInt32 = try dataStream.read(endianess: .littleEndian)
                    
                    /// Bytes to be interpreted as an ANSI string (includes NULL terminator) n
                    let result = try dataStream.readString(count: Int(numberOfBytes) - 1, encoding: .ascii)!
                    dataStream.position += 1
                    results.append(result)
                }
                
                self.value = results
            case .multipleString:
                /// PT_MV_UNICODE (Outlook 2007, Outlook 2010, Outlook 2013)
                /// Number of UNICODE strings X 4
                let numberOfUnicodeStrings: UInt32 = try dataStream.read(endianess: .littleEndian)
                
                /// A run of bytes that contains X UNICODE strings. Each string should be interpreted exactly like the PT_UNICODE byte run.
                var results: [String] = []
                results.reserveCapacity(Int(numberOfUnicodeStrings))
                for _ in 0..<numberOfUnicodeStrings {
                    /// PT_UNICODE
                    /// Number of bytes n 4
                    let numberOfBytes: UInt32 = try dataStream.read(endianess: .littleEndian)
                    
                    /// Bytes to be interpreted as an UNICODE string (includes NULL terminator) n
                    let result = try dataStream.readString(count: Int(numberOfBytes) - 2, encoding: .utf16LittleEndian)!
                    dataStream.position += 2
                    results.append(result)
                }
                
                self.value = results
            case .null:
                self.value = nil
            default:
                fatalError("NYI: \(tag.type)")
            }
        }
    }
}
