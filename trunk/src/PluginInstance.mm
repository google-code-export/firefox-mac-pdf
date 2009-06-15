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
#import "PluginInstance.h"
#import "PluginPDFView.h"
#import "SelectionController.h"
#import "PDFPluginShim.h"

#include "PDFService.h"
#include "nsStringAPI.h"

@implementation PluginInstance

- (BOOL)attached
{
  return _attached;
}

- (void)attachToWindow:(NSWindow*)window at:(NSPoint)point
{
  //debugView([window contentView], 0);
  // find the NSView at the point
  NSView* view = [[window contentView] hitTest:NSMakePoint(point.x+1, point.y+1)];
  if (view == nil || ![[view className] isEqualToString:@"ChildView"]) {
    return;
  }

  [view addSubview:pdfView];
  [pdfView setFrame:[view frame]];

  if (progressView) {
    [view addSubview:progressView positioned:NSWindowAbove relativeTo:pdfView];
    // set the next responder to nil to prevent infinite loop
    // due to weirdness in event handling in nsChildView.mm
    [progressView setNextResponder:nil];

    int x = ([view frame].size.width - [progressView frame].size.width) / 2;
    int y = ([view frame].size.height - [progressView frame].size.height) / 2;
    [progressView setFrameOrigin:NSMakePoint(x, y)];
  }

  _attached = true;
}

- (void)dealloc
{
  if (pdfView) {
    [pdfView removeFromSuperview];
    [pdfView release];
  }
  if (progressView) {
    [progressView removeFromSuperview];
    [progressView release];
  }

  [selectionController release];
  [_searchResults release];
  [path release];
  _pdfService->CleanUp(_shim);
  _shim->Release();
  _pdfService->Release();
  [_url release];
  [_mimeType release];
  [_data release];
  [super dealloc];
}

- (id)initWithService:(PDFService*)pdfService window:(nsIDOMWindow*)window npp:(NPP)npp mimeType:(NSString*)mimeType;
{
  if (self = [super init]) {
    _npp = npp;
    _mimeType = [mimeType retain];

    // load nib file
    [NSBundle loadNibNamed:@"PluginView" owner:self];
    
    selectionController = [[SelectionController forPDFView:pdfView] retain];
    _pdfService = pdfService;
    _pdfService->AddRef();
    _window = window;
    _shim = new PDFPluginShim(self);
    _shim->AddRef();
    _pdfService->Init(_window, _shim);
    
    NSBundle* bundle = [NSBundle bundleForClass:[self class]];
    progressString = NSLocalizedStringFromTableInBundle(
        @"Loading %@ of %@", nil, bundle, @"Loading");
  }
  return self;
}

- (void)print 
{
  [pdfView printWithInfo:[NSPrintInfo sharedPrintInfo] autoRotate:YES];
}

- (void)save
{
  nsCAutoString urlString([_url UTF8String]);
  _pdfService->Save(_window, urlString);
}

static NSString* stringFromByteSize(int size)
{
  double value = size;
  if (value < 1023)
    return [NSString stringWithFormat:@"%i bytes", size];
  value = value / 1024;
  if (value < 1023)
    return [NSString stringWithFormat:@"%1.1f KB", value];
  value = value / 1024;
  if (value < 1023)
    return [NSString stringWithFormat:@"%1.1f MB", value];
  value = value / 1024;
  return [NSString stringWithFormat:@"%1.1f GB", value];

}

- (void)setProgress:(int)progress total:(int)total
{
  if (total == 0) {
    [progressBar setIndeterminate:true];
    return;
  }
  [progressBar setMaxValue:total];
  [progressBar setDoubleValue:progress];
  
  [progressText setStringValue:[NSString stringWithFormat:
      progressString,
      stringFromByteSize(progress),
      stringFromByteSize(total)]];
}

- (void)setData:(NSData*)data
{
  if (progressView) {
    NSLog(@"superview: %@", [progressView superview]);
    [progressView removeFromSuperview];
    [progressView release];
    progressView = nil;
  }

  // create PDF document
  _data = [data retain];
  NSLog(@"setting data: %d ...", [_data length]);
  
  NSData* pdfData;
  if ([_mimeType isEqualToString:@"application/postscript"]) {
    pdfData = [self convertPostScriptDataSourceToPDF:_data];
  } else {
    pdfData = _data;
  }

  PDFDocument* document = [[[PDFDocument alloc] initWithData:pdfData] autorelease];
  [document setDelegate:self];
  [pdfView setDocument:document];
}

