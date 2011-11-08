//
//  PRAppDelegate.m
//  Proximirun
//
//  Created by Benjie Gillam on 07/11/2011.
//  Copyright (c) 2011 BrainBakery Ltd. All rights reserved.
//

#import "PRAppDelegate.h"

@implementation PRAppDelegate

@synthesize window = _window;

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

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	// Insert code here to initialize your application
	NSString *deviceString = [[NSUserDefaults standardUserDefaults] valueForKey:@"device"];
	if (deviceString) {
		device = [[IOBluetoothDevice deviceWithAddressString:deviceString] retain];
	}
	NSNumber *n = [[NSUserDefaults standardUserDefaults] valueForKey:@"monitoringInterval"];
	if (n && [n intValue] > 0) {
		[monitoringIntervalTextField setIntValue:[n intValue]];
	}
	n = [[NSUserDefaults standardUserDefaults] valueForKey:@"monitoringEnabled"];
	if (n) {
		[monitoringEnabledCheck setState:([n boolValue]?NSOnState:NSOffState)];
	}
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
@end
