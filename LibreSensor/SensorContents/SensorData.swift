//
//  SensorData
//  LibreMonitor
//
//  Created by Uwe Petersen on 26.07.16.
//  Copyright © 2016 Uwe Petersen. All rights reserved.
//

import Foundation

/// Structure for data from Freestyle Libre sensor
/// To be initialized with the bytes as read via nfc. Provides all derived data.
public struct SensorData: Codable {
    /// Parameters for the temperature compensation algorithm
    //let temperatureAlgorithmParameterSet: TemperatureAlgorithmParameters?

    /// The uid of the sensor
    let uuid: Data
    /// The serial number of the sensor
    let serialNumber: String
    /// Number of bytes of sensor data to be used (read only), i.e. 344 bytes (24 for header, 296 for body and 24 for footer)
    private let numberOfBytes = 344 // Header and body and footer of Freestyle Libre data (i.e. 40 blocks of 8 bytes)
    /// Array of 344 bytes as read via nfc
    let bytes: [UInt8]
    /// Subarray of 24 header bytes
    let header: [UInt8]
    /// Subarray of 296 body bytes
    let body: [UInt8]
    /// Subarray of 24 footer bytes
    let footer: [UInt8]
    /// Date when data was read from sensor
    let date: Date
    /// Minutes (approx) since start of sensor
    let minutesSinceStart: Int
    /// Maximum time in Minutes he sensor can be worn before it expires
    let maxMinutesWearTime: Int
    /// Index on the next block of trend data that the sensor will measure and store
    let nextTrendBlock: Int
    /// Index on the next block of history data that the sensor will create from trend data and store
    let nextHistoryBlock: Int
    /// true if all crc's are valid
    var hasValidCRCs: Bool {
        hasValidHeaderCRC && hasValidBodyCRC && hasValidFooterCRC
    }
    /// true if the header crc, stored in the first two header bytes, is equal to the calculated crc
    var hasValidHeaderCRC: Bool {
        Crc.hasValidCrc16InFirstTwoBytes(header)
    }
    /// true if the body crc, stored in the first two body bytes, is equal to the calculated crc
    var hasValidBodyCRC: Bool {
        Crc.hasValidCrc16InFirstTwoBytes(body)
    }
    /// true if the footer crc, stored in the first two footer bytes, is equal to the calculated crc
    var hasValidFooterCRC: Bool {
        Crc.hasValidCrc16InFirstTwoBytes(footer)
    }
    /// Footer crc needed for checking integrity of SwiftLibreOOPWeb response
    var footerCrc: UInt16 {
        Crc.crc16(Array(footer.dropFirst(2)), seed: 0xffff)
    }
    
    // the amount of minutes left before this sensor expires
    var minutesLeft: Int {
       maxMinutesWearTime - minutesSinceStart
    }

    /// Sensor state (ready, failure, starting etc.)
    var state: SensorState {
        SensorState(stateByte: header[4])
    }

    var isLikelyLibre1: Bool {
        if bytes.count > 23 {
            let subset = bytes[9...23]
            return !subset.contains(where: { $0 > 0 })
        }
        return false
    }

    var reverseFooterCRC: UInt16? {

        let b0 = UInt16(self.footer[1])
        let b1 = UInt16(self.footer[0])
        return (b0 << 8) | UInt16(b1)
    }

    //how to use this in a sensible way is still unknown
    struct CalibrationInfo {
      var i1: Int
      var i2: Int
      var i3: Double
      var i4: Double
      var i5: Double
      var i6: Double

    }


    //static func readBits(_ buffer: [UInt8], _ byteOffset: Int, _ bitOffset: Int, _ bitCount: Int) -> Int {

    var calibrationData : CalibrationInfo {
        let data = self.bytes
        let i1 = Self.readBits(data, 2, 0, 3)
        let i2 = Self.readBits(data, 2, 3, 0xa)
        let i3 = Double(Self.readBits(data, 0x150, 0, 8))
        let i4 = Double(Self.readBits(data, 0x150, 8, 0xe))
        let negativei3 = Self.readBits(data, 0x150, 0x21, 1) != 0
        let i5 = Double(Self.readBits(data, 0x150, 0x28, 0xc) << 2)
        let i6 = Double(Self.readBits(data, 0x150, 0x34, 0xc) << 2)
        
        return CalibrationInfo(i1: i1, i2: i2, i3: negativei3 ? -i3 : i3 , i4: i4, i5: i5, i6: i6)

    }

