/*
 * Copyright (c) 2008 Samuel Gross.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *f
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */
#import "PluginPDFView.h"
#import "Preferences.h"
#import "Swizzle.h"

static BOOL retValuePerformKeyEquivalent;
static BOOL swizzled = NO;

@interface NSMenu (PDFAltMethod)
- (BOOL)altPerformKeyEquivalent:(NSEvent*)theEvent;
@end

@implementation NSMenu (PDFAltMethod)
- (BOOL)altPerformKeyEquivalent:(NSEvent*)theEvent
{
  retValuePerformKeyEquivalent = [self altPerformKeyEquivalent:theEvent];
  return retValuePerformKeyEquivalent;
}
@end


@interface PluginPDFView (FileInternal)
- (void)_applyDefaults;
@end


@implementation PluginPDFView

// TODO: this is only for 10.5 checkout 10.4 behavior
- (void)PDFViewWillClickOnLink:(PDFView *)sender withURL:(NSURL *)URL
{
//  NSLog(@"PDFViewWillClickOnLink sender:%@ withURL:%@ rel=%@", sender, URL, [URL relativeString]);
  [_plugin loadURL:[URL absoluteString]];
}

- (void)onScaleChanged:(NSNotification*)notification
{
  NSLog(@"scale changed");
  [Preferences setFloatPreference:"scaleFactor" value:[self scaleFactor]];
}

//- (void)onAnnotationHit:(NSNotification*)notification
//{
//  NSLog(@"onAnnotationHit: %@", notification);
//  PDFAnnotation* annotation = [[notification userInfo]
//      objectForKey:@"PDFAnnotationHit"];
//  NSLog(@" annotation: %@", annotation);
//  if ([[annotation type] isEqualToString:@"Link"]) {
//    PDFAnnotationLink* link = (PDFAnnotationLink*) annotation;
//    NSLog(@" link");
//    NSLog(@" destination: %@ url: %@", [link destination], [link URL]);
//  }
//}

- (id)initWithPlugin:(PluginInstance*)plugin
{
  if (self = [super init]) {
    _plugin = plugin;
    [self setDelegate:self];
    [[NSNotificationCenter defaultCenter] addObserver:self 
        selector:@selector(onScaleChanged:) name:PDFViewScaleChangedNotification object:self];
//    [[NSNotificationCenter defaultCenter] addObserver:self
//        selector:@selector(onAnnotationHit:) name:PDFViewAnnotationHitNotification object:self];
  }
  return self;
}

- (void)_applyDefaults
{
  if ([Preferences getBoolPreference:"autoScales"]) {
    [self setAutoScales:YES];
  } else {
    float scaleFactor = [Preferences getFloatPreference:"scaleFactor"];
    [self setAutoScales:NO];
    [self setScaleFactor:scaleFactor];
  }
  [self setDisplayMode:[Preferences getIntPreference:"displayMode"]];
}

- (void)setDocument:(PDFDocument *)doc
{
  [super setDocument:doc];
  [self _applyDefaults];
}

- (void)mouseDown:(NSEvent*)theEvent
{ 
  NSResponder* firstResponder = [[[self window] firstResponder] retain];
  // pass mouse down event to parent view (to claim browser focus from other XUL elements)
  [[self superview] mouseDown:theEvent];
  // reclaim focus
  [[self window] makeFirstResponder:firstResponder];
  // process event
  [super mouseDown:theEvent];
  [firstResponder release];
  
  // used by SelectionController
  [[NSNotificationCenter defaultCenter] postNotificationName:@"mouseDown" object:self];  
}

- (BOOL)handleOverideKeyEquivalent:(NSEvent*)theEvent
{
  int flags = [theEvent modifierFlags];
  int code = [theEvent keyCode];
  switch (code)
  {
    case 24: // CMD+'='
      [self zoomIn:self];
      return YES;
    case 33: // CMD+(SHIFT)+'['
    case 30: // CMD+(SHIFT)+']'
      if (!(flags & NSAlternateKeyMask) && !(flags & NSControlKeyMask)) {
        if (flags & NSShiftKeyMask) {
          [_plugin advanceTab:(code == 30 ? 1 : -1)];
        } else {
          if (code == 33) {
            if ([self canGoBack]) {
              [self goBack:nil];
            }
          } else {
            if ([self canGoForward]) {
              [self goForward:nil];
            }
          }
        }
        return YES;
      }
      break;
    case 123: // CMD+ALT+<LEFT>
    case 124: // CMD+ALT+<RIGHT>
      if (!(flags & NSShiftKeyMask) && !(flags & NSControlKeyMask) && (flags & NSCommandKeyMask)) {
        int offset = ([theEvent keyCode] == 124 ? 1 : -1);
        if ((flags & NSAlternateKeyMask)) {
          [_plugin advanceTab:offset];
        } else {
          [_plugin advanceHistory:offset];
        }
        return YES;
      }
      break;
    case 13:
      if ((flags & NSCommandKeyMask) && !(flags & NSAlternateKeyMask) && !(flags & NSControlKeyMask)
          /*&& !(flags & NSShiftKeyMask)*/) {
        [[self window] makeFirstResponder:[self superview]];
        [[self superview] performKeyEquivalent:theEvent];
        return YES;
      }
      break;
  }
  return NO;
}

- (BOOL)performKeyEquivalent:(NSEvent*)theEvent
{
  if (![super performKeyEquivalent:theEvent]) {
    // 'custom' key shortcuts
    if ([self handleOverideKeyEquivalent:theEvent]) {
      return YES;
    }
    // run the menu accelerators (shortcuts)
    NSMenu* menu = [NSApp mainMenu];
    // see nsChildView.mm:performKeyEquivalent 
    SEL sel = @selector(actOnKeyEquivalent:);
    if ([[menu class] instancesRespondToSelector:sel]) {
      void (*actOnKeyEquivalent)(id, SEL, NSEvent*);
      actOnKeyEquivalent = (void (*)(id, SEL, NSEvent*))[[menu class] instanceMethodForSelector:sel];
      if (!swizzled) {
        MethodSwizzle([menu class],
                    @selector(performKeyEquivalent:),
                    @selector(altPerformKeyEquivalent:));
        swizzled = YES;
      }
      actOnKeyEquivalent(menu, sel, theEvent);
//      MethodSwizzle([menu class],
//                  @selector(performKeyEquivalent:),
//                  @selector(altPerformKeyEquivalent:));
//      NSLog(@"retValuePerformKeyEquivalent = %d", (int) retValuePerformKeyEquivalent);
      return retValuePerformKeyEquivalent;
    } else {
      // TODO: is this ever called?
      return [[NSApp mainMenu] performKeyEquivalent:theEvent];
    }
  }
  return YES;
}

- (void)setAutoScales:(BOOL)newAuto
{
  [super setAutoScales:newAuto];
  [Preferences setBoolPreference:"autoScales" value:newAuto];
}

- (void)setDisplayMode:(PDFDisplayMode)mode
{
  [super setDisplayMode:mode];
  [Preferences setIntPreference:"displayMode" value:mode];
}

@end
