//
//  BCLBeaconDetailsViewController.m
//  BCLRemoteApp
//
// Copyright (c) 2015, Upnext Technologies Sp. z o.o.
// All rights reserved.
//
// This source code is licensed under the BSD 3-Clause License found in the
// LICENSE.txt file in the root directory of this source tree.
//

#import <BeaconCtrl/BCLBeacon.h>
#import <BeaconCtrl/BCLLocation.h>
#import <BeaconCtrl/BCLZone.h>
#import <BeaconCtrl/BCLTrigger.h>
#import <BeaconCtrl/BCLConditionEvent.h>
#import "BCLBeaconDetailsViewController.h"
#import "TPKeyboardAvoidingScrollView.h"
#import "BeaconCtrlManager.h"
#import "UIColor+BCLAppColors.h"
#import "AlertControllerManager.h"
#import "UIViewController+BCLActivityIndicator.h"
#import "BCLUUIDTextFieldFormatter.h"
#import "UIViewController+BCLBannerMessages.h"
#import "BCLVendorChoiceViewController.h"

static const CGFloat BCLKontaktIOFieldsHeight = 52.0f;
static NSString *const BCLShowVendorChoiceSegueIdentifier = @"showVendorChoiceSegue";

@interface BCLBeaconDetailsViewController () <UIAlertViewDelegate, UITextFieldDelegate, BCLVendorChoiceViewControllerDelegate>
@property (weak, nonatomic) IBOutlet UILabel *beaconNameLabel;
@property (weak, nonatomic) IBOutlet UITextField *beaconNameTextField;
@property (weak, nonatomic) IBOutlet UITextField *uuidTextField;
@property (weak, nonatomic) IBOutlet UITextField *minorTextField;
@property (weak, nonatomic) IBOutlet UITextField *majorTextField;
@property (weak, nonatomic) IBOutlet UITextField *latitudeTextField;
@property (weak, nonatomic) IBOutlet UITextField *longitudeTextField;
@property (weak, nonatomic) IBOutlet TPKeyboardAvoidingScrollView *scrollView;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *contentViewHeightConstraint;
@property (weak, nonatomic) IBOutlet UIView *zoneColorBadge;
@property (weak, nonatomic) IBOutlet UILabel *zoneNameLabel;
@property (weak, nonatomic) IBOutlet UILabel *floorTitleLabel;
@property (weak, nonatomic) IBOutlet UILabel *floorNumberLabel;
@property (weak, nonatomic) IBOutlet UIView *zoneButtonBadge;
@property (weak, nonatomic) IBOutlet UILabel *zoneButtonTitleLabel;
@property (weak, nonatomic) IBOutlet UILabel *zoneButtonFloorLabel;
@property (weak, nonatomic) IBOutlet UILabel *notificationMessageLabel;
@property (weak, nonatomic) IBOutlet UIButton *confirmButton;
@property (weak, nonatomic) IBOutlet UIButton *zoneButton;
@property (weak, nonatomic) IBOutlet UIButton *notificationsButton;
@property (weak, nonatomic) IBOutlet UIImageView *zonesDisclosureIndicatorImage;
@property (weak, nonatomic) IBOutlet UIImageView *notificationsDisclosureIndicatorImage;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *barButton;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *uuidViewHeightConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *latitudeViewHeightConstraint;
@property (weak, nonatomic) IBOutlet UILabel *firmwareVersionLabel;
@property (weak, nonatomic) IBOutlet UILabel *batteryStatusLabel;
@property (weak, nonatomic) IBOutlet UIView *firmwareVersionBGView;
@property (weak, nonatomic) IBOutlet UIView *batteryStatusBGView;
@property (weak, nonatomic) IBOutlet UILabel *vendorNameLabel;
@property (weak, nonatomic) IBOutlet UIImageView *vendorDisclosureIndicator;
@property (weak, nonatomic) IBOutlet UILabel *deviceIDLabel;
@property (weak, nonatomic) IBOutlet UILabel *distanceLabel;
@property (weak, nonatomic) IBOutlet UILabel *signalIntervalLabel;
@property (weak, nonatomic) IBOutlet UILabel *transmissionPowerLabel;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *deviceIDViewHeightConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *kontaktStatusViewHeightConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *signalIntervalViewHeightConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *transmissionPowerViewHeightConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *deleteButtonViewHeightConstraint;
@property (nonatomic) BOOL isShowingUpdateMessage;
@property (nonatomic) BOOL editingEnabled;

@property (nonatomic) NSNumber *selectedFloor;
@property (nonatomic) NSString *notificationMessage;
@property (nonatomic) BCLEventType selectedTrigger;

@property (nonatomic) NSArray *editableTextFieldsBackgrounds;

@property(nonatomic, strong) BCLUUIDTextFieldFormatter *uuidFormatter;
@property(nonatomic, strong) NSTimer *distaceReloadTimer;
@property(nonatomic, copy) NSString *selectedVendor;
@end

static const NSUInteger BCLEditableTextFieldBGTag = 23;
static const NSUInteger BCLKontaktEditableTextFieldBGTag = 24;

@implementation BCLBeaconDetailsViewController

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.distaceReloadTimer invalidate];
}