    fileprivate let aday = 86_400.0 //in seconds

    var humanReadableSensorAge: String {
        let days = TimeInterval(minutesSinceStart * 60) / aday
        return String(format: "%.2f", days) + " day(s)"

    }

    var humanReadableTimeLeft: String {
        let days = TimeInterval(minutesLeft * 60) / aday
        return String(format: "%.2f", days) + " day(s)"
    }



    var toJson : String {
        "[" + self.bytes.map{ String(format: "0x%02x", $0) }.joined(separator: ", ") + "]"
    }
    var toEcmaStatement : String {
        "var someFRAM=" + self.toJson + ";"
    }

    init?(bytes: [UInt8], date: Date = Date()) {
        self.init(uuid: Data(), bytes: bytes, date: date)
    }
    init?(uuid: Data, bytes: [UInt8], date: Date = Date()) {
        guard bytes.count == numberOfBytes else {
            return nil
        }
        self.bytes = bytes
        // we don't actually know when this reading was done, only that
        // it was produced within the last minute
        self.date = date.rounded(on: 1, .minute)

        let headerRange = 0..<24   //  24 bytes, i.e.  3 blocks a 8 bytes
        let bodyRange = 24..<320  // 296 bytes, i.e. 37 blocks a 8 bytes
        let footerRange = 320..<344  //  24 bytes, i.e.  3 blocks a 8 bytes

        self.header = Array(bytes[headerRange])
        self.body = Array(bytes[bodyRange])
        self.footer = Array(bytes[footerRange])

        self.nextTrendBlock = Int(body[2])
        self.nextHistoryBlock = Int(body[3])
        self.minutesSinceStart = Int(body[293]) << 8 + Int(body[292])
        self.maxMinutesWearTime = Int(footer[7]) << 8 + Int(footer[6])

        self.uuid = uuid

        self.serialNumber = SensorSerialNumber(withUID: uuid)?.serialNumber ?? "-"

        //self.temperatureAlgorithmParameterSet = derivedAlgorithmParameterSet

        guard 0 <= nextTrendBlock && nextTrendBlock < 16 && 0 <= nextHistoryBlock && nextHistoryBlock < 32 else {
            return nil
        }
    }

    /// Get array of 16 trend glucose measurements. 
    /// Each array is sorted such that the most recent value is at index 0 and corresponds to the time when the sensor was read, i.e. self.date. The following measurements are each one more minute behind, i.e. -1 minute, -2 mintes, -3 minutes, ... -15 minutes.
    ///
    /// - parameter offset: offset in mg/dl that is added (NOT IN USE FOR DERIVEDALGO)
    /// - parameter slope:  slope in (mg/dl)/ raw (NOT IN USE FOR DERIVEDALGO)
    ///
    /// - returns: Array of Measurements
    func trendMeasurements(_ offset: Double = 0.0, slope: Double = 0.1, derivedAlgorithmParameterSet: DerivedAlgorithmParameters?) -> [Measurement] {
        var measurements = [Measurement]()
        // Trend data is stored in body from byte 4 to byte 4+96=100 in units of 6 bytes. Index on data such that most recent block is first.
        for blockIndex in 0...15 {
            var index = 4 + (nextTrendBlock - 1 - blockIndex) * 6 // runs backwards
            if index < 4 {
                index += 96 // if end of ring buffer is reached shift to beginning of ring buffer
            }
            let range = index..<index + 6
            let measurementBytes = Array(body[range])
            let measurementDate = date.addingTimeInterval(Double(-60 * blockIndex))
            let measurement = Measurement(bytes: measurementBytes, slope: slope, offset: offset, date: measurementDate, derivedAlgorithmParameterSet: derivedAlgorithmParameterSet)
            measurements.append(measurement)
        }
        return measurements
    }

