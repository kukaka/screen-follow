#import <AppKit/AppKit.h>
#import <CoreGraphics/CoreGraphics.h>
#import <CoreWLAN/CoreWLAN.h>
#import <os/log.h>

static NSString *const WiFiOffOnLockKey = @"WiFiOffOnLock";
static NSString *const ScreenLockedNotification = @"com.apple.screenIsLocked";
static NSString *const ScreenUnlockedNotification = @"com.apple.screenIsUnlocked";

static NSImage *StatusIcon(void) {
    NSImage *image = [NSImage imageWithSize:NSMakeSize(19, 16)
                                   flipped:NO
                            drawingHandler:^BOOL(NSRect bounds __unused) {
        [NSColor.blackColor setStroke];
        // Draw only the visible edges of the rear screen.
        NSBezierPath *rear = [NSBezierPath bezierPath];
        [rear moveToPoint:NSMakePoint(6.25, 12)];
        [rear curveToPoint:NSMakePoint(7.75, 14.25)
             controlPoint1:NSMakePoint(6.25, 13.6) controlPoint2:NSMakePoint(6.6, 14.25)];
        [rear lineToPoint:NSMakePoint(16, 14.25)];
        [rear curveToPoint:NSMakePoint(17.75, 12.5)
             controlPoint1:NSMakePoint(17, 14.25) controlPoint2:NSMakePoint(17.75, 13.5)];
        [rear lineToPoint:NSMakePoint(17.75, 6.25)];
        [rear curveToPoint:NSMakePoint(16, 4.5)
             controlPoint1:NSMakePoint(17.75, 5.25) controlPoint2:NSMakePoint(17, 4.5)];
        [rear lineToPoint:NSMakePoint(15.5, 4.5)];
        rear.lineWidth = 1.3;
        rear.lineCapStyle = NSLineCapStyleRound;
        [rear stroke];

        NSBezierPath *front = [NSBezierPath bezierPathWithRoundedRect:NSMakeRect(1.25, 2.25, 11.75, 8.75)
                                                              xRadius:1.5 yRadius:1.5];
        front.lineWidth = 1.3;
        [front stroke];
        return YES;
    }];
    image.template = YES;
    return image;
}

static BOOL SetWiFiPower(CWInterface *interface, BOOL power) {
    if (interface.configuration.requireAdministratorForPower) {
        os_log_error(OS_LOG_DEFAULT, "ScreenFollow: Wi-Fi power changes require administrator authentication.");
        return NO;
    }

    NSError *error = nil;
    if ([interface setPower:power error:&error]) return YES;

    os_log_error(OS_LOG_DEFAULT, "ScreenFollow: Unable to turn Wi-Fi %{public}s (%{public}@, %ld).",
                 power ? "on" : "off", error.domain, (long)error.code);
    return NO;
}

@interface ScreenFollow : NSObject <NSApplicationDelegate, NSMenuDelegate>
@end

@implementation ScreenFollow {
    NSStatusItem *_statusItem;
    NSMenuItem *_single;
    NSMenuItem *_dual;
    NSMenuItem *_wifiOffOnLock;
    NSString *_wifiInterfaceToRestore;
}

static BOOL FindDisplays(CGDirectDisplayID *dell, CGDirectDisplayID *main) {
    CGDirectDisplayID displays[8];
    uint32_t count = 0;
    *dell = kCGNullDirectDisplay;
    *main = CGMainDisplayID();
    if (CGGetOnlineDisplayList(8, displays, &count) != kCGErrorSuccess || count != 2) return NO;

    for (uint32_t i = 0; i < count; i++) {
        if (CGDisplayVendorNumber(displays[i]) == 4268 && CGDisplayModelNumber(displays[i]) == 16878) {
            *dell = displays[i];
        }
    }
    if (!*dell || !*main || *dell == *main || !CGDisplayIsActive(*main)) return NO;
    return !CGDisplayIsInMirrorSet(*dell) || CGDisplayMirrorsDisplay(*dell) == *main;
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    _statusItem = [NSStatusBar.systemStatusBar statusItemWithLength:NSVariableStatusItemLength];
    _statusItem.button.image = StatusIcon();
    _statusItem.button.toolTip = @"ScreenFollow";
    [_statusItem.button setAccessibilityLabel:@"ScreenFollow"];
    NSMenu *menu = [[NSMenu alloc] init];
    menu.delegate = self;
    menu.autoenablesItems = NO;
    _single = [menu addItemWithTitle:@"Switch to Single Desktop" action:@selector(singleDesktop) keyEquivalent:@""];
    _dual = [menu addItemWithTitle:@"Restore Extended Desktop" action:@selector(dualDesktop) keyEquivalent:@""];
    [menu addItem:NSMenuItem.separatorItem];
    _wifiOffOnLock = [menu addItemWithTitle:@"Disable Wi-Fi While Locked"
                                    action:@selector(toggleWiFiOffOnLock) keyEquivalent:@""];
    _wifiOffOnLock.target = self;
    [menu addItem:NSMenuItem.separatorItem];
    NSMenuItem *quit = [menu addItemWithTitle:@"Quit ScreenFollow" action:@selector(terminate:) keyEquivalent:@""];
    _single.target = self;
    _dual.target = self;
    quit.target = NSApp;
    _statusItem.menu = menu;

    [NSUserDefaults.standardUserDefaults registerDefaults:@{WiFiOffOnLockKey: @YES}];
    [NSDistributedNotificationCenter.defaultCenter addObserver:self
                                                      selector:@selector(screenDidLock:)
                                                          name:ScreenLockedNotification
                                                        object:nil
                                            suspensionBehavior:NSNotificationSuspensionBehaviorDeliverImmediately];
    [NSDistributedNotificationCenter.defaultCenter addObserver:self
                                                      selector:@selector(screenDidUnlock:)
                                                          name:ScreenUnlockedNotification
                                                        object:nil
                                            suspensionBehavior:NSNotificationSuspensionBehaviorDeliverImmediately];
}

