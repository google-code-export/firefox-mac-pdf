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
#import "PluginInstance.h"
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


@implementation PluginPDFView

- (PDFView*)pdfView
{
  return pdfView;
}

- (void)dealloc
{
  [pdfView release];
  [super dealloc];
}

- (void)awakeFromNib
{
  [self initPDFViewWithFrame:[self frame]];
}

- (NSView *)hitTest:(NSPoint)point
{
  // We override hit test and invert the next responder loop so that
  // we can preview all mouse events. Our next responder is the view
  // that would have receieved the event. We make sure the pdfView has
  // a nil next responder to prevent an infinite loop.
  // This is a terrible HACK. There must be a better way...
  [self setNextResponder:[super hitTest:point]];
  [pdfView setNextResponder:nil];
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
  int code = [theEvent keyCode];
  switch (code)
  {
    case 24: // CMD+'='
      [pdfView zoomIn:nil];
      return YES;
    case 33: // CMD+(SHIFT)+'['
    case 30: // CMD+(SHIFT)+']'
      if (!(flags & NSAlternateKeyMask) && !(flags & NSControlKeyMask)) {
        if (flags & NSShiftKeyMask) {
          [plugin advanceTab:(code == 30 ? 1 : -1)];
        } else {
          if (code == 33) {
            if ([pdfView canGoBack]) {
              [pdfView goBack:nil];
            }
          } else {
            if ([pdfView canGoForward]) {
              [pdfView goForward:nil];
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
          [plugin advanceTab:offset];
        } else {
          [plugin advanceHistory:offset];
        }
        return YES;
      }
      break;
    case 48: // CTRL+TAB and CTRL+SHIFT+TAB
      if ((flags & NSControlKeyMask) && !(flags & NSCommandKeyMask) && !(flags & NSAlternateKeyMask)) {
        [plugin advanceTab:(flags & NSShiftKeyMask ? -1 : 1)];
        return YES;
      }
      break;
    case 13: // CMD+W
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
      return retValuePerformKeyEquivalent;
    } else {
      // TODO: is this ever called?
      return [[NSApp mainMenu] performKeyEquivalent:theEvent];
    }
  }
  return YES;
}

@end