#pragma mark - UIViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    [self updateView];
    self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"" style:UIBarButtonItemStylePlain target:nil action:nil];
    if ([UIScreen mainScreen].bounds.size.height < 667.0) {
        [self decreaseFontSize];
    }
    
    //distance reload timer
    self.distaceReloadTimer = [NSTimer scheduledTimerWithTimeInterval:2 target:self selector:@selector(reloadDistance) userInfo:nil repeats:YES];

    //beacon and zone listeners
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(closestBeaconDidChange:) name:BeaconManagerClosestBeaconDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(currentZoneDidChange:) name:BeaconManagerCurrentZoneDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(propertiesUpdateDidStart:) name:BeaconManagerPropertiesUpdateDidStartNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(propertiesUpdateDidEnd:) name:BeaconManagerPropertiesUpdateDidFinishNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(firmwareUpdateDidStart:) name:BeaconManagerFirmwareUpdateDidStartNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(firmwareUpdateDidProgress:) name:BeaconManagerFirmwareUpdateDidProgressNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(firmwareUpdateDidEnd:) name:BeaconManagerFirmwareUpdateDidFinishNotification object:nil];
    
    self.uuidFormatter = [BCLUUIDTextFieldFormatter new];
    self.uuidFormatter.textField = self.uuidTextField;

    [self setEditingEnabled:NO];
}

