Proximirun
==========

OSX bluetooth proximity-based script-runner.

What?
----

This utility app monitors a Bluetooth device (such as an iPhone) and
runs Apple Script when it comes into/goes out of range.

How?
----
It monitors the [RSSI][] value for the connection, and then runs the
configured Apple Script.

Why?
----
I wanted to lock my screen/go "away" on Skype when I left the room
unexpectedly without time to do it myself.

Where?
------
Mac only, I'm afraid. I've had it running on Lion, have not tested it
elsewhere.

When?
-----
When the bluetooth device goes out of (or in to) range... Were you not
reading the above?

Installation
============
Get Xcode from the App Store, clone this repo locally and then open
Proximirun.xcodeproj into Xcode and run.

Running
=======
This app runs as a utility/background process, so it is only visible in
the status bar (at the top). Unfortunately because I'm terrible at
graphics it only has words currently, but if someone fancies making
graphics...

Contributing
============
If anyone fancies making a logo or graphics to put into the header
bar then I will be very grateful - same goes for an Icon image!

Unsolicited pull requests welcome, so long as they are concise and well
explained. Longer pull requests probably best to contact me first :)

License
=======
[MIT License][]

[RSSI]: http://en.wikipedia.org/wiki/Received_signal_strength_indication
[MIT License]: http://benjie.mit-license.org/
