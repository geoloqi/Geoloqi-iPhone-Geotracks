This is one of the official iPhone client applications for Geoloqi. This
application provides functionality for sharing your location in realtime.
It consumes the Geoloqi iOS SDK and is one example of what can be
accomplished using the library.

You can download this application from [iTunes App Store][app-store-link].

## Getting Started

First, open LQConfig.h from the XCode project or in your favorite text editor.
Insert your API credentials here:

    static NSString *const LQ_APIKey = @"XXX";
    static NSString *const LQ_APISecret = @"YYY";

These credentials can be found on your application page [Geoloqi Applications][geoloqi-applications]

After that, you may need to change the bundle identifier.

Finally, plug in your iPhone, and run the app.

## License

Copyright 2012 by [Geoloqi.com][geoloqi-site] and contributors.

See LICENSE.

[geoloqi-site]: https://geoloqi.com/
[geoloqi-dev-site]: https://developers.geoloqi.com/
[app-store-link]: http://itunes.apple.com/us/app/
[geoloqi-applications]: https://developers.geoloqi.com/account/applications
[push-notification-setup]: https://developers.geoloqi.com/ios/push-notifications