    /// Get date of most recent history value.
    /// History values are updated every 15 minutes. Their corresponding time from start of the sensor in minutes is 15, 30, 45, 60, ..., but the value is delivered three minutes later, i.e. at the minutes 18, 33, 48, 63, ... and so on. So for instance if the current time in minutes (since start of sensor) is 67, the most recent value is 7 minutes old. This can be calculated from the minutes since start. Unfortunately sometimes the history index is incremented earlier than the minutes counter and they are not in sync. This has to be corrected.
    ///
    /// - Returns: the date of the most recent history value and the corresponding minute counter
    func dateOfMostRecentHistoryValue() -> (date: Date, counter: Int) {
        // Calculate correct date for the most recent history value.
        //        date.addingTimeInterval( 60.0 * -Double( (minutesSinceStart - 3) % 15 + 3 ) )
        let nextHistoryIndexCalculatedFromMinutesCounter = ( (minutesSinceStart - 3) / 15 ) % 32
        let delay = (minutesSinceStart - 3) % 15 + 3 // in minutes
        if nextHistoryIndexCalculatedFromMinutesCounter == nextHistoryBlock {
            // Case when history index is incremented togehter with minutesSinceStart (in sync)
            //            print("delay: \(delay), minutesSinceStart: \(minutesSinceStart), result: \(minutesSinceStart-delay)")
            return (date: date.addingTimeInterval( 60.0 * -Double(delay) ), counter: minutesSinceStart - delay)
        } else {
            // Case when history index is incremented before minutesSinceStart (and they are async)
            //            print("delay: \(delay), minutesSinceStart: \(minutesSinceStart), result: \(minutesSinceStart-delay-15)")
            return (date: date.addingTimeInterval( 60.0 * -Double(delay - 15)), counter: minutesSinceStart - delay)
        }
    }

    /// Get date of most recent history value.
    /// History values are updated every 15 minutes. Their corresponding time from start of the sensor in minutes is 15, 30, 45, 60, ..., but the value is delivered three minutes later, i.e. at the minutes 18, 33, 48, 63, ... and so on. So for instance if the current time in minutes (since start of sensor) is 67, the most recent value is 7 minutes old. This can be calculated from the minutes since start. Unfortunately sometimes the history index is incremented earlier than the minutes counter and they are not in sync. This has to be corrected.
    ///
    /// - Returns: the date of the most recent history value
    func dateOfMostRecentHistoryValue() -> Date {
        // Calculate correct date for the most recent history value.
        //        date.addingTimeInterval( 60.0 * -Double( (minutesSinceStart - 3) % 15 + 3 ) )
        let nextHistoryIndexCalculatedFromMinutesCounter = ( (minutesSinceStart - 3) / 15 ) % 32
        let delay = (minutesSinceStart - 3) % 15 + 3 // in minutes
        if nextHistoryIndexCalculatedFromMinutesCounter == nextHistoryBlock {
            // Case when history index is incremented togehter with minutesSinceStart (in sync)
            //            print("delay: \(delay), minutesSinceStart: \(minutesSinceStart), result: \(minutesSinceStart-delay)")
            return date.addingTimeInterval( 60.0 * -Double(delay) )
        } else {
            // Case when history index is incremented before minutesSinceStart (and they are async)
            //            print("delay: \(delay), minutesSinceStart: \(minutesSinceStart), result: \(minutesSinceStart-delay-15)")
            return date.addingTimeInterval( 60.0 * -Double(delay - 15))
        }
    }

//    func currentTime() -> Int {
//        
//        let quotientBy16 = minutesSinceStart / 16
//        let nominalMinutesSinceStart = nextTrendBlock + quotientBy16 * 16
//        let correctedQuotientBy16 = minutesSinceStart <= nominalMinutesSinceStart ? quotientBy16 - 1 : quotientBy16
//        let currentTime = nextTrendBlock + correctedQuotientBy16 * 16
//        
//        let mostRecentHistoryCounter = (currentTime / 15) * 15
//
//        print("currentTime: \(currentTime), mostRecentHistoryCounter: \(mostRecentHistoryCounter)")
//        return currentTime
//    }

