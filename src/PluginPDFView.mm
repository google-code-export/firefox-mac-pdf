/*
 * Copyright (c) 2008 Samuel Gross.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
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

static BOOL retValuePerformKeyEquivalent;

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


- (BOOL)handleCommonKeyEvents:(NSEvent*)theEvent
{
  /*
   Here we have to redefine all key bindings, users expect to work in a PDFView.
   Probably still incomplete.
   */
  switch ([theEvent keyCode]) {
    case 0x31: // Space
    case 0x7C: // Right
      [pdfView scrollPageDown:nil];
      return YES;
    //case 0x33: // Backspace (most people will use this for "Go Back")
    case 0x7B: // Left
      [pdfView scrollPageUp:nil];
      return YES;
    case 0x7D: // Down
      [pdfView scrollLineDown:nil];
      return YES;
    case 0x7E: // Up
      [pdfView scrollLineUp:nil];
      return YES;
  }
  return NO;
}

- (void)keyDown:(NSEvent*)theEvent
{
//  NSLog(@"keyDown: %d", [theEvent keyCode]);
  if (![self handleCommonKeyEvents:theEvent]) {
    [[[self superview] superview] keyDown:theEvent];
  }
}

- (BOOL)performKeyEquivalent:(NSEvent*)theEvent
{
//  NSLog(@"PluginPDFView performKeyEquivalent: %d", [theEvent keyCode]);
  switch ([theEvent keyCode])
  {
    case 24: // CMD+'='
      [pdfView zoomIn:nil];
      return YES;
    case 27: // CMD+'-'
      [pdfView zoomOut:nil];
      return YES;
    case 8: // CMD+'c'
      [pdfView copy:nil];
      return YES;
  }
  return [self handleCommonKeyEvents:theEvent];
}

@end