static bool selectionsAreEqual(PDFSelection* sel1, PDFSelection* sel2)
{
  NSArray* pages1 = [sel1 pages];
  NSArray* pages2 = [sel2 pages];
  if (![pages1 isEqual:pages2]) {
    return false;
  }
  for (int i = 0; i < [pages1 count]; i++) {
    if (!NSEqualRects([sel1 boundsForPage:[pages1 objectAtIndex:i]],
                      [sel2 boundsForPage:[pages2 objectAtIndex:i]])) {
      return false;
    }
  }
  return true;
}

- (int)find:(NSString*)string caseSensitive:(bool)caseSensitive forwards:(bool)forwards
{
  const int FOUND = 0;
  const int NOT_FOUND = 1;
  const int WRAPPED = 2;
  int ret;

  PDFDocument* doc = [pdfView document];
  if (!doc) {
    return FOUND;
  }

  // only one search can take place at a time
  if ([doc isFinding]) {
    [doc cancelFindString];
  }

  if ([string length] == 0) {
    [selectionController setCurrentSelection:nil];
    return FOUND;
  }

  // see WebPDFView.mm in WebKit for general technique
  PDFSelection* initialSelection = [[pdfView currentSelection] copy];
  PDFSelection* searchSelection = [initialSelection copy];
  
  // collapse selection to before start/end
  int length = [[searchSelection string] length];
  if (forwards) {
    [searchSelection extendSelectionAtStart:1];
    [searchSelection extendSelectionAtEnd:-length];
  } else {
    [searchSelection extendSelectionAtStart:-length];
    [searchSelection extendSelectionAtEnd:1];
  }
    
  int options = 0;
  options |= (caseSensitive ? 0 : NSCaseInsensitiveSearch);
  options |= (forwards ? 0 : NSBackwardsSearch);

  // search!
  PDFSelection* result = [doc findString:string fromSelection:searchSelection withOptions:options];
  [searchSelection release];
  
  // advance search if we get the same selection
  if (result && initialSelection && selectionsAreEqual(result, initialSelection)) {
    result = [doc findString:string fromSelection:initialSelection withOptions:options];
  }
  [initialSelection release];
  
  // wrap search
  if (!result) {
    result = [doc findString:string fromSelection:result withOptions:options];
    ret = result ? WRAPPED : NOT_FOUND;
  } else {
    ret = FOUND;
  }

  // scroll to the selection
  [selectionController setCurrentSelection:result];
  return ret;
}

- (void)advanceTab:(int)offset
{
  _pdfService->AdvanceTab(_window, offset);
}

- (void)advanceHistory:(int)offset
{
  _pdfService->GoHistory(_window, offset);
}

- (void)findAll:(NSString*)string caseSensitive:(bool)caseSensitive
{
  PDFDocument* doc = [pdfView document];
  if ([doc isFinding]) {
    [doc cancelFindString];
  }
  if ([string length] == 0) {
    [selectionController setHighlightedSelections:nil];
    return;
  }
  if (_searchResults == NULL) {
    _searchResults = [[NSMutableArray arrayWithCapacity: 10] retain];
  }
  int options = (caseSensitive ? 0 : NSCaseInsensitiveSearch);
  [doc beginFindString:string withOptions:options];
}

- (void)removeHighlights
{
  [selectionController setHighlightedSelections:nil];
}

- (void)documentDidBeginDocumentFind:(NSNotification *)notification
{
  [_searchResults removeAllObjects];
}

- (void)documentDidEndDocumentFind:(NSNotification *)notification
{
  [selectionController setHighlightedSelections:_searchResults];
}

- (void)didMatchString:(PDFSelection*)instance
{
  [_searchResults addObject: [instance copy]];
}

- (void)copy
{
  [pdfView copy:nil];
}

- (void)loadURL:(NSString*)url
{
  NPN_GetURL(_npp, [url UTF8String], "_self");
}

- (BOOL)zoom:(int)zoomArg
{
  switch (zoomArg) {
    case -1:
      [pdfView zoomOut:nil];
      break;
    case 0:
      [pdfView setScaleFactor:1.0];
      break;
    case 1:
      [pdfView zoomIn:nil];
      break;
    default:
      return NO;
  }
  return YES;
}

+ (NSSet*)keyPathsForValuesAffectingFilename
{
  return [NSSet setWithObject:@"url"];
}

- (NSString*)filename
{
  if (!_url)
    return nil;
  return [[[NSURL URLWithString:_url] path] lastPathComponent];
}

- (void)setUrl:(NSString*)url
{
  [_url autorelease];
  _url = [url retain];
}

- (NSImage*)pdfIcon
{
  NSImage* icon = [[NSWorkspace sharedWorkspace] iconForFileType:@"pdf"];
  NSLog(@"scales: %d", [icon scalesWhenResized]);
  return icon;
}

@end
