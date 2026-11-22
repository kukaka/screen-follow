#import <AppKit/AppKit.h>
#import <CoreGraphics/CoreGraphics.h>

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

@interface ScreenFollow : NSObject <NSApplicationDelegate, NSMenuDelegate>
@end

@implementation ScreenFollow {
    NSStatusItem *_statusItem;
    NSMenuItem *_single;
    NSMenuItem *_dual;
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
    NSMenuItem *quit = [menu addItemWithTitle:@"Quit ScreenFollow" action:@selector(terminate:) keyEquivalent:@""];
    _single.target = self;
    _dual.target = self;
    quit.target = NSApp;
    _statusItem.menu = menu;
}

- (void)menuNeedsUpdate:(NSMenu *)menu {
    CGDirectDisplayID dell, main;
    BOOL available = FindDisplays(&dell, &main);
    BOOL mirrored = available && CGDisplayMirrorsDisplay(dell) == main;
    _single.enabled = available && !mirrored && CGDisplayIsActive(dell);
    _dual.enabled = mirrored;
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
