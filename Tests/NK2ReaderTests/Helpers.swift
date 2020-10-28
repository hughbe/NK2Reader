//
//  Helpers.swift
//  
//
//  Created by Hugh Bellamy on 19/10/2020.
//

import Foundation

public func getData(name: String) throws -> Data {
    var name = name
    let urlExtension: String
    if name.hasSuffix(".NK2") {
        name = String(name.prefix(name.count - 4))
        urlExtension = "NK2"
    } else if name.hasSuffix(".dat") {
        name = String(name.prefix(name.count - 4))
        urlExtension = "dat"
    } else {
        urlExtension = "NK2"
    }
    
    let url = URL(forResource: name, withExtension: urlExtension)
    return try Data(contentsOf: url)
}
