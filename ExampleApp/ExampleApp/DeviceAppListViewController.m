//
//  DeviceAppListViewController.m
//  ExampleApp
//
//  Copyright (c) 2014 Garmin. All rights reserved.
//

#import "DeviceAppListViewController.h"
#import <ConnectIQ/ConnectIQ.h>
#import "AppInfo.h"
#import "AppTableViewCell.h"
#import "AppMessageViewController.h"

// --------------------------------------------------------------------------------
#pragma mark - LITERAL CONSTANTS
// --------------------------------------------------------------------------------

// --------------------------------------------------------------------------------
#pragma mark - PRIVATE DECLARATIONS
// --------------------------------------------------------------------------------

@interface DeviceAppListViewController () <IQDeviceEventDelegate, UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, weak) IBOutlet UITableView *tableView;
@property (nonatomic, weak) IBOutlet UIButton *installButton;

@property (nonatomic, strong) IQDevice *device;
@property (nonatomic, strong) NSMutableDictionary *appInfos;
@property (nonatomic, strong) NSUUID *currentAppID;

@end

// --------------------------------------------------------------------------------
#pragma mark - CLASS DEFINITION
// --------------------------------------------------------------------------------

@implementation DeviceAppListViewController

// --------------------------------------------------------------------------------
#pragma mark - STATIC METHODS
// --------------------------------------------------------------------------------

// --------------------------------------------------------------------------------
#pragma mark - INITIALIZERS AND DEALLOCATOR
// --------------------------------------------------------------------------------

- (instancetype)initWithDevice:(IQDevice *)device {
    if ((self = [super initWithNibName:nil bundle:nil])) {
        _device = device;

        IQApp *stringApp   = [IQApp appWithUUID:[[NSUUID alloc] initWithUUIDString:@"a3421fee-d289-106a-538c-b9547ab12095"]
                                      storeUuid:[NSUUID UUID]
                                         device:device];

        _appInfos = [NSMutableDictionary dictionary];
        _appInfos[stringApp.uuid]   = [[AppInfo alloc] initWithName:@"String Test App"   IQApp:stringApp];
    }
    return self;
}

// --------------------------------------------------------------------------------
#pragma mark - VIEW LIFECYCLE
// --------------------------------------------------------------------------------

- (void)viewDidLoad {
    [super viewDidLoad];

    self.navigationItem.title = self.device.friendlyName;

    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    UINib *nib = [UINib nibWithNibName:@"AppTableViewCell" bundle:nil];
    [self.tableView registerNib:nib forCellReuseIdentifier:@"iqappcell"];

    self.currentAppID = nil;
}

- (void)viewWillAppear:(BOOL)animated {
    [[ConnectIQ sharedInstance] registerForDeviceEvents:self.device delegate:self];
    [self.tableView reloadData];

    for (AppInfo *appInfo in self.appInfos.allValues) {
        [appInfo updateStatusWithCompletion:^(AppInfo *appInfo) {
            [self.tableView reloadData];
        }];
    }
}

- (void)viewDidDisappear:(BOOL)animated {
    [[ConnectIQ sharedInstance] unregisterForAllDeviceEvents:self];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

// --------------------------------------------------------------------------------
#pragma mark - DYNAMIC PROPERTIES
// --------------------------------------------------------------------------------

- (void)setCurrentAppID:(NSUUID *)currentAppID {
    _currentAppID = currentAppID;

    AppInfo *appInfo = self.appInfos[currentAppID];
    if (appInfo.status == nil || appInfo.status.isInstalled) {
        self.installButton.enabled = NO;
        self.installButton.backgroundColor = [UIColor lightGrayColor];
    } else {
        self.installButton.enabled = YES;
        self.installButton.backgroundColor = [UIColor colorWithRed:0.655f green:0.792f blue:1.0f alpha:1.0f];
    }
}

// --------------------------------------------------------------------------------
#pragma mark - METHODS (IBAction)
// --------------------------------------------------------------------------------

- (IBAction)installButtonPressed:(id)sender {
    AppInfo *currentAppInfo = self.appInfos[self.currentAppID];
    NSLog(@"Installing '%@'", currentAppInfo.name);
    [[ConnectIQ sharedInstance] showConnectIQStoreForApp:currentAppInfo.app];
}

// --------------------------------------------------------------------------------
#pragma mark - METHODS (UITableView)
// --------------------------------------------------------------------------------

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.appInfos.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 85.0f;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSUUID *appKey = self.appInfos.allKeys[indexPath.row];
    AppInfo *appInfo = self.appInfos[appKey];
    AppTableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"iqappcell" forIndexPath:indexPath];
    cell.nameLabel.text = appInfo.name;
    cell.installedLabel.text = appInfo.status.isInstalled ? [NSString stringWithFormat:@"Installed (v%d)", appInfo.status.version] : @"Not installed";
    cell.enabled = appInfo.status.isInstalled;
    cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSUUID *appKey = self.appInfos.allKeys[indexPath.row];
    self.currentAppID = appKey;

    AppInfo *appInfo = self.appInfos[appKey];
    if (appInfo.status.isInstalled) {
        AppMessageViewController *vc = [[AppMessageViewController alloc] initWithAppInfo:appInfo];
        [self.navigationController pushViewController:vc animated:YES];
    }
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
    NSUUID *appKey = self.appInfos.allKeys[indexPath.row];
    AppInfo *appInfo = self.appInfos[appKey];
    [[ConnectIQ sharedInstance] showConnectIQStoreForApp:appInfo.app];
}

// --------------------------------------------------------------------------------
#pragma mark - METHODS (IQDeviceEventDelegate)
// --------------------------------------------------------------------------------

- (void)deviceStatusChanged:(IQDevice *)device status:(IQDeviceStatus)status {
    // We've only registered to receive status updates for one device, so we don't
    // need to check the device parameter here. We know it's our device.
    if (status != IQDeviceStatus_Connected) {
        // This page's device is no longer connected. Pop back to the device list.
        [self.navigationController popToRootViewControllerAnimated:YES];
    }
}

// --------------------------------------------------------------------------------
#pragma mark - METHODS
// --------------------------------------------------------------------------------

@end
