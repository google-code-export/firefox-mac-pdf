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
#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>
#include "mozincludes.h";

class nsIDOMWindow;
class PDFService;
class PDFPluginShim;

@class SelectionController;
 
typedef struct _SavedState {
  BOOL autoScales;
  float zoom;
  PDFDisplayMode displayMode;
} SavedState;

@interface PluginInstance : NSObject {
  NPP _npp;
  BOOL _attached;
  PDFView* _pdfView;
  SelectionController* selectionController;
  NSMutableArray* _searchResults;
  nsIDOMWindow* _window;
  NSString* _url;
  BOOL written;
  NSString *path;
  PDFPluginShim* _shim;
  PDFService* _pdfService;
}
- (void)copy;
- (BOOL)zoom:(int)zoomArg;
- (BOOL)attached;
- (void)advanceTab:(int)offset;
- (void)advanceHistory:(int)offset;
- (void)attachToWindow:(NSWindow*)window at:(NSPoint)point;
- (void)dealloc;
- (id)initWithService:(PDFService*)pdfService window:(nsIDOMWindow*)window npp:(NPP)npp;
- (void)print;
- (void)save;
- (void)setFile:(const char*)filename url:(const char*)url;
- (void)setFrameSize:(NSSize)size;
- (int)find:(NSString*)string caseSensitive:(bool)caseSensitive forwards:(bool)forwards;
- (void)findAll:(NSString*)string caseSensitive:(bool)caseSensitive;
- (void)removeHighlights;
- (void)loadURL:(NSString*)url;
- (PDFView*)pdfView;
@end

@interface PluginInstance (OpenWithFinder)
- (void)openWithFinder;
@end
