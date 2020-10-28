//
//  NK2ReadError.swift
//  
//
//  Created by Hugh Bellamy on 27/10/2020.
//

public enum NK2ReadError: Error {
    case invalidSignature(signature: UInt32)
}