- (void)toggleWiFiOffOnLock {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    [defaults setBool:![defaults boolForKey:WiFiOffOnLockKey] forKey:WiFiOffOnLockKey];
}

- (void)screenDidLock:(NSNotification *)notification {
    if (![NSUserDefaults.standardUserDefaults boolForKey:WiFiOffOnLockKey]) return;

    CWInterface *interface = CWWiFiClient.sharedWiFiClient.interface;
    NSString *name = interface.interfaceName;
    if (name.length && interface.powerOn && SetWiFiPower(interface, NO)) {
        _wifiInterfaceToRestore = [name copy];
    }
}

- (void)screenDidUnlock:(NSNotification *)notification {
    NSString *name = _wifiInterfaceToRestore;
    _wifiInterfaceToRestore = nil;
    if (!name) return;

    CWInterface *interface = [CWWiFiClient.sharedWiFiClient interfaceWithName:name];
    if (interface && !interface.powerOn) SetWiFiPower(interface, YES);
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    NSDistributedNotificationCenter *center = NSDistributedNotificationCenter.defaultCenter;
    [center removeObserver:self name:ScreenLockedNotification object:nil];
    [center removeObserver:self name:ScreenUnlockedNotification object:nil];
}

- (void)menuNeedsUpdate:(NSMenu *)menu {
    CGDirectDisplayID dell, main;
    BOOL available = FindDisplays(&dell, &main);
    BOOL mirrored = available && CGDisplayMirrorsDisplay(dell) == main;
    _single.enabled = available && !mirrored && CGDisplayIsActive(dell);
    _dual.enabled = mirrored;
    _wifiOffOnLock.state = [NSUserDefaults.standardUserDefaults boolForKey:WiFiOffOnLockKey]
        ? NSControlStateValueOn : NSControlStateValueOff;
}

- (void)singleDesktop { [self applyMirror:YES]; }
- (void)dualDesktop { [self applyMirror:NO]; }

- (void)applyMirror:(BOOL)mirror {
    CGDirectDisplayID dell, main;
    if (!FindDisplays(&dell, &main)) {
        [self showError:@"Connect the Dell U2421E and set your other display as the main display."];
        return;
    }

    BOOL mirrored = CGDisplayMirrorsDisplay(dell) == main;
    if (mirrored == mirror) return;

    CGDisplayConfigRef config;
    CGError error = CGBeginDisplayConfiguration(&config);
    if (error == kCGErrorSuccess) {
        error = CGConfigureDisplayMirrorOfDisplay(config, dell, mirror ? main : kCGNullDirectDisplay);
        if (error == kCGErrorSuccess) {
            error = CGCompleteDisplayConfiguration(config, kCGConfigureForAppOnly);
        } else {
            CGCancelDisplayConfiguration(config);
        }
    }

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 400 * NSEC_PER_MSEC),
                   dispatch_get_main_queue(), ^{
        CGDirectDisplayID currentDell, currentMain;
        if (FindDisplays(&currentDell, &currentMain) &&
            (CGDisplayMirrorsDisplay(currentDell) == currentMain) == mirror) return;
        NSString *message = error == kCGErrorSuccess ? @"macOS did not apply the requested display layout." :
            [NSString stringWithFormat:@"Could not change the display layout (error %d).", error];
        [self showError:message];
    });
}

- (void)showError:(NSString *)message {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"ScreenFollow";
    alert.informativeText = message;
    [NSApp activateIgnoringOtherApps:YES];
    [alert runModal];
}

@end

int main(void) {
    @autoreleasepool {
        NSApplication *app = NSApplication.sharedApplication;
        ScreenFollow *delegate = [[ScreenFollow alloc] init];
        app.delegate = delegate;
        [app run];
    }
    return 0;
}
