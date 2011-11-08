//
//  PRAppDelegate.h
//  Proximirun
//
//  Created by Benjie Gillam on 07/11/2011.
//  Copyright (c) 2011 BrainBakery Ltd. All rights reserved.
//

#import <Cocoa/Cocoa.h>
//#import <IOBluetooth/IOBluetooth.h>
#import <IOBluetoothUI/IOBluetoothUI.h>
//#import <IOBluetoothUI/objc/IOBluetoothDeviceSelectorController.h>

@interface PRAppDelegate : NSObject <NSApplicationDelegate> {
	
	IBOutlet NSTextField *chosenDeviceLabel;
	IBOutlet NSProgressIndicator *deviceActivityIndicator;
	IBOutlet NSTextField *currentRSSILabel;
	IBOutlet NSTextField *requiredRSSITextField;
	IBOutlet NSButton *connectNowButton;
	
	IBOutlet NSButton *monitoringEnabledCheck;
	IBOutlet NSTextField *monitoringIntervalTextField;
	
	
	IOBluetoothDevice *device;
}

@property (assign) IBOutlet NSWindow *window;

- (IBAction)selectDeviceButtonPressed:(id)sender;
- (IBAction)connectNowButtonPressed:(id)sender;
@end
