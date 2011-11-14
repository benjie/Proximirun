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
-(void)runInRangeEvents {
	if (IS_CHECKED(akPlaySoundCheck)) {
		[[NSSound soundNamed:@"Blow"] play];
	}
	if (IS_CHECKED(akRunAppleScriptCheck)) {
		[akScriptController runScript:self];
	}
}
-(void)runOutOfRangeEvents {
	if (IS_CHECKED(afkPlaySoundCheck)) {
		[[NSSound soundNamed:@"Basso"] play];
	}
	if (IS_CHECKED(afkRunAppleScriptCheck)) {
		[afkScriptController runScript:self];
	}
}

#pragma mark - Update user interface methods
-(void)updatedSelectedDevice {
	if (device) {
		[selectDeviceButton setKeyEquivalent:@""];
		[statusItem setTitle:@"-unknown-"];
		[chosenDeviceLabel setStringValue:SWF(@"%@ [%@]",[device name],[device addressString])];
		[connectNowButton setEnabled:YES];
	} else {
		[statusItem setTitle:@"No device"];
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
		if (IS_CHECKED(warnIfAFKAndInUseCheck)) {
			//Growl
			if ([GrowlApplicationBridge isGrowlRunning]) {
				NSData *data = [NSData dataWithContentsOfFile:@"eye-150.jpg"];
				[GrowlApplicationBridge notifyWithTitle:@"Proximirun" description:SWF(@"Device out of range, but computer active - decrease required RSSI? RSSI: %i",currentRSSI) notificationName:@"Out of range but not idle" iconData:data priority:0 isSticky:NO clickContext:@"AFKWhenInUse"];
			}
			
		}
		if (IS_CHECKED(noAFKWhenInUseCheck)) {
			iir = YES;
			overridden = YES;
			NSLog(@"Overriding AFK - computer is in use.");
		}
	} else if (deviceRange == PRDeviceRangeOutOfRange && iir && [self idleTime] > [monitoringIntervalTextField intValue]) {
		if (IS_CHECKED(noAKWhenNotInUse)) {
			NSLog(@"Overriding AK - computer is not in use");
			iir = NO;
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
		if (retry++ < 2) {
			NSLog(@"Could not connect to device, retry %i/3",retry+1);
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
	return MAX(0,CGEventSourceSecondsSinceLastEventType(kCGEventSourceStateCombinedSessionState, kCGAnyInputEventType) - kIdleTimeFiddle);
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
-(NSURL *)userDataURL {
	NSArray *folders = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
	NSError *error;
	if (folders && [folders count]) {
		NSString *folder = [[folders objectAtIndex:0] stringByAppendingPathComponent:@"Proximirun"];
		if ([[NSFileManager defaultManager] fileExistsAtPath:folder] || [[NSFileManager defaultManager] createDirectoryAtPath:folder withIntermediateDirectories:NO attributes:nil error:&error]) {
			return [NSURL fileURLWithPath:folder];
		} else {
			NSLog(@"Error occurred creating user data folder: %@",error);
		}
	}
	return nil;
}
-(NSURL *)akScriptURL {
	return [[self userDataURL] URLByAppendingPathComponent:@"akScript.scpt"];
}
-(NSURL *)afkScriptURL {
	return [[self userDataURL] URLByAppendingPathComponent:@"afkScript.scpt"];
}
-(void)loadScripts {
	OSAScript *script;
#define LOAD_SCRIPT(URL,CONTROLLER,VIEW,DEFAULT) \
	if (URL) {\
		if ([[NSFileManager defaultManager] fileExistsAtPath:[URL path]]) {\
			script = [[OSAScript alloc] initWithContentsOfURL:URL error:nil];\
		} else {\
			script = [[OSAScript alloc] initWithSource:DEFAULT];\
			[script writeToURL:URL ofType:@"scpt" error:nil];\
		}\
		if (script) {\
			[CONTROLLER setScript:script];\
		}\
		[VIEW setSource:[script source]];\
		RELEASE(script);\
	}\
	[CONTROLLER compileScript:self];

	NSString *air = @"on IsRunning(appName)\ntell application \"System Events\" to set result to exists (processes where name is appName)\nreturn result\nend IsRunning";
	LOAD_SCRIPT([self akScriptURL],akScriptController,akScriptView,SWF(@"if IsRunning(\"Skype\") then\ntell application \"Skype\"\nsend command \"SET USERSTATUS ONLINE\" script name \"Proximirun\"\nend tell\nend if\ntell application \"Finder\"\ndo shell script \"afplay '/System/Library/Sounds/Blow.aiff'\"\nend tell\n%@",air));
	LOAD_SCRIPT([self afkScriptURL],afkScriptController,afkScriptView,SWF(@"if IsRunning(\"Skype\") then\ntell application \"Skype\"\nsend command \"SET USERSTATUS AWAY\" script name \"Proximirun\"\nend tell\nend if\ntell application \"Finder\"\ndo shell script \"afplay '/System/Library/Sounds/Basso.aiff'\"\nend tell\n%@",air));

}
-(void)saveScripts {
	if (akScriptViewIsDirty) {
		OSAScript *script = [[OSAScript alloc] initWithSource:[akScriptView source]];
		[script writeToURL:[self akScriptURL] ofType:@"scpt" error:nil];	
		RELEASE(script);
		akScriptViewIsDirty = NO;
	}
	if (afkScriptViewIsDirty) {
		OSAScript *script = [[OSAScript alloc] initWithSource:[afkScriptView source]];
		[script writeToURL:[self afkScriptURL] ofType:@"scpt" error:nil];	
		RELEASE(script);
		afkScriptViewIsDirty = NO;
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

	
	
	//[akScriptController setScript:[[[OSAScript alloc] initWithSource:] autorelease]];
	//[akScriptView setString:];
	if (trustDisplay) {
		[self saveScripts];
	} else {
		[self loadScripts];
	}

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
-(void)receiveSleepNote:(id)sender {
	if ([NSApp isActive]) {
		[self synchronizeSettings:YES];
	}
}
-(void)receiveWakeNote:(id)sender {
	if (inProgress) return;
	if (deviceRange == PRDeviceRangeOutOfRange) {
		if (IS_CHECKED(noAFKWhenInUseCheck)) {
			//Force in range.
			[self setDeviceIsInRange:YES];
		} else if (IS_CHECKED(noAKWhenNotInUse) && currentRSSI >= [requiredRSSITextField intValue] && currentRSSI <= 20) {
			// Device is in range, screen woke, but we're not here
			// Make us here!
			[self setDeviceIsInRange:YES];
		}
	}
}
-(void)applicationWillTerminate:(NSNotification *)notification {
	[self synchronizeSettings:YES];
	[[NSUserDefaults standardUserDefaults] synchronize];
}
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	// Uncomment next line to clear settings.
	//[[NSUserDefaults standardUserDefaults] removePersistentDomainForName:[[NSBundle mainBundle] bundleIdentifier]];
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
		if (device) {
			[connectNowButton setEnabled:YES];
		}
	}
	[self synchronizeSettings:NO];
	[monitoringIntervalTextField setIntegerValue:[[NSUserDefaults standardUserDefaults] integerForKey:@"monitoringInterval"]];
	[self check:monitoringEnabledCheck withSetting:@"monitoringEnabled"];
	[self check:akPlaySoundCheck withSetting:@"akPlaySound"];
	[self check:akRunAppleScriptCheck withSetting:@"akRunAppleScript"];
	[self updatedSelectedDevice];
	
	if ([monitoringEnabledCheck state] == NSOnState) {
		[self performSelector:@selector(monitor) withObject:nil afterDelay:0];
	}
	if (!device) {
		[self openPreferencesMenuItemPressed:self];
		[selectDeviceButton becomeFirstResponder];
	}
	
	[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver: self 
														   selector: @selector(receiveWakeNote:) 
															   name: NSWorkspaceDidWakeNotification object: NULL];
	[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver: self 
														   selector: @selector(receiveSleepNote:) 
															   name: NSWorkspaceWillSleepNotification object: NULL];

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
-(void)modalSheetDidEnd {
	NSArray *results = [dsc getResults];
	RELEASE(dsc);
	if (!results || [results count] == 0) {
		return;
	}
	RELEASE(device);
	device = [[results objectAtIndex:0] retain];
	[connectNowButton setEnabled:YES];
	[self updatedSelectedDevice];
	[[NSUserDefaults standardUserDefaults] setValue:[device addressString] forKey:@"device"];
	[self synchronizeSettings:YES];
	if (IS_CHECKED(monitoringEnabledCheck)) {
		[self monitor];
	}	
}

- (IBAction)selectDeviceButtonPressed:(id)sender {
	dsc = [[IOBluetoothDeviceSelectorController deviceSelector] retain];
	[dsc beginSheetModalForWindow:preferencesWindow modalDelegate:self didEndSelector:@selector(modalSheetDidEnd) contextInfo:NULL];
	//[dsc runModal];
	
	
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

- (IBAction)akOpenInAppleScriptEditorButtonPressed:(id)sender {
	//alreadyRunningApplications = [[[NSWorkspace sharedWorkspace] runningApplications] retain];
	[[NSWorkspace sharedWorkspace] openURLs:[NSArray arrayWithObject:[self akScriptURL]] withAppBundleIdentifier:kEditorIdentifier options:NSWorkspaceLaunchWithoutAddingToRecents/*|NSWorkspaceLaunchNewInstance*/ additionalEventParamDescriptor:nil launchIdentifiers:NULL];
	//[self performSelector:@selector(findNewApp) withObject:nil afterDelay:0];
}

- (IBAction)afkOpenInAppleScriptEditorButtonPressed:(id)sender {
	[[NSWorkspace sharedWorkspace] openURLs:[NSArray arrayWithObject:[self afkScriptURL]] withAppBundleIdentifier:kEditorIdentifier options:NSWorkspaceLaunchWithoutAddingToRecents/*|NSWorkspaceLaunchNewInstance*/ additionalEventParamDescriptor:nil launchIdentifiers:NULL];
}
-(void)findNewApp {
	NSMutableArray *nowRunningApplications = [NSMutableArray arrayWithArray:[[NSWorkspace sharedWorkspace] runningApplications]];
	for (NSInteger i = [nowRunningApplications count]-1; i>=0; i--) {
		NSRunningApplication *app = [nowRunningApplications objectAtIndex:i];
		if ([alreadyRunningApplications containsObject:app]) {
			[nowRunningApplications removeObjectAtIndex:i];
		} else if (![[app bundleIdentifier] isEqualToString:kEditorIdentifier]) {
			[nowRunningApplications removeObjectAtIndex:i];
		}
	}
	RELEASE(alreadyRunningApplications);
	if ([nowRunningApplications count] == 1) {
		NSRunningApplication *app = [nowRunningApplications objectAtIndex:0];
		NSLog(@"Found app: %@",app);
	} else {
		[NSAlert alertWithMessageText:@"Could not locate spawned external editor" defaultButton:@"Okay" alternateButton:nil otherButton:nil informativeTextWithFormat:@"%i matching applications were found",[nowRunningApplications count]];
	}
	/*
	if ([[NSWorkspace sharedWorkspace] launchApplication:@"AppleScript Editor"]) {
		NSArray *apps = [NSRunningApplication runningApplicationsWithBundleIdentifier:];
		if (apps && [apps count]) {
			NSRunningApplication *app = [apps objectAtIndex:0];
		}
	}*/
	
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
-(void)applicationDidBecomeActive:(NSNotification *)notification {
//-(void)windowDidBecomeKey:(NSNotification *)notification {
	[self loadScripts];
	[akScriptController compileScript:self];
	NSLog(@"Key");
}
-(void)applicationDidResignActive:(NSNotification *)notification {
//-(void)windowDidResignKey:(NSNotification *)notification {
	[self saveScripts];
	NSLog(@"Resign key");
	[self synchronizeSettings:YES];
}
- (BOOL)textView:(NSTextView *)textView shouldChangeTextInRanges:(NSArray *)affectedRanges replacementStrings:(NSArray *)replacementStrings {
	if (textView == akScriptView) {
		akScriptViewIsDirty = YES;
	} else if (textView == afkScriptView) {
		afkScriptViewIsDirty = YES;
	}
	[self performSelector:@selector(save) withObject:nil afterDelay:0];
	return YES;
}
-(void)save {
	[self synchronizeSettings:YES];
}
@end