- (void)reloadDistance
{
    if (self.beacon.estimatedDistance != NSNotFound) {
        self.distanceLabel.text = [NSString stringWithFormat:@"%.2f m", self.beacon.estimatedDistance];
    } else {
        self.distanceLabel.text = @"Unknown";
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [UIView animateWithDuration:animated ? 0.5 : 0.0 animations:^{
        UIViewController *topViewController = self.navigationController.topViewController;
        if (topViewController == self && self.isShowingUpdateMessage) {
            NSInteger previousViewControllerIndex = self.navigationController.viewControllers.count - 2;
            UIView *bannerView;
            if (previousViewControllerIndex >= 0) {
                UIViewController *previousViewController = self.navigationController.viewControllers[previousViewControllerIndex];
                bannerView = previousViewController.bannerView;
            } else {
                bannerView = self.bannerView;
            }
            
            self.scrollView.contentInset = UIEdgeInsetsMake(bannerView.bounds.size.height, 0, 0, 0);
            self.scrollView.contentOffset = CGPointMake(0, -self.scrollView.contentInset.top);
        }
    }];
    
    if (self.beaconMode == kBCLBeaconModeNew) {
        [self setEditingEnabled:[self.parentViewController isKindOfClass:[UINavigationController class]] animated:YES];
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    self.navigationItem.rightBarButtonItem.enabled = YES;
    self.navigationItem.leftBarButtonItem.enabled = YES;
    
    if (self.beacon) {
        [self showUpdateMessages:NO];
    } else {
        [self hideUpdateMessages:NO];
    }
}

- (void)decreaseFontSize
{
    [self decreaseFontSize:self.scrollView];
}

- (void)decreaseFontSize:(UIView *)mainView
{
    for (UIView *view in mainView.subviews) {
        if ([view isKindOfClass:[UITextField class]]) {
            UITextField *textField = (UITextField *)view;
            if (textField != self.beaconNameTextField) {
                textField.font = [textField.font fontWithSize:textField.font.pointSize - 3];
            }
        }

        if ([view isKindOfClass:[UILabel class]]) {
            UILabel *label = (UILabel *)view;
            if (label != self.beaconNameLabel) {
                label.font = [label.font fontWithSize:label.font.pointSize - 3];
            }
        }

        [self decreaseFontSize:view];
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
    [self hideKeyboard];
    [self resetFormValidation];
    if ([self.navigationController.viewControllers indexOfObject:self]==NSNotFound) {
        if (self.beaconMode == kBCLBeaconModeNew) {
            [self updateBeaconData];
        } else {
            [self updateView];
        }

        [UIView animateWithDuration:animated ? 0.5 : 0.0 animations:^{
            [self.scrollView setContentInset:UIEdgeInsetsZero];
            [self.scrollView setContentOffset:CGPointZero];
        }];
    }
    
    [super viewWillDisappear:animated];
    
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    if ([UIScreen mainScreen].bounds.size.height > 480) {
        self.contentViewHeightConstraint.constant = self.scrollView.frame.size.height;
    } else {
        self.contentViewHeightConstraint.constant = 504.0;
    }

    self.zoneButtonBadge.layer.cornerRadius = self.zoneButtonBadge.layer.frame.size.width/2;
    self.zoneColorBadge.layer.cornerRadius = self.zoneColorBadge.layer.frame.size.width/2;

}

#pragma mark - Private

- (void)hideKeyboard
{
    [self.beaconNameTextField resignFirstResponder];
    [self.latitudeTextField resignFirstResponder];
    [self.longitudeTextField resignFirstResponder];
    [self.majorTextField resignFirstResponder];
    [self.minorTextField resignFirstResponder];
    [self.uuidTextField resignFirstResponder];
}

- (BOOL)hideKeyboardIfNeeded
{
    if ([self showingKeyboard]) {
        [self hideKeyboard];
        return YES;
    }
    
    return NO;
}

- (void)currentZoneDidChange:(NSNotification *)notification
{
    if (self.beaconMode == kBCLBeaconModeHidden) {
        self.selectedZone = [BeaconCtrlManager sharedManager].beaconCtrl.currentZone;
    }
}

- (void)propertiesUpdateDidStart:(NSNotification *)notification
{
    if (![[notification.userInfo[@"beacon"] beaconIdentifier] isEqualToString:self.beacon.beaconIdentifier]) {
        return;
    }
    
    [self showUpdateMessage:@"Updating properties..." warning:YES];
}

- (void)propertiesUpdateDidEnd:(NSNotification *)notification
{
    BCLBeacon *updatedBeacon = notification.userInfo[@"beacon"];
    
    if (![updatedBeacon.beaconIdentifier isEqualToString:self.beacon.beaconIdentifier]) {
        return;
    }
    
    if ([notification.userInfo[@"success"] boolValue]) {
        [self showUpdateMessage:@"Properties succesfully updated!" warning:NO];
    } else {
        [self showUpdateMessage:@"Something went wrong while updating properties!" warning:YES];
    }
    
    [self updateView];
}

- (void)firmwareUpdateDidStart:(NSNotification *)notification
{
    if (![[notification.userInfo[@"beacon"] beaconIdentifier] isEqualToString:self.beacon.beaconIdentifier]) {
        return;
    }
    
    [self showUpdateMessage:@"Updating firmware..." warning:YES];
}

- (void)firmwareUpdateDidProgress:(NSNotification *)notification
{
    if (![[notification.userInfo[@"beacon"] beaconIdentifier] isEqualToString:self.beacon.beaconIdentifier]) {
        return;
    }
    
    [self showUpdateMessage:[NSString stringWithFormat:@"Firwmare update progress: %@%%", notification.userInfo[@"progress"]] warning:YES];
}

- (void)firmwareUpdateDidEnd:(NSNotification *)notification
{
    BCLBeacon *updatedBeacon = notification.userInfo[@"beacon"];
    
    if (![updatedBeacon.beaconIdentifier isEqualToString:self.beacon.beaconIdentifier]) {
        return;
    }
    
    if ([notification.userInfo[@"success"] boolValue]) {
        [self showUpdateMessage:@"Successfully updated firmware!" warning:NO];
    } else {
        [self showUpdateMessage:@"Something went wrong while updating firmware!" warning:YES];
    }
    
    [self updateView];
}

- (void)showUpdateMessage:(NSString *)message warning:(BOOL)isWarning
{
    UIViewController *topViewController = self.navigationController.topViewController;
    
    [topViewController presentMessage:message animated:NO warning:isWarning completion:nil];
    self.isShowingUpdateMessage = YES;
}

- (void)closestBeaconDidChange:(NSNotification *)notification
{
    if (self.beaconMode == kBCLBeaconModeHidden) {
        BCLBeacon *candidate = [BeaconCtrlManager sharedManager].beaconCtrl.closestBeacon;
        self.floorNumberLabel.text = candidate ? candidate.name : @"No beacon in range";
    }
}

- (IBAction)confirmButtonPressed:(id)sender
{
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:nil message:@"Are you sure you want to delete this beacon?" delegate:self cancelButtonTitle:@"No" otherButtonTitles:@"Yes", nil];
    [alertView show];
}

- (BOOL)validateForm
{
    [self resetFormValidation];

    NSString *name = [self.beaconNameTextField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!name || [name isEqualToString:@""]) {
        [self presentValidationError:@"Name can't be blank!"];
        self.beaconNameTextField.superview.layer.borderColor = [UIColor redAppColor].CGColor;
        self.beaconNameTextField.superview.layer.borderWidth = 1.0;
        return NO;
    }

    NSString *uuid = [self.uuidTextField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!uuid || [uuid isEqualToString:@""]) {
        [self presentValidationError:@"UUID can't be blank!"];
        self.uuidTextField.superview.layer.borderColor = [UIColor redAppColor].CGColor;
        self.uuidTextField.superview.layer.borderWidth = 1.0;
        return NO;
    }

    if (![self.uuidFormatter isValid]) {
        [self presentValidationError:@"Invalid UUID"];
        self.uuidTextField.superview.layer.borderColor = [UIColor redAppColor].CGColor;
        self.uuidTextField.superview.layer.borderWidth = 1.0;
        return NO;
    }

    NSString *major = [self.majorTextField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!major || [major isEqualToString:@""]) {
        [self presentValidationError:@"Major can't be blank!"];
        self.majorTextField.superview.layer.borderColor = [UIColor redAppColor].CGColor;
        self.majorTextField.superview.layer.borderWidth = 1.0;
        return NO;
    }

    NSString *minor = [self.minorTextField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!minor || [minor isEqualToString:@""]) {
        [self presentValidationError:@"Minor can't be blank!"];
        self.minorTextField.superview.layer.borderColor = [UIColor redAppColor].CGColor;
        self.minorTextField.superview.layer.borderWidth = 1.0;
        return NO;
    }


    return YES;
}

- (void)presentValidationError:(NSString *)errorMessage
{
    self.navigationItem.rightBarButtonItem.enabled = NO;
    [self presentValidationError:errorMessage completion:^(BOOL finished) {
        self.navigationItem.rightBarButtonItem.enabled = YES;
    }];
}

- (void)resetFormValidation
{
    [self hideBannerView:NO];
    self.beaconNameTextField.superview.layer.borderWidth = 0;
    self.uuidTextField.superview.layer.borderWidth = 0;
    self.majorTextField.superview.layer.borderWidth = 0;
    self.minorTextField.superview.layer.borderWidth = 0;
    self.latitudeTextField.superview.layer.borderWidth = 0;
    self.longitudeTextField.superview.layer.borderWidth = 0;
}

- (IBAction)barButtonPressed:(id)sender
{
    switch (self.beaconMode) {
        case kBCLBeaconModeNew:
            [self saveBeacon];
            break;
        case kBCLBeaconModeEdit:
            [self updateBeacon];
            break;
        case kBCLBeaconModeDetails:
            self.beaconMode = kBCLBeaconModeEdit;
            break;
        case kBCLBeaconModeHidden:
            break;
    }
}

- (void)saveBeacon
{
    if (![self validateForm]) {
        return;
    }
    [self hideKeyboard];
    [self updateBeaconData];

    [self showActivityIndicatorViewAnimated:YES];
    self.navigationItem.rightBarButtonItem.enabled = NO;
    self.navigationItem.leftBarButtonItem.enabled = NO;

    NSString *testActionName;
    NSArray *testActionAttributes;

    if (self.notificationMessage) {
        testActionName = @"Test action";
        testActionAttributes = @[@{@"name" : @"text", @"value" : self.notificationMessage}];
    }

    [self.bclManager createBeacon:self.beacon testActionName:testActionName testActionTrigger:self.selectedTrigger testActionAttributes:testActionAttributes completion:^(BCLBeacon *newBeacon, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!error) {
                self.beacon = newBeacon;
                if ([self.delegate respondsToSelector:@selector(beaconDetailsViewController:didSaveNewBeacon:)]) {
                    [self.delegate beaconDetailsViewController:self didSaveNewBeacon:newBeacon];
                }
            } else {
                [[AlertControllerManager sharedManager] presentError:error inViewController:self completion:nil];
            }

            self.navigationItem.rightBarButtonItem.enabled = YES;
            self.navigationItem.leftBarButtonItem.enabled = YES;
            [self hideActivityIndicatorViewAnimated:YES];
        });
    }];
}