    /// Get array of 32 history glucose measurements.
    /// Each array is sorted such that the most recent value is at index 0. This most recent value corresponds to -(minutesSinceStart - 3) % 15 + 3. The following measurements are each 15 more minutes behind, i.e. -15 minutes behind, -30 minutes, -45 minutes, ... .
    ///
    /// - parameter offset: offset in mg/dl that is added
    /// - parameter slope:  slope in (mg/dl)/ raw
    ///
    /// - returns: Array of Measurements
    func historyMeasurements(_ offset: Double = 0.0, slope: Double = 0.1, derivedAlgorithmParameterSet: DerivedAlgorithmParameters?) -> [Measurement] {
        var measurements = [Measurement]()
        // History data is stored in body from byte 100 to byte 100+192-1=291 in units of 6 bytes. Index on data such that most recent block is first.
        for blockIndex in 0..<32 {
            var index = 100 + (nextHistoryBlock - 1 - blockIndex) * 6 // runs backwards
            if index < 100 {
                index += 192 // if end of ring buffer is reached shift to beginning of ring buffer
            }

            let range = index..<index + 6
            let measurementBytes = Array(body[range])
//            let measurementDate = dateOfMostRecentHistoryValue().addingTimeInterval(Double(-900 * blockIndex)) // 900 = 60 * 15
//            let measurement = Measurement(bytes: measurementBytes, slope: slope, offset: offset, date: measurementDate)
            let (date, counter) = dateOfMostRecentHistoryValue()
            let measurement = Measurement(bytes: measurementBytes, slope: slope, offset: offset, counter: counter - blockIndex * 15, date: date.addingTimeInterval(Double(-900 * blockIndex)), derivedAlgorithmParameterSet: derivedAlgorithmParameterSet) // 900 = 60 * 15

            measurements.append(measurement)
        }
        return measurements
    }

    func oopWebInterfaceInput() -> String {
        Data(bytes).base64EncodedString()
    }

    /// Returns a new array of 344 bytes of FRAM with correct crc for header, body and footer.
    ///
    /// Usefull, if some bytes are modified in order to investigate how the OOP algorithm handles this modification.
    /// - Returns: 344 bytes of FRAM with correct crcs
    func bytesWithCorrectCRC() -> [UInt8] {
        Crc.bytesWithCorrectCRC(header) + Crc.bytesWithCorrectCRC(body) + Crc.bytesWithCorrectCRC(footer)
    }

    /// Reads Libredata in bits converts and the result to int
    ///
    /// Makes it possible to read for example 7 bits from a 1 byte (8 bit) buffer.
    /// Can be used to read both FRAM and Libre2 Bluetooth buffer data . Buffer is expected to be unencrypted
    /// - Returns: bits from buffer

    static func readBits(_ buffer: [UInt8], _ byteOffset: Int, _ bitOffset: Int, _ bitCount: Int) -> Int {
        guard bitCount != 0 else {
            return 0
        }
        var res = 0
        for i in stride(from: 0, to: bitCount, by: 1) {
            let totalBitOffset = byteOffset * 8 + bitOffset + i
            let abyte = Int(floor(Float(totalBitOffset) / 8))
            let abit = totalBitOffset % 8
            if totalBitOffset >= 0 && ((buffer[abyte] >> abit) & 0x1) == 1 {
                res = res | (1 << i)
            }
        }
        return res
    }

    static func writeBits(_ buffer: [UInt8], _ byteOffset: Int, _ bitOffset: Int, _ bitCount: Int, _ value: Int) -> [UInt8]{

        var res = buffer; // Make a copy
        for i in stride(from: 0, to: bitCount, by: 1) {
            let totalBitOffset = byteOffset * 8 + bitOffset + i;
            let byte = Int(floor(Double(totalBitOffset) / 8))
            let bit = totalBitOffset % 8;
            let bitValue = (value >> i) & 0x1;
            res[byte] = (res[byte] & ~(1 << bit) | (UInt8(bitValue) << bit));
        }
        return res;
    }

}
