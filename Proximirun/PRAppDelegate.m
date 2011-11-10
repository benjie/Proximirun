//
//  PRAppDelegate.m
//  Proximirun
//
//  Created by Benjie Gillam on 07/11/2011.
//  Copyright (c) 2011 BrainBakery Ltd. All rights reserved.
//

#import "PRAppDelegate.h"
#import <ApplicationServices/ApplicationServices.h>
#import <CoreServices/CoreServices.h>
#define IS_CHECKED(X) ([X state] == NSOnState)

@implementation PRAppDelegate

@synthesize window = _window;
#pragma mark - Growl
- (void) growlNotificationWasClicked:(id)clickContext {
	if ([clickContext isEqual:@"AFKWhenInUse"]) {
		[self openPreferencesMenuItemPressed:nil];
	}
}
#pragma mark - Events
-(void)runScriptForSetting:(NSString *)key {
	NSURL *url = [[NSUserDefaults standardUserDefaults] URLForKey:key];
	if (url) {
		NSDictionary *error = nil;
		NSAppleScript *s = [[NSAppleScript alloc] initWithContentsOfURL:url error:&error];
		if (s && !error) {
			[s executeAndReturnError:&error];
		}
		RELEASE(s);
	}
}
-(void)runInRangeEvents {
	if (IS_CHECKED(akPlaySoundCheck)) {
		[[NSSound soundNamed:@"Blow"] play];
	}
	if (IS_CHECKED(akRunAppleScriptCheck)) {
		[self runScriptForSetting:@"akAppleScriptURL"];
	}
}
-(void)runOutOfRangeEvents {
	if (IS_CHECKED(afkPlaySoundCheck)) {
		[[NSSound soundNamed:@"Basso"] play];
	}
	if (IS_CHECKED(afkRunAppleScriptCheck)) {
		[self runScriptForSetting:@"afkAppleScriptURL"];
	}
}

#pragma mark - Update user interface methods
-(void)updatedSelectedDevice {
	if (device) {
		[chosenDeviceLabel setStringValue:SWF(@"%@ [%@]",[device name],[device addressString])];
		[connectNowButton setEnabled:YES];
	} else {
		[chosenDeviceLabel setStringValue:@"Press 'select device' below to select device"];
		[connectNowButton setEnabled:NO];
	}
}

