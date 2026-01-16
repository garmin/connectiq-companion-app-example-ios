//
//  DeviceManager.m
//  ExampleApp
//
//  Copyright (c) 2014 Garmin. All rights reserved.
//

#import "DeviceManager.h"
#import <ConnectIQ/ConnectIQ.h>
#import "Constants.h"

// --------------------------------------------------------------------------------
#pragma mark - LITERAL CONSTANTS
// --------------------------------------------------------------------------------

NSString * const kDevicesFileName = @"devices";

// --------------------------------------------------------------------------------
#pragma mark - PRIVATE DECLARATIONS
// --------------------------------------------------------------------------------

@interface DeviceManager ()

@property (nonatomic, readwrite) NSMutableDictionary *devices;

@end

// --------------------------------------------------------------------------------
#pragma mark - CLASS DEFINITION
// --------------------------------------------------------------------------------

@implementation DeviceManager

// --------------------------------------------------------------------------------
#pragma mark - STATIC METHODS
// --------------------------------------------------------------------------------

+ (DeviceManager *)sharedManager {
    static DeviceManager *sharedManager = nil;
    @synchronized(self) {
        if (!sharedManager) {
            sharedManager = [[DeviceManager alloc] initPrivate];
        }
        return sharedManager;
    }
}

// --------------------------------------------------------------------------------
#pragma mark - INITIALIZERS AND DEALLOCATOR
// --------------------------------------------------------------------------------

- (instancetype)initPrivate {
    if ((self = [super init])) {
        self.devices = [NSMutableDictionary dictionary];
    }
    return self;
}

// --------------------------------------------------------------------------------
#pragma mark - METHODS
// --------------------------------------------------------------------------------

- (BOOL)handleOpenURL:(NSURL *)url {
    if ([url.scheme isEqualToString:ReturnURLScheme] || [url.scheme isEqualToString:@"https"]) {
        NSArray *devices = [[ConnectIQ sharedInstance] parseDeviceSelectionResponseFromURL:url];
        if (devices != nil) {
            NSLog(@"Forgetting %d known devices.", (int)self.devices.count);
            [self.devices removeAllObjects];

            for (IQDevice *device in devices) {
                NSLog(@"Received device: [%@, %@, %@, %@]", device.uuid, device.modelName, device.friendlyName, device.partNumber);
                self.devices[device.uuid] = device;
            }
            [self saveDevicesToFileSystem];
            [self.delegate devicesChanged];
            return YES;
        }
    }
    return NO;
}

- (NSArray *)allDevices {
    return self.devices.allValues;
}

- (void)saveDevicesToFileSystem {
    NSLog(@"Saving known devices.");
    NSError *archiveError = nil;
    NSData* archivedData = [NSKeyedArchiver archivedDataWithRootObject:self.devices
                                                 requiringSecureCoding:YES
                                                                 error:&archiveError];
    if (!archivedData) {
        NSLog(@"Archiving failed: %@", archiveError.localizedDescription);
        return;
    }
    if (![archivedData writeToFile:self.devicesFilePath atomically:YES]) {
        NSLog(@"Failed to save devices file.");
    }
}

- (void)restoreDevicesFromFileSystem {
    NSError *unarchiveError = nil;
    NSSet *allowedClasses = [NSSet setWithObjects:[NSMutableDictionary class],
                             [IQDevice class],
                             [NSString class],
                             [NSUUID class],
                             nil];
    NSData *unarchivedData = [NSData dataWithContentsOfFile:self.devicesFilePath];
    NSMutableDictionary *restoredDevices = [NSKeyedUnarchiver unarchivedObjectOfClasses:allowedClasses
                                                                               fromData:unarchivedData
                                                                                  error:&unarchiveError];
    if (unarchiveError) {
        NSLog(@"Error unarchiving: %@", unarchiveError.localizedDescription);
        return;
    }

    if (![restoredDevices isKindOfClass:[NSMutableDictionary class]]) {
        NSLog(@"Unarchived object was of an unexpected type.");
        return;
    }

    if (nil != restoredDevices && restoredDevices.count > 0) {
        NSLog(@"Restored saved devices:");
        for (IQDevice *device in restoredDevices.allValues) {
            NSLog(@"%@", device);
        }
        self.devices = restoredDevices;
    } else {
        NSLog(@"No saved devices to restore.");
        [self.devices removeAllObjects];
    }
    [self.delegate devicesChanged];
}

- (NSString *)devicesFilePath {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *appSupportDirectory = [paths objectAtIndex:0];
    if (![[NSFileManager defaultManager] fileExistsAtPath:appSupportDirectory]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:appSupportDirectory withIntermediateDirectories:YES attributes:nil error:nil];
    }
    return [appSupportDirectory stringByAppendingPathComponent:kDevicesFileName];
}

@end
