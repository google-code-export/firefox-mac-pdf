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

- (void)keyDown:(NSEvent*)theEvent
{
  NSLog(@"keyDown: %d", [theEvent keyCode]);
  /*
   Here we have to redefine all key bindings, users expect to work in a PDFView.
   Probably still incomplete.
   */
  switch ([theEvent keyCode]) {
    case 0x31: // Space
    case 0x7C: // Right
      [pdfView scrollPageDown:nil];
      break;
    //case 0x33: // Backspace (most people will use this for "Go Back")
    case 0x7B: // Left
      [pdfView scrollPageUp:nil];
      break;
    case 0x7D: // Down
      [pdfView scrollLineDown:nil];
      break;
    case 0x7E: // Up
      [pdfView scrollLineUp:nil];
      break;
    default:
      [[[self superview] superview] keyDown:theEvent];
  }
}

- (BOOL)performKeyEquivalent:(NSEvent*)theEvent
{
  NSLog(@"PluginPDFView performKeyEquivalent");
  switch ([theEvent keyCode])
  {
    case 24: // CMD+'='
      [pdfView zoomIn:nil];
      return YES;
    case 27: // CMD+'-'
      [pdfView zoomOut:nil];
      return YES;
  }
  return NO;
  
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

@end