#pragma mark -
-(void)scheduleMonitor {
	if (!monitorTimer && [monitoringEnabledCheck state] == NSOnState) {
		int interval = [monitoringIntervalTextField intValue];
		if (deviceRange == PRDeviceRangeInRange) {
			interval -= (2*retry);
		}
		if (interval < 1) interval = 1;
		monitorTimer = [[NSTimer scheduledTimerWithTimeInterval:interval target:self selector:@selector(monitor) userInfo:nil repeats:NO] retain];
	}
}
-(void)setDeviceIsInRange:(BOOL)iir {
	[currentRSSILabel setTextColor:(iir?[NSColor colorWithDeviceRed:0 green:0.75 blue:0 alpha:1]:[NSColor redColor])];
	inProgress = NO;
	[self scheduleMonitor];	
	[deviceActivityIndicator performSelector:@selector(stopAnimation:) withObject:nil afterDelay:0.2];
	BOOL overridden = NO;
	if (!iir && [self idleTime] < [monitoringIntervalTextField intValue]) {
		if (warnIfAFKAndInUseCheck) {
			//Growl
			if ([GrowlApplicationBridge isGrowlRunning]) {
				NSData *data = [NSData dataWithContentsOfFile:@"eye-150.jpg"];
				[GrowlApplicationBridge notifyWithTitle:@"Proximirun" description:SWF(@"Device out of range, but computer active - decrease required RSSI? RSSI: %i",currentRSSI) notificationName:@"Out of range but not idle" iconData:data priority:0 isSticky:NO clickContext:@"AFKWhenInUse"];
			}
			
		}
		if (IS_CHECKED(noAFKWhenInUseCheck)) {
			iir = YES;
			overridden = YES;
		}
	}
	[statusItem setTitle:(iir?(overridden?@"At Mac (!)":@"In Range"):@"AFK")];
	PRDeviceRange newRange = iir?PRDeviceRangeInRange : PRDeviceRangeOutOfRange;
	if (newRange != deviceRange) {
		deviceRange = newRange;
		if (deviceRange == PRDeviceRangeInRange) {
			[self runInRangeEvents];
		} else {
			[self runOutOfRangeEvents];			
		}
	}
}
-(void)actOnRSSI:(BluetoothHCIRSSIValue)RSSI {
	//BluetoothHCIRSSIValue Valid Range: -127 to +20
	currentRSSI = RSSI;
	[currentRSSILabel setIntValue:RSSI>20?-128:RSSI];
	[currentRSSISlider setIntValue:RSSI>20?-128:RSSI];
	if (RSSI > 20) {
		if (retry < 2) {
			[self performSelector:@selector(connectToDevice) withObject:nil afterDelay:1];
			return;
		} else {
			//Nothing
		}
	} else {
		//Nothing
	}
	[self setDeviceIsInRange:(RSSI >= [requiredRSSITextField intValue] && RSSI <= 20)];
}
-(void)checkRSSI {
	BluetoothHCIRSSIValue RSSI = [device rawRSSI];
	[device closeConnection];
	[self actOnRSSI:RSSI];
}
- (void)remoteNameRequestComplete:(IOBluetoothDevice *)device status:(IOReturn)status {
	
}
- (void)sdpQueryComplete:(IOBluetoothDevice *)device status:(IOReturn)status {
	
}
-(void)connectionComplete:(IOBluetoothDevice *)device status:(IOReturn)status {
	[self checkRSSI];
}
-(void)connectToDevice {
	inProgress = YES;
	[deviceActivityIndicator startAnimation:nil];
	if ([device isConnected] || [device openConnection:self] != kIOReturnSuccess) {
		// Couldn't issue connect command, so skip to next stage.
		[self checkRSSI];
	} else {
		// Fine, continue asynchronously.
	}
}
-(NSTimeInterval)idleTime {
	return CGEventSourceSecondsSinceLastEventType(kCGEventSourceStateCombinedSessionState, kCGAnyInputEventType);
}
#pragma mark -
- (void)dealloc
{
    [super dealloc];
}
-(void)check:(NSButton *)checkBox withSetting:(NSString *)key {
	if ([[NSUserDefaults standardUserDefaults] valueForKey:key]) {
		[checkBox setState:([[NSUserDefaults standardUserDefaults] boolForKey:key]?NSOnState:NSOffState)];
	}
}
-(void)synchronizeSettings:(BOOL)trustDisplay {
#define SYNC_INT(SETTING, INPUT) \
	if (trustDisplay || ![[NSUserDefaults standardUserDefaults] valueForKey:SETTING]) {\
		[[NSUserDefaults standardUserDefaults] setInteger:[INPUT integerValue] forKey:SETTING];\
	} else if ([[NSUserDefaults standardUserDefaults] valueForKey:SETTING]) {\
		[INPUT setIntegerValue:[[NSUserDefaults standardUserDefaults] integerForKey:SETTING]];\
	}
#define SYNC_CHECK(SETTING, INPUT) \
	if (trustDisplay || ![[NSUserDefaults standardUserDefaults] valueForKey:SETTING]) {\
		[[NSUserDefaults standardUserDefaults] setBool:IS_CHECKED(INPUT) forKey:SETTING];\
	} else if ([[NSUserDefaults standardUserDefaults] valueForKey:SETTING]) {\
		[INPUT setState:([[NSUserDefaults standardUserDefaults] boolForKey:SETTING]?NSOnState:NSOffState)];\
	}
	
	SYNC_INT(@"requiredRSSI", requiredRSSISlider);
	[requiredRSSITextField setIntegerValue:[requiredRSSISlider integerValue]];
	
	SYNC_CHECK(@"monitoringEnabled",monitoringEnabledCheck);
	SYNC_INT(@"monitoringInterval", monitoringIntervalTextField);
	SYNC_CHECK(@"triggerEventsOnStart", triggerEventsOnStartCheck);
	SYNC_CHECK(@"noAFKWhenInUse", noAFKWhenInUseCheck);
	SYNC_CHECK(@"warnIfAFKAndInUse", warnIfAFKAndInUseCheck);
	
	SYNC_CHECK(@"akPlaySound",akPlaySoundCheck);
	SYNC_CHECK(@"akRunAppleScript",akRunAppleScriptCheck);
	
	SYNC_CHECK(@"afkPlaySound",afkPlaySoundCheck);
	SYNC_CHECK(@"afkRunAppleScript",afkRunAppleScriptCheck);


	LSSharedFileListRef fileList = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
	UInt32 seed;
	CFArrayRef array = LSSharedFileListCopySnapshot(fileList,&seed);
	BOOL found = NO;
	BOOL enabled = NO;
	OSStatus s = noErr;
	for (CFIndex i = 0, l = CFArrayGetCount(array); i<l; i++) {
		LSSharedFileListItemRef item = (LSSharedFileListItemRef)CFArrayGetValueAtIndex(array, i);
		CFURLRef url = NULL;
		LSSharedFileListItemResolve(item,0,&url,NULL);
		if (url && [[[NSBundle mainBundle] bundleURL] isEqual:(NSURL *)url]) {
			found = YES;
			enabled = YES;
			if (trustDisplay && !IS_CHECKED(startAtLoginCheck)) {
				s = LSSharedFileListItemRemove(fileList,item);
				if (s == noErr){
					NSLog(@"Removed");
					enabled = NO;
				} else {
					NSLog(@"NOT REMOVED! %i",s);
				}
				break;
			}
		}
	}
	if (!found) {
		if (trustDisplay) {
			if (IS_CHECKED(startAtLoginCheck)) {
				LSSharedFileListItemRef item = LSSharedFileListInsertItemURL(fileList,kLSSharedFileListItemLast,CFSTR("Proximirun"),NULL,(CFURLRef)[[NSBundle mainBundle] bundleURL],NULL,NULL);
				if (item) {
					NSLog(@"Added");
					enabled = YES;
				} else {
					NSLog(@"Not added!");
				}
			}
		}
	}
	[startAtLoginCheck setState:(enabled?NSOnState:NSOffState)];
}
-(void)applicationWillTerminate:(NSNotification *)notification {
	[self synchronizeSettings:YES];
	[[NSUserDefaults standardUserDefaults] synchronize];
}
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	[GrowlApplicationBridge setGrowlDelegate:self];
	statusItem = [[[NSStatusBar systemStatusBar] statusItemWithLength:90] retain];
	
	[statusItem setTitle:@"-unknown-"];
	
	[statusItem setMenu:menu];
	[statusItem setToolTip:@"(c) Benjie Gillam"];
	
	[statusItem setHighlightMode:YES];
	// Insert code here to initialize your application
	NSString *deviceString = [[NSUserDefaults standardUserDefaults] valueForKey:@"device"];
	if (deviceString) {
		device = [[IOBluetoothDevice deviceWithAddressString:deviceString] retain];
	}
	[self synchronizeSettings:NO];
	[monitoringIntervalTextField setIntegerValue:[[NSUserDefaults standardUserDefaults] integerForKey:@"monitoringInterval"]];
	[self check:monitoringEnabledCheck withSetting:@"monitoringEnabled"];
	[self check:akPlaySoundCheck withSetting:@"akPlaySound"];
	[self check:akRunAppleScriptCheck withSetting:@"akRunAppleScript"];
	[akAppleScriptTextField setStringValue:[[[NSUserDefaults standardUserDefaults] URLForKey:@"akAppleScriptURL"] path]];
	[afkAppleScriptTextField setStringValue:[[[NSUserDefaults standardUserDefaults] URLForKey:@"afkAppleScriptURL"] path]];
	[self updatedSelectedDevice];
	
	if ([monitoringEnabledCheck state] == NSOnState) {
		[self performSelector:@selector(monitor) withObject:nil afterDelay:0];
	}

}
#pragma mark -
-(void)monitor {
	if (inProgress) return;
	RELEASE_TIMER(monitorTimer);
	retry = 0;
	if (device) {
		[self connectToDevice];
	} else {
		[self scheduleMonitor];
	}
}

