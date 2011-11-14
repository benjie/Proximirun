//
//  PRAppDelegate.h
//  Proximirun
//
//  Created by Benjie Gillam on 07/11/2011.
//  Copyright (c) 2011 BrainBakery Ltd. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <IOBluetoothUI/IOBluetoothUI.h>
#import <Growl/Growl.h>
#import <OSAKit/OSAKit.h>
#define kEditorIdentifier @"com.apple.ScriptEditor2"
#define kIdleTimeFiddle 15.0
typedef enum {
	PRDeviceRangeUnknown,
	PRDeviceRangeInRange,
	PRDeviceRangeOutOfRange
} PRDeviceRange;

@interface PRAppDelegate : NSObject <NSApplicationDelegate,IOBluetoothDeviceAsyncCallbacks,GrowlApplicationBridgeDelegate, NSWindowDelegate, NSTextViewDelegate> {
	
	IBOutlet NSTextField *chosenDeviceLabel;
	IBOutlet NSProgressIndicator *deviceActivityIndicator;
	IBOutlet NSTextField *currentRSSILabel;
	IBOutlet NSSlider *currentRSSISlider;
	IBOutlet NSTextField *requiredRSSITextField;
	IBOutlet NSSlider *requiredRSSISlider;
	IBOutlet NSButton *selectDeviceButton;
	IBOutlet NSButton *connectNowButton;
	
	IBOutlet NSButton *monitoringEnabledCheck;
	IBOutlet NSTextField *monitoringIntervalTextField;
	IBOutlet NSButton *triggerEventsOnStartCheck;
	IBOutlet NSButton *startAtLoginCheck;
	IBOutlet NSButton *noAFKWhenInUseCheck;
	IBOutlet NSButton *warnIfAFKAndInUseCheck;
	IBOutlet NSButton *noAKWhenNotInUse;
	
	IBOutlet OSAScriptController *akScriptController;
	IBOutlet OSAScriptView *akScriptView;
	BOOL akScriptViewIsDirty;
	
	IBOutlet OSAScriptController *afkScriptController;
	IBOutlet OSAScriptView *afkScriptView;
	BOOL afkScriptViewIsDirty;
	
	IBOutlet NSButton *akPlaySoundCheck;
	IBOutlet NSButton *akRunAppleScriptCheck;
	
	IBOutlet NSButton *afkPlaySoundCheck;
	IBOutlet NSButton *afkRunAppleScriptCheck;
	
	
	IOBluetoothDeviceSelectorController *dsc;
	
	IOBluetoothDevice *device;
	NSTimer *monitorTimer;
	BOOL inProgress;
	int retry;
	
	BluetoothHCIRSSIValue currentRSSI;
	PRDeviceRange deviceRange;
	
	IBOutlet NSMenu *menu;
	IBOutlet NSWindow *preferencesWindow;
	
	NSStatusItem *statusItem;
	
	
	NSArray *alreadyRunningApplications;
}

@property (assign) IBOutlet NSWindow *window;

-(NSURL *)userDataURL;
-(NSURL *)akScriptURL;
-(NSURL *)afkScriptURL;

- (IBAction)requiredRSSISliderChanged:(id)sender;
- (IBAction)selectDeviceButtonPressed:(id)sender;
- (IBAction)connectNowButtonPressed:(id)sender;
- (IBAction)akOpenInAppleScriptEditorButtonPressed:(id)sender;
- (IBAction)afkOpenInAppleScriptEditorButtonPressed:(id)sender;
- (void)monitor;
-(IBAction)checkChanged:(id)sender;
- (IBAction)openPreferencesMenuItemPressed:(id)sender;
- (IBAction)quitMenuItemPressed:(id)sender;
-(NSTimeInterval)idleTime;
@end