- (void)updateBeacon
{
    if (![self validateForm]) {
        return;
    }

    [self hideKeyboard];
    BCLBeacon *beaconCopy = [self.beacon copy];
    [self updateBeaconData:beaconCopy];
    [self showActivityIndicatorViewAnimated:YES];
    self.navigationItem.rightBarButtonItem.enabled = NO;
    self.navigationItem.leftBarButtonItem.enabled = NO;

    NSString *testActionName;
    NSMutableArray *testActionAttributes;

    if (self.notificationMessage) {
        testActionName = @"Test action";
        BCLAction *testAction = [[BeaconCtrlManager sharedManager] testActionForBeacon:self.beacon];
        if (testAction) {
            testActionAttributes = [@[] mutableCopy];
            [testAction.customValues enumerateObjectsUsingBlock:^(NSDictionary *valueDict, NSUInteger idx, BOOL *stop) {
                [testActionAttributes addObject:@{@"name": valueDict[@"name"], @"value": [valueDict[@"name"] isEqualToString:@"text"] ? self.notificationMessage : valueDict[@"value"], @"id": valueDict[@"id"]}];
            }];
        } else {
            testActionAttributes = [@[@{@"name": @"text", @"value": self.notificationMessage}] mutableCopy];
        }
    }

    [self.bclManager updateBeacon:beaconCopy testActionName:testActionName testActionTrigger:self.selectedTrigger testActionAttributes:testActionAttributes.copy completion:^(BCLBeacon *updatedBeacon, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!error) {
                self.beacon = updatedBeacon;
                if ([self.delegate respondsToSelector:@selector(beaconDetailsViewController:didEditBeacon:)]) {
                    [self.delegate beaconDetailsViewController:self didEditBeacon:updatedBeacon];
                }
            } else {
                [[AlertControllerManager sharedManager] presentError:error inViewController:self completion:nil];
            }
            [self hideActivityIndicatorViewAnimated:YES];
            self.navigationItem.rightBarButtonItem.enabled = YES;
            self.navigationItem.leftBarButtonItem.enabled = YES;
        });
    }];
}

- (IBAction)zoneButtonPressed:(id)sender
{

    BLCZonesViewController *zonesViewController = [BLCZonesViewController newZonesViewController];
    [zonesViewController setMode:kBCLZonesViewControllerSelect initialZoneSelection:self.selectedZone floorSelection:self.selectedFloor];
    zonesViewController.delegate = self;

    [self.navigationController pushViewController:zonesViewController animated:YES];
}

