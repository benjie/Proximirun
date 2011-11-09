//
//  PRAppDelegate.m
//  Proximirun
//
//  Created by Benjie Gillam on 07/11/2011.
//  Copyright (c) 2011 BrainBakery Ltd. All rights reserved.
//

#import "PRAppDelegate.h"

#define IS_CHECKED(X) ([X state] == NSOnState)

@implementation PRAppDelegate

@synthesize window = _window;
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
		if (interval < 1) interval = 1;
		monitorTimer = [[NSTimer scheduledTimerWithTimeInterval:interval target:self selector:@selector(monitor) userInfo:nil repeats:NO] retain];
	}
}
-(void)setDeviceIsInRange:(BOOL)iir {
	[currentRSSILabel setTextColor:(iir?[NSColor colorWithDeviceRed:0 green:0.75 blue:0 alpha:1]:[NSColor redColor])];
	[self scheduleMonitor];	
	inProgress = NO;
	[deviceActivityIndicator performSelector:@selector(stopAnimation:) withObject:nil afterDelay:0.2];
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
	//BluetoothHCIRSSIValue RSSI = 127; /* Valid Range: -127 to +20 */
	if (RSSI > 20) {
		[currentRSSILabel setStringValue:[NSString stringWithFormat:@"%i - out of range",RSSI]];
	} else {
		[currentRSSILabel setStringValue:[NSString stringWithFormat:@"%i",RSSI]];
	}
	[self setDeviceIsInRange:(RSSI >= [requiredRSSITextField intValue] && RSSI <= 20)];
}
-(void)checkRSSI {
	if ([device isConnected]) {
		[self actOnRSSI:[device rawRSSI]];
	} else {
		[self actOnRSSI:127];
	}
}
- (void)remoteNameRequestComplete:(IOBluetoothDevice *)device status:(IOReturn)status {
	
}
- (void)sdpQueryComplete:(IOBluetoothDevice *)device status:(IOReturn)status {
	
}
-(void)connectionComplete:(IOBluetoothDevice *)device status:(IOReturn)status {
	[self checkRSSI];
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
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	// Insert code here to initialize your application
	NSString *deviceString = [[NSUserDefaults standardUserDefaults] valueForKey:@"device"];
	if (deviceString) {
		device = [[IOBluetoothDevice deviceWithAddressString:deviceString] retain];
	}
	[monitoringIntervalTextField setIntegerValue:[[NSUserDefaults standardUserDefaults] integerForKey:@"monitoringInterval"]];
	[self check:monitoringEnabledCheck withSetting:@"monitoringEnabled"];
	[self check:akPlaySoundCheck withSetting:@"akPlaySound"];
	[self check:akRunAppleScriptCheck withSetting:@"akRunAppleScript"];
	[akAppleScriptTextField setStringValue:[[[NSUserDefaults standardUserDefaults] URLForKey:@"akAppleScriptURL"] path]];
	[self updatedSelectedDevice];
	
	if ([monitoringEnabledCheck state] == NSOnState) {
		[self monitor];
	}
}
-(void)monitor {
	if (inProgress) return;
	RELEASE_TIMER(monitorTimer);
	if (device) {
		inProgress = YES;
		[deviceActivityIndicator startAnimation:nil];
		if ([device isConnected] || [device openConnection:self] != kIOReturnSuccess) {
			// Couldn't issue connect command, so skip to next stage.
			[self checkRSSI];
		} else {
			// Fine, continue asynchronously.
		}
	} else {
		[self scheduleMonitor];
	}
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
@end
