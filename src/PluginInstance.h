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
#include "npapi.h";

class nsIDOMWindow;
class PDFService;
class PDFPluginShim;

@class SelectionController;

@interface PluginInstance : NSObject {
  IBOutlet PDFView* pdfView;
  IBOutlet NSView* progressView;
  IBOutlet NSProgressIndicator* progressBar;
  IBOutlet NSTextField* progressText;
  IBOutlet NSTextField* filenameText;
  NSString* progressString;
  NPP _npp;
  BOOL _attached;
  SelectionController* selectionController;
  NSMutableArray* _searchResults;
  nsIDOMWindow* _window;
  NSString* _url;
  NSString* _mimeType;
  NSData* _data;
  BOOL written;
  NSString *path;
  PDFPluginShim* _shim;
  PDFService* _pdfService;
}
- (BOOL)attached;
- (void)advanceTab:(int)offset;
- (void)advanceHistory:(int)offset;
- (void)attachToWindow:(NSWindow*)window at:(NSPoint)point;
- (void)dealloc;
- (id)initWithService:(PDFService*)pdfService window:(nsIDOMWindow*)window npp:(NPP)npp mimeType:(NSString*)mimeType;
- (void)setProgress:(int)progress total:(int)total;
- (void)save;
- (void)downloadFailed;
- (void)setData:(NSData*)data;
- (void)loadURL:(NSString*)url;
- (void)print;
// model
- (NSString*)filename;
- (void)setUrl:(NSString*)url;
// plugin shim methods
- (void)copy;
- (int)find:(NSString*)string caseSensitive:(bool)caseSensitive forwards:(bool)forwards;
- (void)findAll:(NSString*)string caseSensitive:(bool)caseSensitive;
- (void)removeHighlights;
- (BOOL)zoom:(int)zoomArg;
@end

@interface PluginInstance (OpenWithFinder)
- (void)openWithFinder;
- (NSData *)convertPostScriptDataSourceToPDF:(NSData *)data;
@end
