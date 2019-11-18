//
//  MiaomiaoTestMessage.swift
//  MiaomiaoClient
//
//  Created by Bjørn Inge Berg on 26/09/2019.
//  Copyright © 2019 Mark Wilson. All rights reserved.
//

import Foundation

func sensorTestData() -> SensorData {
    let b64 = "p/g4FQMAAAAAAAAAAAAAAAAAAAAAAAAAhvINA9AEyISZAN4EyLCZAN8EiLKZAOAEyLhZAN8EiH4ZgNwEyHCZANgEyGyZANcEyFyZANgEyGSZAMsEyGhZAL4EyHBZALgEyHBZAK8EyFxZANcEyEyZAM8EyFSZAMgEyFBZALcEyGBaAJwEyNxZAMQEyExZAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD0AAACU4AABBgevUBQHloBaAO2mDmoayASfuW4="

    let temp: [UInt8] = [UInt8](Data(base64Encoded: b64)!)
     return SensorData(uuid: "0123".data(using: .ascii)!, bytes: temp)!
}