- (void)updateBeaconData:(BCLBeacon *)beacon
{
    beacon.name = [self isEmptyString:self.beaconNameTextField.text] ? nil : self.beaconNameTextField.text;
    beacon.proximityUUID = [self isEmptyString:self.uuidTextField.text] ? nil : [[NSUUID alloc] initWithUUIDString:self.uuidTextField.text];
    beacon.minor = [self isEmptyString:self.minorTextField.text] ? nil : @([self.minorTextField.text floatValue]);
    beacon.major = [self isEmptyString:self.majorTextField.text] ? nil : @([self.majorTextField.text floatValue]);
    beacon.location = [[BCLLocation alloc] initWithLocation:[[CLLocation alloc] initWithLatitude:[self.latitudeTextField.text floatValue] longitude:[self.longitudeTextField.text floatValue]] floor:self.selectedFloor];
    beacon.vendor = [self isEmptyString:self.vendorNameLabel.text] ? nil : self.vendorNameLabel.text;
    [beacon.zone.beacons removeObject:self.beacon];
    beacon.zone = self.selectedZone;
    [beacon.zone.beacons addObject:self.beacon];
}

- (void)updateBeaconData
{
    [self updateBeaconData:self.beacon];
}

- (BOOL)isEmptyString:(NSString *)text
{
    NSString *trimmedText = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return (!text || [trimmedText isEqualToString:@""]);
}

- (void)updateView
{
    [self resetFormValidation];
    self.beaconNameTextField.text = self.beacon.name;
    self.uuidTextField.text = self.beacon.proximityUUID.UUIDString;
    self.minorTextField.text = [self.beacon.minor stringValue];
    self.majorTextField.text = [self.beacon.major stringValue];
    self.latitudeTextField.text = [NSString stringWithFormat:@"%f", self.beacon.location.location.coordinate.latitude];
    self.longitudeTextField.text = [NSString stringWithFormat:@"%f", self.beacon.location.location.coordinate.longitude];
    self.selectedZone = self.beacon.zone;
    self.selectedVendor = self.beacon.vendor;
    self.selectedTrigger = BCLEventTypeEnter;
    self.vendorNameLabel.text = self.beacon.vendor ?: @"Other";
    [self reloadDistance];

    // kontakt.io specific fields
    BOOL isKontaktIO = self.beaconIsKontakt;
    self.deviceIDViewHeightConstraint.constant = isKontaktIO ? BCLKontaktIOFieldsHeight : 0.0f;
    self.kontaktStatusViewHeightConstraint.constant = isKontaktIO ? BCLKontaktIOFieldsHeight : 0.0f;
    self.signalIntervalViewHeightConstraint.constant = isKontaktIO ? BCLKontaktIOFieldsHeight : 0.0f;
    self.transmissionPowerViewHeightConstraint.constant = isKontaktIO ? BCLKontaktIOFieldsHeight : 0.0f;

    if (self.beacon.batteryLevel != NSNotFound) {
        self.batteryStatusLabel.text = [NSString stringWithFormat:@"%d %%", self.beacon.batteryLevel];
        if (self.beacon.batteryLevel <= 20) {
            self.batteryStatusBGView.backgroundColor = [UIColor colorWithRed:0.95 green:0.32 blue:0.29 alpha:1];
        } else if (self.beacon.batteryLevel <= 40) {
            self.batteryStatusBGView.backgroundColor = [UIColor colorWithRed:1 green:0.94 blue:0.94 alpha:1];
        } else {
            self.batteryStatusBGView.backgroundColor = [UIColor whiteColor];
        }
    } else {
        self.batteryStatusBGView.backgroundColor = [UIColor whiteColor];
        self.batteryStatusLabel.text = @"-";
    }

    if (self.beacon.vendorFirmwareVersion) {
        self.firmwareVersionLabel.text = self.beacon.vendorFirmwareVersion;
    } else {
        self.firmwareVersionLabel.text = @"-";
    }

    self.deviceIDLabel.text = self.beacon.vendorIdentifier;
    self.transmissionPowerLabel.text = [NSString stringWithFormat:@"%d", self.beacon.transmissionPower];
    self.signalIntervalLabel.text = [NSString stringWithFormat:@"%d", self.beacon.transmissionInterval];
    [self markFieldsThatNeedUpdate];


    NSString *notificationMessage;
    BCLAction *testAction = [[BeaconCtrlManager sharedManager] testActionForBeacon:self.beacon];
    if (testAction) {
        notificationMessage = [testAction.customValues firstObject][@"value"];
        self.selectedTrigger = [self triggerFromName:[((BCLConditionEvent *)testAction.trigger.conditions.firstObject) eventType]];
    }
    self.notificationMessage = notificationMessage;

    self.selectedFloor = self.beacon.location.floor;
}