- (IBAction)requiredRSSISliderChanged:(id)sender {
	[requiredRSSITextField setIntegerValue:[requiredRSSISlider integerValue]];
}

- (IBAction)selectDeviceButtonPressed:(id)sender {
	IOBluetoothDeviceSelectorController *dsc = [IOBluetoothDeviceSelectorController deviceSelector];
	[dsc runModal];
	
	
	NSArray *results = [dsc getResults];
	if (!results || [results count] == 0) {
		return;
	}
	RELEASE(device);
	device = [[results objectAtIndex:0] retain];
	[self updatedSelectedDevice];
	[[NSUserDefaults standardUserDefaults] setValue:[device addressString] forKey:@"device"];
}
- (IBAction)connectNowButtonPressed:(id)sender {
	[self monitor];
}
-(NSURL *)openScriptURL {
	NSOpenPanel *op = [NSOpenPanel openPanel];
	NSURL *directoryURL = [[NSUserDefaults standardUserDefaults] URLForKey:@"scriptDir"];
	if (!directoryURL) directoryURL = [NSURL URLWithString:NSHomeDirectory()];
	[op setDirectoryURL:directoryURL];
	[op setAllowedFileTypes:[NSArray arrayWithObject:@"scpt"]];
	[op runModal];
	
	directoryURL = [op directoryURL];
	[[NSUserDefaults standardUserDefaults] setURL:directoryURL forKey:@"scriptDir"];
	
	NSArray *URLs = [op URLs];
	if (URLs && [URLs count]>0) {
		NSURL *url = [URLs objectAtIndex:0];
		return url;
	}
	return nil;
}
- (IBAction)akSelectAppleScriptButtonPressed:(id)sender {
	NSURL *url = [self openScriptURL];
	[akAppleScriptTextField setStringValue:[url path]];
	[[NSUserDefaults standardUserDefaults] setURL:url forKey:@"akAppleScriptURL"];
}
- (IBAction)akTestAppleScriptButtonPressed:(id)sender {
	[self runInRangeEvents];
}
- (IBAction)akClearAppleScriptButtonPressed:(id)sender {
	[akAppleScriptTextField setStringValue:@""];
	[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"akAppleScriptURL"];	
}

