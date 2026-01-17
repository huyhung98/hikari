import IOKit
import ApplicationServices
import Foundation

// MARK: - I2C Definitions
// Manually defining struct layout to match IOKit/i2c/IOI2CInterface.h

public struct IOI2CRequest {
    var sendTransactionType: IOOptionBits = 0
    var replyTransactionType: IOOptionBits = 0
    var sendAddress: UInt32 = 0
    var replyAddress: UInt32 = 0
    var sendBytes: UInt32 = 0
    var replyBytes: UInt32 = 0
    var minReplyDelay: UInt32 = 0
    var result: IOReturn = 0
    var commFlags: IOOptionBits = 0
    var pad: UInt32 = 0
    var sendBuffer: vm_address_t = 0
    var replyBuffer: vm_address_t = 0
    
    init() {}
}

struct DDC {
    static let kDelay: UInt32 = 20000 // Microseconds

    static func findService(for displayId: CGDirectDisplayID) -> io_service_t {
         var iterator: io_iterator_t = 0
         let result = IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceMatching("IODisplayConnect"), &iterator)
         guard result == KERN_SUCCESS else { return 0 }
         defer { IOObjectRelease(iterator) }
         
         var service: io_object_t = 0
         while true {
             service = IOIteratorNext(iterator)
             guard service != 0 else { break }
             
             if let info = IODisplayCreateInfoDictionary(service, IOOptionBits(kIODisplayOnlyPreferredName)).takeRetainedValue() as? [String: Any] {
                 if let vendor = info["DisplayVendorID"] as? Int,
                    let product = info["DisplayProductID"] as? Int {
                     if UInt32(vendor) == CGDisplayVendorNumber(displayId) &&
                        UInt32(product) == CGDisplayModelNumber(displayId) {
                          return service
                     }
                 }
             }
             IOObjectRelease(service)
         }
         return 0
    }
    
    static func findI2CInterface(for framebuffer: io_service_t) -> io_service_t {
        var iterator: io_iterator_t = 0
        let result = IORegistryEntryCreateIterator(framebuffer, kIOServicePlane, IOOptionBits(kIORegistryIterateRecursively), &iterator)
        guard result == KERN_SUCCESS else { return 0 }
        defer { IOObjectRelease(iterator) }
        
        var service: io_object_t = 0
        while true {
            service = IOIteratorNext(iterator)
            guard service != 0 else { break }
            
            if IOObjectConformsTo(service, "IOI2CInterface") != 0 {
                return service
            }
            IOObjectRelease(service)
        }
        return 0
    }
    
    static func write(displayId: CGDirectDisplayID, controlCode: UInt8, newValue: UInt8) -> Bool {
        let displayService = findService(for: displayId)
        if displayService == 0 {
            print("No service found for display \(displayId)")
            return false
        }
        defer { IOObjectRelease(displayService) }
        
        let i2cService = findI2CInterface(for: displayService)
        guard i2cService != 0 else {
            print("No I2C interface found for service")
            return false
        }
        defer { IOObjectRelease(i2cService) }
        
        var request = IOI2CRequest()
        request.commFlags = 0
        request.sendTransactionType = 0
        request.replyTransactionType = 0
        request.sendAddress = 0x6E >> 1
        request.replyAddress = 0x6F >> 1
        
        var data = [UInt8](repeating: 0, count: 7)
        data[0] = 0x51 
        data[1] = 0x84 
        data[2] = 0x03 
        data[3] = controlCode
        data[4] = 0x00 
        data[5] = newValue
        
        var checksum: UInt8 = 0x6E 
        for i in 0..<6 {
            checksum ^= data[i]
        }
        data[6] = checksum
        
        request.sendBytes = UInt32(data.count)
        request.replyBytes = 0
        
        var connect: io_connect_t = 0
        guard IOServiceOpen(i2cService, mach_task_self_, 0, &connect) == KERN_SUCCESS else {
            return false
        }
        defer { IOServiceClose(connect) }
        
        let success = data.withUnsafeBufferPointer { buffer -> Bool in
            request.sendBuffer = vm_address_t(bitPattern: buffer.baseAddress)
            let requestSize = MemoryLayout<IOI2CRequest>.size
            var outputSize: Int = 0
            var reqCopy = request
            let kr = IOConnectCallStructMethod(connect, 0, &reqCopy, requestSize, nil, &outputSize)
            return kr == KERN_SUCCESS
        }
        return success
    }
}
