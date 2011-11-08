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


- (BOOL)isInRange {
	BluetoothHCIRSSIValue RSSI = 127; /* Valid Range: -127 to +20 */
	if (device) {
		[deviceActivityIndicator startAnimation:nil];
		if (![device isConnected]) {
			[device openConnection];//:nil withPageTimeout:BluetoothGetSlotsFromSeconds(2) authenticationRequired:NO];
		}
		if ([device isConnected]) {
			RSSI = [device rawRSSI];
			[device closeConnection];
		}
		[deviceActivityIndicator stopAnimation:nil];
	}
	if (RSSI > 20) {
		[currentRSSILabel setStringValue:[NSString stringWithFormat:@"%i - out of range",RSSI]];
	} else {
		[currentRSSILabel setStringValue:[NSString stringWithFormat:@"%i",RSSI]];
	}
	if (RSSI >= [requiredRSSITextField intValue] && RSSI <= 20) {
		[currentRSSILabel setTextColor:[NSColor colorWithDeviceRed:0 green:0.75 blue:0 alpha:1]];
		return YES;
	} else {
		[currentRSSILabel setTextColor:[NSColor redColor]];
		return NO;
	}
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
	if ([self isInRange]) {
		//...
	}
}

- (IBAction)selectDeviceButtonPressed:(id)sender {
}
- (IBAction)connectNowButtonPressed:(id)sender {
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
@end
