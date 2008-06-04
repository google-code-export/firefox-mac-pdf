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
#import "SelectionController.h"
#include "mozincludes.h";

@interface PluginInstance : NSObject {
  NPIdentifier IDENT_FIND;
  NPIdentifier IDENT_FINDALL;
  NPIdentifier IDENT_ZOOM;
  NPIdentifier IDENT_REMOVEHIGHLIGHTS;
  NPIdentifier IDENT_SETTABCALLBACK;
  NPIdentifier IDENT_SETHISTORYCALLBACK;
  BOOL _attached;
  PDFView* _pdfView;
  NPP _npp;
  SelectionController* selectionController;
  NSMutableArray* _searchResults;
  NPObject* _scriptableObject;
  NPObject* _tabCallback;
  NPObject* _historyCallback;
}
- (BOOL)attached;
- (void)advanceTab:(int)offset;
- (void)advanceHistory:(int)offset;
- (void)attachToWindow:(NSWindow*)window at:(NSPoint)point;
- (void)dealloc;
- (BOOL)hasMethod:(NPIdentifier)name;
- (BOOL)invokeMethod:(NPIdentifier)name args:(const NPVariant*)args len:(uint32_t)num_args result:(NPVariant*)result;
- (id)initWithNPP:(NPP)npp;
- (void)print;
- (void)setFile:(const char*)filename;
- (void)setFrameSize:(NSSize)size;
- (NPObject*)getScriptableObject;
- (int)find:(NSString*)string caseSensitive:(bool)caseSensitive forwards:(bool)forwards;
- (void)findAll:(NSString*)string caseSensitive:(bool)caseSensitive;
- (void)setTabCallback:(NPObject*)callback;
- (void)setHistoryCallback:(NPObject*)callback;
- (void)removeHighlights;
- (PDFView*)pdfView;
@end