- (void)markFieldsThatNeedUpdate
{
    if (self.beacon.needsFirmwareUpdate) {
        self.firmwareVersionBGView.backgroundColor = [UIColor redAppColor];
        self.firmwareVersionLabel.textColor = [UIColor whiteColor];
    } else {
        self.firmwareVersionBGView.backgroundColor = [UIColor whiteColor];
        self.firmwareVersionLabel.textColor = [UIColor blackColor];
    }

    if (self.beaconIsKontakt && [self.beacon.fieldsToUpdate.allKeys containsObject:@"proximity"]) {
        self.uuidTextField.textColor = [UIColor redAppColor];
    } else {
        self.uuidTextField.textColor = [UIColor blackColor];
    }

    if (self.beaconIsKontakt && [self.beacon.fieldsToUpdate.allKeys containsObject:@"major"]) {
        self.majorTextField.textColor = [UIColor redAppColor];
    } else {
        self.majorTextField.textColor = [UIColor blackColor];
    }

    if (self.beaconIsKontakt && [self.beacon.fieldsToUpdate.allKeys containsObject:@"minor"]) {
        self.minorTextField.textColor = [UIColor redAppColor];
    } else {
        self.minorTextField.textColor = [UIColor blackColor];
    }

    if (self.beaconIsKontakt && [self.beacon.fieldsToUpdate.allKeys containsObject:@"interval"]) {
        self.signalIntervalLabel.attributedText = [self attributedStringWithValue:[NSString stringWithFormat:@"%d", self.beacon.transmissionInterval] updatedValue:self.beacon.fieldsToUpdate[@"interval"]];
    }

    if (self.beaconIsKontakt && [self.beacon.fieldsToUpdate.allKeys containsObject:@"power"]) {
        self.transmissionPowerLabel.attributedText = [self attributedStringWithValue:[NSString stringWithFormat:@"%d", self.beacon.transmissionPower] updatedValue:self.beacon.fieldsToUpdate[@"power"]];
    }
}

- (NSAttributedString *)attributedStringWithValue:(NSString *)value updatedValue:(NSString *)updatedValue
{
    NSMutableAttributedString *attributedString = [NSMutableAttributedString new];

    NSDictionary *redTextAttributes = @{
            NSForegroundColorAttributeName : [UIColor redAppColor]
    };

    NSDictionary *blackTextAttributes = @{
            NSForegroundColorAttributeName : [UIColor blackColor]
    };

    [attributedString appendAttributedString:[[NSAttributedString alloc] initWithString:value
                                                                             attributes:redTextAttributes]];

    [attributedString appendAttributedString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@" (%@)", updatedValue]
                                                                             attributes:blackTextAttributes]];

    return [attributedString copy];
}

- (BCLEventType)triggerFromName:(NSString *)triggerName
{
    if ([triggerName isEqualToString:@"enter"]) {
        return BCLEventTypeEnter;
    } else if ([triggerName isEqualToString:@"leave"]) {
        return BCLEventTypeLeave;
    } else if ([triggerName isEqualToString:@"immediate"]) {
        return BCLEventTypeRangeImmediate;
    } else if ([triggerName isEqualToString:@"near"]) {
        return BCLEventTypeRangeNear;
    } else if ([triggerName isEqualToString:@"far"]) {
        return BCLEventTypeRangeFar;
    }
    
    return BCLEventTypeUnknown;
}

- (void)showUpdateMessages:(BOOL)animated
{
    if (self.beacon) {
        UIViewController *topViewController = self.navigationController.topViewController;

        self.isShowingUpdateMessage = YES;
        if (self.beacon.characteristicsAreBeingUpdated) {
            [topViewController presentMessage:@"Updating beacon's properties..." animated:animated warning:YES completion:nil];
        } else if (self.beacon.needsCharacteristicsUpdate) {
            [topViewController presentMessage:@"This beacon needs to have its properties updated. Move closer to it and wait for a while" animated:animated warning:YES completion:nil];
        } else if (self.beacon.needsFirmwareUpdate) {
            [topViewController presentMessage:@"This beacon needs to have its firmware updated. Move closer to it and wait for a while" animated:animated warning:YES completion:nil];
        } else if (self.beacon.firmwareUpdateProgress > 0 && self.beacon.firmwareUpdateProgress != NSNotFound) {
            [topViewController presentMessage:@"This beacon's firmware is being updated" animated:animated warning:YES completion:nil];
        } else {
            [self hideUpdateMessages:YES];
        }
    }
}

- (void)hideUpdateMessages:(BOOL)animated
{
    UIViewController *topViewController = self.navigationController.topViewController;
    [topViewController hideBannerView:animated];
    self.isShowingUpdateMessage = NO;

    if (topViewController == self) {
        [UIView animateWithDuration:animated ? 0.5 : 0.0 animations:^{
            UIEdgeInsets contentInset = self.scrollView.contentInset;
            contentInset.top = 0;
            self.scrollView.contentInset = contentInset;
            self.scrollView.contentOffset = CGPointZero;
        }];
    }
}

#pragma mark - Accessors

- (BOOL)showingKeyboard
{
   return  [self.beaconNameTextField isFirstResponder] ||
    [self.latitudeTextField isFirstResponder] ||
    [self.longitudeTextField isFirstResponder] ||
    [self.majorTextField isFirstResponder] ||
    [self.minorTextField isFirstResponder] ||
    [self.uuidTextField isFirstResponder];
}

- (BOOL)beaconIsKontakt
{
    return [self.beacon.vendor isEqualToString:@"Kontakt"];
}

- (void)setBeacon:(BCLBeacon *)beacon
{
    _beacon = beacon;
    [self updateView];
    
    if (beacon) {
        [self showUpdateMessages:YES];
    } else {
        [self hideUpdateMessages:YES];
    }
}

- (void)setNotificationMessage:(NSString *)notificationMessage
{
    _notificationMessage = notificationMessage;
    self.notificationMessageLabel.text = notificationMessage;
}

