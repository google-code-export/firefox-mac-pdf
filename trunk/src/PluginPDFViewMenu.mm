/*
 * Copyright (C) 2005, 2006, 2007 Apple Inc. All rights reserved.
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
#import "PluginInstance.h"

// This is the implementation of the menu.
// This includes source code from the WebPDFView.mm in the WebKit project

static void _applicationInfoForMIMEType(NSString *type, NSString **name, NSImage **image)
{
    NSURL *appURL = nil;
    
    OSStatus error = LSCopyApplicationForMIMEType((CFStringRef)type, kLSRolesAll, (CFURLRef *)&appURL);
    if (error != noErr)
        return;
    
    NSString *appPath = [appURL path];
    CFRelease (appURL);
    
    *image = [[NSWorkspace sharedWorkspace] iconForFile:appPath];  
    [*image setSize:NSMakeSize(16.f,16.f)];  
    
    NSString *appName = [[NSFileManager defaultManager] displayNameAtPath:appPath];
    *name = appName;
}


@implementation PluginPDFView (PluginPDFViewMenu)

- (BOOL)acceptsFirstResponder {
    return YES;
}

- (BOOL)becomeFirstResponder
{
    NSLog(@"becomeFirstResponder direction: %d", [[self window] keyViewSelectionDirection]);
    // This works together with setNextKeyView to splice our PDFSubview into
    // the key loop similar to the way NSScrollView does this.
    NSWindow *window = [self window];
    id newFirstResponder = nil;

    if ([window keyViewSelectionDirection] == NSSelectingPrevious) {
        NSView *previousValidKeyView = [self previousValidKeyView];
        if ((previousValidKeyView != self) && (previousValidKeyView != pdfView))
            newFirstResponder = previousValidKeyView;
    } else {
        NSView *PDFDocumentView = [pdfView documentView];
        if ([PDFDocumentView acceptsFirstResponder])
            newFirstResponder = PDFDocumentView;
    }

    if (!newFirstResponder)
        return NO;

    if (![window makeFirstResponder:newFirstResponder])
        return NO;

    //[[dataSource webFrame] _clearSelectionInOtherFrames];

    return YES;
}


- (NSMenuItem*) menuItemOpenWithFinder
{
  NSString *appName = nil;
  NSImage *appIcon = nil;
  
  _applicationInfoForMIMEType(@"application/pdf", &appName, &appIcon);
  if (!appName)
      appName = @"Finder";

  NSBundle* bundle = [NSBundle bundleForClass:[self class]];
  NSString* openStr = NSLocalizedStringFromTableInBundle(@"Open with %@", nil, bundle, @"Open PDF with application");

  // To match the PDFKit style, we'll add Open with Preview even when there's no document yet to view, and
  // disable it using validateUserInterfaceItem.
  NSString *title = [NSString stringWithFormat:openStr, appName];
  NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title action:@selector(openWithFinder:) keyEquivalent:@""];
  if (appIcon) {
    [item setImage:appIcon];
  }
  return [item autorelease];
}

- (int) menuInsertIndex:(NSMenu*)menu
{
  NSSet* priorActions = [[NSSet alloc] initWithObjects:
                         NSStringFromSelector(@selector(_searchInSpotlight:)),
                         NSStringFromSelector(@selector(_searchInGoogle:)),
                         NSStringFromSelector(@selector(_searchInDictionary:)),
                         NSStringFromSelector(@selector(copy:)),
                         nil];
  int length = [[menu itemArray] count];
  for (int i = 0; i < length; i++) {
    NSString* action = NSStringFromSelector([[menu itemAtIndex:i] action]);
    if (action != nil && ![priorActions containsObject:action]) {
      return i;
    }
  }
  return -1;
}

- (NSMenu *)menuForEvent:(NSEvent*)theEvent
{
  NSMenu* menu = [pdfView menuForEvent:theEvent];
  int insertIndex = [self menuInsertIndex:menu];
  
  NSBundle* bundle = [NSBundle bundleForClass:[self class]];
  NSString* printStr = NSLocalizedStringFromTableInBundle(@"Print File...", nil, bundle, @"Print PDF file");
  NSString* saveStr = NSLocalizedStringFromTableInBundle(@"Save File As...", nil, bundle, @"Save PDF file");                                       
  
  // Add the Open with Preview/Finder item
  [menu insertItem:[NSMenuItem separatorItem] atIndex:insertIndex];
  [menu insertItem:[self menuItemOpenWithFinder] atIndex:insertIndex];

  [menu insertItem:[NSMenuItem separatorItem] atIndex:insertIndex];
  [menu insertItemWithTitle:printStr action:@selector(doPrint:) keyEquivalent:@"" atIndex:insertIndex];
  [menu insertItemWithTitle:saveStr action:@selector(saveAs:) keyEquivalent:@"" atIndex:insertIndex];
  
  // Swizzle the search in google
  NSEnumerator *e = [[menu itemArray] objectEnumerator];
  NSMenuItem *item;
  for (int i = 0; (item = [e nextObject]) != nil; i++) {
    NSString *actionString = NSStringFromSelector([item action]);
    if ([actionString isEqualToString:NSStringFromSelector(@selector(_searchInGoogle:))]) {
      [item setAction:@selector(googleInFirefox:)];
      break;
    }
  }

  return menu;
}

// Code courtesy of Chris Wegg
// TODO: possibly implement with gecko API
- (void)googleInFirefox:(id)sender {
	//Get selection, URL encode it, add it to the google search string, and ask the OS to open that URL. 
	//Should open a new firefox tab provided its the default browser. 
	PDFSelection *selection = [pdfView currentSelection];
	NSString *escapedselection=(NSString*)CFURLCreateStringByAddingPercentEscapes(NULL,
		(CFStringRef) [selection string], NULL, NULL, kCFStringEncodingUTF8);
	NSString *searchurl=[NSString stringWithFormat:@"http://www.google.com/search?q=%@",escapedselection];
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:searchurl]];
}

- (void)doPrint:(id)sender
{
  [plugin print];
}

- (void)saveAs:(id)sender
{
  [plugin save];
}

- (void)openWithFinder:(id)sender
{
  [plugin openWithFinder];
}

@end
