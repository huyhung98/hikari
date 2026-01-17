import Foundation
import IOKit
import CoreGraphics

// MARK: - DisplayServices (Internal Brightness for M1/Intel)

class PrivateDisplayServices {
    static let setBrightnessFunc: (@convention(c) (CGDirectDisplayID, Float) -> Int32)? = {
        let handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY)
        guard handle != nil else { return nil }
        guard let sym = dlsym(handle, "DisplayServicesSetBrightness") else { return nil }
        return unsafeBitCast(sym, to: (@convention(c) (CGDirectDisplayID, Float) -> Int32).self)
    }()
    
    static let getBrightnessFunc: (@convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32)? = {
        let handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY)
        guard handle != nil else { return nil }
        guard let sym = dlsym(handle, "DisplayServicesGetBrightness") else { return nil }
        return unsafeBitCast(sym, to: (@convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32).self)
    }()
    
    static func setBrightness(displayID: CGDirectDisplayID, level: Float) {
        _ = setBrightnessFunc?(displayID, level)
    }
    
    static func getBrightness(displayID: CGDirectDisplayID) -> Float? {
        var brightness: Float = 0
        let result = getBrightnessFunc?(displayID, &brightness)
        return result == 0 ? brightness : nil
    }
}

// MARK: - SkyLight (Private Display Configuration)

class PrivateSkyLight {
    typealias CGSConfigureDisplayEnabledType = @convention(c) (CGDisplayConfigRef, CGDirectDisplayID, Bool) -> Int32
    
    static let configureDisplayEnabledFunc: CGSConfigureDisplayEnabledType? = {
        let handle = dlopen("/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics", RTLD_LAZY)
        guard handle != nil else { return nil }
        guard let sym = dlsym(handle, "CGSConfigureDisplayEnabled") else { return nil }
        return unsafeBitCast(sym, to: CGSConfigureDisplayEnabledType.self)
    }()
    
    static func setDisplayEnabled(config: CGDisplayConfigRef, displayID: CGDirectDisplayID, enabled: Bool) -> Int32 {
        guard let funcPtr = configureDisplayEnabledFunc else { return -1 }
        return funcPtr(config, displayID, enabled)
    }
    
    typealias CGSGetDisplayListType = @convention(c) (UInt32, UnsafeMutablePointer<CGDirectDisplayID>, UnsafeMutablePointer<UInt32>) -> Int32
    
    static let getDisplayListFunc: CGSGetDisplayListType? = {
        let handle = dlopen("/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics", RTLD_LAZY)
        guard handle != nil else { return nil }
        guard let sym = dlsym(handle, "CGSGetDisplayList") else { return nil }
        return unsafeBitCast(sym, to: CGSGetDisplayListType.self)
    }()
    
    static func getDisplayList(max: UInt32, displays: UnsafeMutablePointer<CGDirectDisplayID>, count: UnsafeMutablePointer<UInt32>) -> Int32 {
        guard let funcPtr = getDisplayListFunc else { return -1 }
        return funcPtr(max, displays, count)
    }
}

// MARK: - IOAVService (M1 External DDC)

class PrivateIOAVService {
    typealias IOAVServiceCreateType = @convention(c) (CFAllocator?, io_service_t) -> Unmanaged<CFTypeRef>?
    typealias IOAVServiceWriteI2CType = @convention(c) (CFTypeRef, UInt32, UInt32, UnsafeMutableRawPointer?, UInt32) -> IOReturn
    
    static let createFunc: IOAVServiceCreateType? = {
        let handle = dlopen(nil, RTLD_LAZY)
        guard let sym = dlsym(handle, "IOAVServiceCreate") else { return nil }
        return unsafeBitCast(sym, to: IOAVServiceCreateType.self)
    }()
    
    static let writeI2CFunc: IOAVServiceWriteI2CType? = {
        let handle = dlopen(nil, RTLD_LAZY)
        guard let sym = dlsym(handle, "IOAVServiceWriteI2C") else { return nil }
        return unsafeBitCast(sym, to: IOAVServiceWriteI2CType.self)
    }()
}

struct IOAVDDC {
    static func write(displayID: CGDirectDisplayID, controlCode: UInt8, newValue: UInt8) -> Bool {
        guard let createFunc = PrivateIOAVService.createFunc,
              let writeFunc = PrivateIOAVService.writeI2CFunc else {
            return false
        }
        
        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(0, IOServiceMatching("DCPAVServiceProxy"), &iterator)
        guard result == KERN_SUCCESS else { return false }
        defer { IOObjectRelease(iterator) }
        
        var service: io_object_t = 0
        var foundService: io_object_t = 0
        
        while true {
            service = IOIteratorNext(iterator)
            guard service != 0 else { break }
            foundService = service
            break
        }
        
        if foundService == 0 { return false }
        
        guard let avServiceRef = createFunc(kCFAllocatorDefault, foundService) else {
            IOObjectRelease(foundService)
            return false
        }
        let avService = avServiceRef.takeRetainedValue()
        IOObjectRelease(foundService)
        
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
        
        let kr = writeFunc(avService, 0x37, 0x51, &data, UInt32(data.count))
        return kr == KERN_SUCCESS
    }
}