- (void)setSelectedZone:(BCLZone *)zone
{
    _selectedZone = zone;
    NSString *zoneName = zone.name?:@"Unassigned";
    UIColor *zoneColor = zone.color?:[UIColor colorWithRed:0.38 green:0.73 blue:0.91 alpha:1];

    self.zoneColorBadge.backgroundColor = zoneColor;
    self.zoneButtonBadge.backgroundColor = zoneColor;
    self.zoneNameLabel.text = zoneName;
    self.zoneButtonTitleLabel.text = zoneName;
}

- (void)setSelectedFloor:(NSNumber *)selectedFloor
{
    _selectedFloor = selectedFloor;
    self.zoneButtonFloorLabel.text = [NSString stringWithFormat:@"%@", selectedFloor ? : @"None"];
}

- (void)setSelectedVendor:(NSString *)selectedVendor
{
    _selectedVendor = selectedVendor ?: @"Other";
    self.vendorNameLabel.text = _selectedVendor;
}

- (void)setBeaconMode:(BCLBeaconDetailsMode)beaconMode
{
    _beaconMode = beaconMode;
    switch (beaconMode) {
        case kBCLBeaconModeNew:
            self.floorTitleLabel.text = @"Floor:";
            self.floorNumberLabel.text = [NSString stringWithFormat:@"%@", self.beacon.location.floor ? : @"None"];
            self.navigationItem.rightBarButtonItem = self.barButton;
            self.barButton.title = @"Save";
            self.barButton.tintColor = [UIColor blueAppColor];
            self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Cancel" style:UIBarButtonItemStylePlain target:self action:@selector(cancelButtonPressed)];
            [self setEditingEnabled:[self.parentViewController isKindOfClass:[UINavigationController class]]];
            [self setDeleteButtonVisible:NO];
            break;
        case kBCLBeaconModeEdit:
            self.floorTitleLabel.text = @"Floor:";
            self.floorNumberLabel.text = [NSString stringWithFormat:@"%@", self.beacon.location.floor ? : @"None"];
            self.navigationItem.rightBarButtonItem = self.barButton;
            self.barButton.title = @"Save";
            self.barButton.tintColor = [UIColor blueAppColor];
            self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Cancel" style:UIBarButtonItemStylePlain target:self action:@selector(cancelButtonPressed)];
            [self setEditingEnabled:YES animated:YES];
            [self setDeleteButtonVisible:YES];
            break;
        case kBCLBeaconModeDetails:
            self.floorTitleLabel.text = @"Floor:";
            self.floorNumberLabel.text = [NSString stringWithFormat:@"%@", self.beacon.location.floor ? : @"None"];
            self.navigationItem.rightBarButtonItem = self.barButton;
            self.barButton.title = @"Edit";
            self.barButton.tintColor = [UIColor blackColor];
            self.navigationItem.leftBarButtonItem = nil;
            self.navigationItem.hidesBackButton = NO;
            [self setEditingEnabled:NO animated:YES];
            [self setDeleteButtonVisible:NO];
            break;
        case kBCLBeaconModeHidden:
            self.floorTitleLabel.text = @"Beacon:";
            self.floorNumberLabel.text = [BeaconCtrlManager sharedManager].beaconCtrl.closestBeacon.name ? : @"No beacon in range";
            self.selectedZone = [BeaconCtrlManager sharedManager].beaconCtrl.currentZone;
            self.barButton.tintColor = [UIColor blackColor];
            self.navigationItem.leftBarButtonItem = nil;
            self.navigationItem.hidesBackButton = NO;
            [self setDeleteButtonVisible:NO];
            break;
    }
}

- (void)setDeleteButtonVisible:(BOOL)visible
{
    [UIView animateWithDuration:0.25 animations:^{
        self.confirmButton.alpha = visible;
        self.deleteButtonViewHeightConstraint.constant = visible ? 80 : 0;
        [self.view layoutIfNeeded];
    }];
}

- (void)cancelButtonPressed
{
    switch (self.beaconMode) {
        case kBCLBeaconModeNew:
            if (![self hideKeyboardIfNeeded]) {
                [self.navigationController popViewControllerAnimated:YES];
            }
            break;
        case kBCLBeaconModeEdit:
            [self updateView];
            self.beaconMode = kBCLBeaconModeDetails;
            break;
        case kBCLBeaconModeDetails:break;
        case kBCLBeaconModeHidden:break;
    }
}

- (void)setEditingEnabled:(BOOL)enabled
{
    [self setEditingEnabled:enabled animated:NO];
}

- (void)setEditingEnabled:(BOOL)enabled animated:(BOOL)animated
{
    _editingEnabled = enabled;
    self.zonesDisclosureIndicatorImage.hidden = !enabled;
    self.notificationsDisclosureIndicatorImage.hidden = !enabled;
    self.vendorDisclosureIndicator.hidden = !enabled || self.beaconIsKontakt;
    self.minorTextField.enabled = enabled && !self.beaconIsKontakt;
    self.beaconNameTextField.enabled = enabled;
    self.latitudeTextField.enabled = enabled;
    self.longitudeTextField.enabled = enabled;
    self.majorTextField.enabled = enabled && !self.beaconIsKontakt;
    self.uuidTextField.enabled = enabled && !self.beaconIsKontakt;
    self.zoneButton.userInteractionEnabled = enabled;
    self.notificationsButton.userInteractionEnabled = enabled;
    [self setEditableTextFieldBackgroundsVisible:enabled animated:animated];
}

