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

@implementation PluginPDFView

- (void)onScaleChanged:(NSNotification*)notification
{
  NSLog(@"scale changed");
  [Preferences setFloatPreference:"scaleFactor" value:[self scaleFactor]];
}

- (id)initWithPlugin:(PluginInstance*)plugin
{
  if (self = [super init]) {
    _plugin = plugin;
    [self setDelegate:self];
    [self setDisplayMode:[Preferences getIntPreference:"displayMode"]];
    if ([Preferences getBoolPreference:"autoScales"]) {
      [self setAutoScales:YES];
    } else {
      [self setScaleFactor:[Preferences getFloatPreference:"scaleFactor"]];
    }
    [[NSNotificationCenter defaultCenter] addObserver:self 
        selector:@selector(onScaleChanged:) name:PDFViewScaleChangedNotification object:self];
  }
  return self;
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
  switch ([theEvent keyCode])
  {
    case 24: // CMD+'='
      [self zoomIn:self];
      return YES;
    case 33: // CMD+SHIFT+'['
    case 30: // CMD+SHIFT+']'
      if ((flags & NSShiftKeyMask) && !(flags & NSAlternateKeyMask) && !(flags & NSControlKeyMask)) {
        [_plugin advanceTab:([theEvent keyCode] == 30 ? 1 : -1)];
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
      actOnKeyEquivalent(menu, sel, theEvent);
    } else {
      // TODO: is this ever called?
      [[NSApp mainMenu] performKeyEquivalent:theEvent];
    }
    return NO;
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