- (IBAction)afkSelectAppleScriptButtonPressed:(id)sender {
	NSURL *url = [self openScriptURL];
	[afkAppleScriptTextField setStringValue:[url path]];
	[[NSUserDefaults standardUserDefaults] setURL:url forKey:@"afkAppleScriptURL"];
}

- (IBAction)afkTestAppleScriptButtonPressed:(id)sender {
	[self runOutOfRangeEvents];
}

- (IBAction)afkClearAppleScriptButtonPressed:(id)sender {
	[afkAppleScriptTextField setStringValue:@""];
	[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"afkAppleScriptURL"];	
}
-(IBAction)checkChanged:(id)sender {
	[self synchronizeSettings:YES];
	if (IS_CHECKED(monitoringEnabledCheck)) {
		if (!monitorTimer && !inProgress) {
			[self monitor];
		}
	} else {
		RELEASE_TIMER(monitorTimer);
	}
}

- (IBAction)openPreferencesMenuItemPressed:(id)sender {
	if (![preferencesWindow isVisible]) {
		[self synchronizeSettings:NO];
	}
	[preferencesWindow makeKeyAndOrderFront:self];
	[preferencesWindow setOrderedIndex:0];
	[NSApp activateIgnoringOtherApps:YES];
}

- (IBAction)quitMenuItemPressed:(id)sender {
	[NSApp performSelector:@selector(terminate:) withObject:nil afterDelay:0];
}
#pragma mark - Window delegate
-(void)windowWillClose:(NSNotification *)notification {
	[self synchronizeSettings:YES];
}
@end
