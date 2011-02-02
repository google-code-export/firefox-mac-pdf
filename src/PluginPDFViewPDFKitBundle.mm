/*
 * Copyright (C) 2005, 2006, 2007, 2008 Apple Inc. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * 1.  Redistributions of source code must retain the above copyright
 *     notice, this list of conditions and the following disclaimer. 
 * 2.  Redistributions in binary form must reproduce the above copyright
 *     notice, this list of conditions and the following disclaimer in the
 *     documentation and/or other materials provided with the distribution. 
 * 3.  Neither the name of Apple Computer, Inc. ("Apple") nor the names of
 *     its contributors may be used to endorse or promote products derived
 *     from this software without specific prior written permission. 
 *
 * THIS SOFTWARE IS PROVIDED BY APPLE AND ITS CONTRIBUTORS "AS IS" AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL APPLE OR ITS CONTRIBUTORS BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

/*
 * Modified by Sam Gross <colesbury@gmail.com> for use with Firefox PDF Plugin for Mac OS X.
 */
#import "PluginPDFView.h"

extern "C" NSString *_NSPathForSystemFramework(NSString *framework);

/*
 This is a category for PDFView to prevent it from handling keystrokes by itself.
 That means no scrolling etc., if we want that we'll have to implement it by hand.
 But it's necessary to have Firefox keybindings (and those implemented by other extensions)
 handled correctly.
 */
@interface PDFView (NoFocus)
- (void)keyDown:(NSEvent*)theEvent;
- (BOOL)performKeyEquivalent:(NSEvent*)theEvent;
@end

@implementation PDFView (NoFocus)

/*
 We forward all keyDown and performKeyEquivalent events down to the PluginPDFView.
 That superview-chain will be quite fragile when the view layout changes, it
 should be closely monitored.
 */
- (void)keyDown:(NSEvent*)theEvent
{
  [[[[self superview] superview] superview] keyDown:theEvent];
}
- (BOOL)performKeyEquivalent:(NSEvent*)theEvent
{
  return [[[[self superview] superview] superview] performKeyEquivalent:theEvent];
}

@end


@interface PluginPDFView (FileInternal)
+ (Class)_PDFPreviewViewClass;
+ (Class)_PDFViewClass;
@end

@implementation PluginPDFView (PDFKitBundle)

+ (NSBundle *)PDFKitBundle
{
    static NSBundle *PDFKitBundle = nil;
    if (PDFKitBundle == nil) {
        NSString *PDFKitPath = [_NSPathForSystemFramework(@"Quartz.framework") stringByAppendingString:@"/Frameworks/PDFKit.framework"];
        if (PDFKitPath == nil) {
            NSLog(@"Couldn't find PDFKit.framework");
            return nil;
        }
        PDFKitBundle = [NSBundle bundleWithPath:PDFKitPath];
        if (![PDFKitBundle load]) {
            NSLog(@"Couldn't load PDFKit.framework");
        }
    }
    return PDFKitBundle;
}

+ (Class)_PDFPreviewViewClass
{
    static Class PDFPreviewViewClass = nil;
    static BOOL checkedForPDFPreviewViewClass = NO;
    
    if (!checkedForPDFPreviewViewClass) {
        checkedForPDFPreviewViewClass = YES;
        PDFPreviewViewClass = [[PluginPDFView PDFKitBundle] classNamed:@"PDFPreviewView"];
    }
    
    // This class might not be available; callers need to deal with a nil return here.
    return PDFPreviewViewClass;
}

+ (Class)_PDFViewClass
{
    static Class PDFViewClass = nil;
    if (PDFViewClass == nil) {
        PDFViewClass = [[PluginPDFView PDFKitBundle] classNamed:@"PDFView"];
        if (!PDFViewClass)
            NSLog(@"Couldn't find PDFView class in PDFKit.framework");
    }
    return PDFViewClass;
}

// see initWithFrame:(NSRect)frame in WebPDFView.mm
- (void)initPDFViewWithFrame:(NSRect)frame
{
   Class previewViewClass = [[self class] _PDFPreviewViewClass];

   NSView *previewView = nil;
   if (previewViewClass) {
      previewView = [[previewViewClass alloc] initWithFrame:frame];
   }

   NSView *topLevelPDFKitView = nil;
   if (previewView) {
      // We'll retain the PDFSubview here so that it is equally retained in all
      // code paths. That way we don't need to worry about conditionally releasing
      // it later.
      pdfView = [[previewView performSelector:@selector(pdfView)] retain];
      topLevelPDFKitView = previewView;
   } else {
      pdfView = [[[[self class] _PDFViewClass] alloc] initWithFrame:frame];
      topLevelPDFKitView = pdfView;
   }

   [topLevelPDFKitView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
   [self addSubview:topLevelPDFKitView];

   [pdfView setDelegate:plugin];
   
   [previewView release];
}

@end
