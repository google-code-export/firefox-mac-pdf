/*
 * Copyright (c) 2009 Samuel Gross.
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

#import "PluginProgressView.h"


@implementation PluginProgressView

// Modifed function from DemoView.m in PathDemo
static void addRoundedRectToPath(CGContextRef context, CGRect rect,
                                 float ovalWidth,float ovalHeight)
{
    float fw, fh;
 
    CGContextSaveGState(context);// 2
 
    CGContextTranslateCTM (context, CGRectGetMinX(rect),// 3
                         CGRectGetMinY(rect));
    CGContextScaleCTM (context, ovalWidth, ovalHeight);// 4
    fw = CGRectGetWidth (rect) / ovalWidth;// 5
    fh = CGRectGetHeight (rect) / ovalHeight;// 6
 
    CGContextMoveToPoint(context, fw, fh/2); // 7
    CGContextAddArcToPoint(context, fw, fh, fw/2, fh, 1);// 8
    CGContextAddArcToPoint(context, 0, fh, 0, fh/2, 1);// 9
    CGContextAddArcToPoint(context, 0, 0, fw/2, 0, 1);// 10
    CGContextAddArcToPoint(context, fw, 0, fw, fh/2, 1); // 11
    CGContextFillPath(context); // 12
 
    CGContextRestoreGState(context);// 13
}

static NSString* stringFromByteSize(int size)
{
  double value = size / 1024;
  if (value < 1023)
    return [NSString localizedStringWithFormat:@"%1.1f KB", value];
  value = value / 1024;
  if (value < 1023)
    return [NSString localizedStringWithFormat:@"%1.1f MB", value];
  value = value / 1024;
  return [NSString localizedStringWithFormat:@"%1.1f GB", value];

}

- (void)setProgress:(int)progress total:(int)total
{
  NSBundle* bundle = [NSBundle bundleForClass:[self class]];
  NSString* progressString = NSLocalizedStringFromTableInBundle(
      @"Loading", nil, bundle, @"Loading PDF");

  if (total == 0) {
    [progressBar setIndeterminate:true];
    return;
  }
  [progressBar setMaxValue:total];
  [progressBar setDoubleValue:progress];
  
  [progressText setStringValue:
    [NSString localizedStringWithFormat:
      progressString,
      stringFromByteSize(progress),
      stringFromByteSize(total)]];
}

- (void)downloadFailed
{
  [progressBar setHidden:YES];

  NSBundle* bundle = [NSBundle bundleForClass:[self class]];
  [progressText setStringValue:
    NSLocalizedStringFromTableInBundle(
        @"Failed", nil, bundle, @"Download failed")];
  [progressText setFrameOrigin:NSMakePoint(51, 23)];
  [filenameText setFrameOrigin:NSMakePoint(51, 43)];
}

- (void)setFrame:(NSRect)frame
{
  NSView* superview = [self superview];
  if (superview) {
    frame.origin.x = MAX(0, ([superview frame].size.width - frame.size.width) / 2);
    frame.origin.y = MAX(0, ([superview frame].size.height - frame.size.height) / 2);
  }
  [super setFrame:frame];
}

- (void)drawRect:(NSRect)dirty
{
  NSRect rect = [self bounds];
  CGRect r = CGRectMake(rect.origin.x, rect.origin.y, rect.size.width, rect.size.height);
  CGContextRef context = (CGContextRef) [[NSGraphicsContext currentContext] graphicsPort];
  
  CGContextSetGrayFillColor(context, 1.0, 1.0);
  addRoundedRectToPath(context, r, 10.0, 10.0);
}

@end
