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

typedef enum {
	PRDeviceRangeUnknown,
	PRDeviceRangeInRange,
	PRDeviceRangeOutOfRange
} PRDeviceRange;

@interface PRAppDelegate : NSObject <NSApplicationDelegate,IOBluetoothDeviceAsyncCallbacks> {
	
	IBOutlet NSTextField *chosenDeviceLabel;
	IBOutlet NSProgressIndicator *deviceActivityIndicator;
	IBOutlet NSTextField *currentRSSILabel;
	IBOutlet NSTextField *requiredRSSITextField;
	IBOutlet NSButton *connectNowButton;
	
	IBOutlet NSButton *monitoringEnabledCheck;
	IBOutlet NSTextField *monitoringIntervalTextField;
	IBOutlet NSButton *triggerEventsOnStartCheck;
	IBOutlet NSButton *startAtLoginCheck;
	IBOutlet NSButton *noAFKWhenInUseCheck;
	IBOutlet NSButton *warnIfAFKAndInUseCheck;
	
	
	IBOutlet NSButton *akPlaySoundCheck;
	IBOutlet NSButton *akRunAppleScriptCheck;
	IBOutlet NSTextField *akAppleScriptTextField;
	
	IBOutlet NSButton *afkPlaySoundCheck;
	IBOutlet NSButton *afkRunAppleScriptCheck;
	IBOutlet NSTextField *afkAppleScriptTextField;
	
	
	
	IOBluetoothDevice *device;
	NSTimer *monitorTimer;
	BOOL inProgress;
	
	PRDeviceRange deviceRange;
	
	IBOutlet NSMenu *menu;
	IBOutlet NSWindow *preferencesWindow;
	
	NSStatusItem *statusItem;
}

@property (assign) IBOutlet NSWindow *window;

- (IBAction)selectDeviceButtonPressed:(id)sender;
- (IBAction)connectNowButtonPressed:(id)sender;
- (IBAction)akSelectAppleScriptButtonPressed:(id)sender;
- (IBAction)akTestAppleScriptButtonPressed:(id)sender;
- (IBAction)akClearAppleScriptButtonPressed:(id)sender;
- (IBAction)afkSelectAppleScriptButtonPressed:(id)sender;
- (IBAction)afkTestAppleScriptButtonPressed:(id)sender;
- (IBAction)afkClearAppleScriptButtonPressed:(id)sender;
- (void)monitor;
-(IBAction)checkChanged:(id)sender;
- (IBAction)openPreferencesMenuItemPressed:(id)sender;
- (IBAction)quitMenuItemPressed:(id)sender;
@end