- (void)setEditableTextFieldBackgroundsVisible:(BOOL)visible
{
    [self setEditableTextFieldBackgroundsVisible:visible animated:NO];
}

- (void)setEditableTextFieldBackgroundsVisible:(BOOL)visible animated:(BOOL)animated
{
    [UIView animateWithDuration:animated ? .25 : 0.0 animations:^{
        for (UIView *view in self.editableTextFieldsBackgrounds) {
            view.backgroundColor = [view.backgroundColor colorWithAlphaComponent:visible];
        }
        self.uuidViewHeightConstraint.constant = (visible && !self.beaconIsKontakt) ? 40.0f : 30.0f;
        self.latitudeViewHeightConstraint.constant = visible ? 40.0f : 30.0f;
        [self.view layoutIfNeeded];
    }];
}

- (NSArray *)editableTextFieldsBackgrounds
{
    NSMutableArray *mutableArray = [NSMutableArray new];
    [self.scrollView.subviews[0].subviews enumerateObjectsUsingBlock:^(UIView * view, NSUInteger idx, BOOL *stop) {
        if ((view.tag == BCLEditableTextFieldBGTag && !self.beaconIsKontakt) || view.tag == BCLKontaktEditableTextFieldBGTag) {
            [mutableArray addObject:view];
        }
    }];

    return [mutableArray copy];
}

- (BeaconCtrlManager *)bclManager
{
    return [BeaconCtrlManager sharedManager];
}

#pragma mark - Zones View Controller Delegate

- (void)zonesViewController:(BLCZonesViewController *)viewController didSelectedZone:(BCLZone *)zone
{
    self.selectedZone = zone;
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)zonesViewController:(BLCZonesViewController *)viewController didSelectedFloor:(NSNumber *)floorNumber
{
    self.selectedFloor = floorNumber;
}

#pragma mark - UITextField delegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    if (textField == self.uuidTextField) {
        [self.majorTextField becomeFirstResponder];
    } else if (textField == self.minorTextField) {
        [self.latitudeTextField becomeFirstResponder];
    } else if (textField == self.longitudeTextField) {
        [textField resignFirstResponder];
    }
    return NO;
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    if (textField == self.uuidTextField) {
        return [self.uuidFormatter textField:textField shouldChangeCharactersInRange:range replacementString:string];
    }
    return YES;
}

#pragma mark - UIAlertView delegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    __weak BCLBeaconDetailsViewController *weakSelf = self;
    if (buttonIndex == 1) {
        [self showActivityIndicatorViewAnimated:YES];
        self.navigationItem.rightBarButtonItem.enabled = NO;
        self.navigationItem.leftBarButtonItem.enabled = NO;
        [self.bclManager deleteBeacon:self.beacon completion:^(BOOL success, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (success) {
                    if ([weakSelf.delegate respondsToSelector:@selector(beaconDetailsViewController:didDeleteBeacon:)]) {
                        [weakSelf.delegate beaconDetailsViewController:self didDeleteBeacon:weakSelf.beacon];
                    }
                } else {
                    [[AlertControllerManager sharedManager] presentError:error inViewController:self completion:nil];
                }
                [self hideActivityIndicatorViewAnimated:YES];
                self.navigationItem.rightBarButtonItem.enabled = YES;
                self.navigationItem.leftBarButtonItem.enabled = YES;
            });
        }];
    }
}

#pragma mark - BCLNotificationSetupViewController Delegate

- (void)notificationSetupViewController:(BCLNotificationSetupViewController *)controller didSetupNotificationMessage:(NSString *)message trigger:(BCLEventType)trigger
{
    [self.navigationController popViewControllerAnimated:YES];
    self.notificationMessage = message;
    self.selectedTrigger = trigger;
}


#pragma mark - Navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.destinationViewController isKindOfClass:[BCLNotificationSetupViewController class]]) {
        BCLNotificationSetupViewController *viewController = (BCLNotificationSetupViewController *) segue.destinationViewController;
        viewController.delegate = self;
        viewController.notificationMessage = self.notificationMessage;
        viewController.chosenTrigger = self.selectedTrigger;
    } else if ([segue.destinationViewController isKindOfClass:[BCLVendorChoiceViewController class]]) {
        BCLVendorChoiceViewController *vendorChoiceViewController = (BCLVendorChoiceViewController *) segue.destinationViewController;
        vendorChoiceViewController.delegate = self;
        vendorChoiceViewController.selectedVendor = self.selectedVendor;
    }
}

- (BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(nullable id)sender
{
    if ([identifier isEqualToString:BCLShowVendorChoiceSegueIdentifier]) {
        return (self.editingEnabled && !self.beaconIsKontakt && ![self hideKeyboardIfNeeded]);
    }

    return YES;
}

#pragma mark BCLVendorChoiceViewControllerDelegate

- (void)vendorChoiceViewController:(BCLVendorChoiceViewController *)viewController didChooseVendor:(NSString *)vendor
{
    self.selectedVendor = vendor;
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)vendorChoiceViewControllerDidCancel:(BCLVendorChoiceViewController *)viewController
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
