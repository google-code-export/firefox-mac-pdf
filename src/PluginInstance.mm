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

typedef struct PluginNPObject : NPObject {
  PluginInstance* plugin;
} PluginNPObject;

static NPObject* Allocate(NPP npp, NPClass *npclass) {
  return (NPObject*) NPN_MemAlloc(sizeof(PluginNPObject));
}

static void Deallocate(NPObject *npobj) {
  NPN_MemFree((void*)npobj);
}

static bool HasMethod(NPObject *npobj, NPIdentifier name) {
  PluginNPObject* obj = static_cast<PluginNPObject*>(npobj);
  return [obj->plugin hasMethod:name];
}

static bool Invoke(NPObject *npobj, NPIdentifier name, const NPVariant *args, uint32_t num_args, NPVariant *result) {
  VOID_TO_NPVARIANT(*result);
  PluginNPObject* obj = static_cast<PluginNPObject*>(npobj);
  return [obj->plugin invokeMethod:name args:args len:num_args result:result];
}

static bool HasProperty(NPObject *npobj, NPIdentifier name) {
  return FALSE;
}  

static bool GetProperty(NPObject *npobj, NPIdentifier name, NPVariant *result) {
  return FALSE;
}

static NPClass pluginNPClass = {
  NP_CLASS_STRUCT_VERSION,
  Allocate,
  Deallocate,
  NULL,  // Invalidate,
  HasMethod,
  Invoke,
  NULL,  // InvokeDefault,
  HasProperty,
  GetProperty,
  NULL,  // SetProperty,
  NULL   // RemoveProperty
};



@implementation PluginInstance

- (BOOL)attached
{
  return _attached;
}

- (void)attachToWindow:(NSWindow*)window at:(NSPoint)point
{
  //debugView([window contentView], 0);
  // find the NSView at the point
  _attached = true;
  NSView* view = [[window contentView] hitTest:NSMakePoint(point.x+1, point.y+1)];
  [view addSubview:_pdfView];
}

- (void)dealloc
{
  [_pdfView release];
  [selectionController release];
  [_searchResults release];
  if (_scriptableObject) {
    NPN_ReleaseObject(_scriptableObject);
  }
  if (_tabCallback) {
    NPN_ReleaseObject(_tabCallback);
  }
  if (_historyCallback) {
    NPN_ReleaseObject(_historyCallback);
  }
  [super dealloc];
}

- (id)initWithNPP:(NPP)npp
{
  if (self = [super init]) {
    _pdfView = [[PluginPDFView alloc] initWithPlugin:self];
    selectionController = [[SelectionController forPDFView:_pdfView] retain];
    _npp = npp;
    IDENT_FIND = NPN_GetStringIdentifier("find");
    IDENT_FINDALL = NPN_GetStringIdentifier("findAll");
    IDENT_ZOOM = NPN_GetStringIdentifier("zoom");
    IDENT_REMOVEHIGHLIGHTS = NPN_GetStringIdentifier("removeHighlights");
    IDENT_SETTABCALLBACK = NPN_GetStringIdentifier("setTabCallback");
    IDENT_SETHISTORYCALLBACK = NPN_GetStringIdentifier("setHistoryCallback");
  }
  return self;
}

- (void)print 
{
  [_pdfView print:self];
}

- (void)setFile:(const char*)filename
{
  // create PDF document
  NSURL* url = [NSURL fileURLWithPath:[NSString stringWithUTF8String:filename]];
  PDFDocument* document = [[[PDFDocument alloc] initWithURL:url] autorelease];
  [document setDelegate:self];
  [_pdfView setDocument:document];
}

- (void)setFrameSize:(NSSize)size
{
  [_pdfView setFrameSize:size];
}

- (NPObject*)getScriptableObject
{
  if (_scriptableObject == NULL) {
    PluginNPObject* obj = static_cast<PluginNPObject*>(NPN_CreateObject(_npp, &pluginNPClass));
    obj->plugin = self;
    _scriptableObject = obj;
  }
  // This is a weird one: I think the browser wants us to increment the ref count for each instance returned
  NPN_RetainObject(_scriptableObject);
  return _scriptableObject;
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

  PDFDocument* doc = [_pdfView document];

  // only one search can take place at a time
  if ([doc isFinding]) {
    [doc cancelFindString];
  }

  if ([string length] == 0) {
    [selectionController setCurrentSelection:nil];
    return FOUND;
  }

  // see WebPDFView.mm in WebKit for general technique
  PDFSelection* initialSelection = [[_pdfView currentSelection] copy];
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

- (void)setTabCallback:(NPObject*)callback
{
  NPN_RetainObject(callback);
  if (_tabCallback) {
    NPN_ReleaseObject(_tabCallback);
  }
  _tabCallback = callback;
}

- (void)advanceTab:(int)offset
{
  if (_tabCallback) {
    NPVariant arg;
    INT32_TO_NPVARIANT(offset, arg);
    NPVariant result;
    NPN_InvokeDefault(_npp, _tabCallback, &arg, 1, &result);
    NPN_ReleaseVariantValue(&arg);
    NPN_ReleaseVariantValue(&result);
  }
}

- (void)setHistoryCallback:(NPObject*)callback
{
  NPN_RetainObject(callback);
  if (_historyCallback) {
    NPN_ReleaseObject(_historyCallback);
  }
  _historyCallback = callback;
}

- (void)advanceHistory:(int)offset
{
  if (_historyCallback) {
    NPVariant arg;
    INT32_TO_NPVARIANT(offset, arg);
    NPVariant result;
    NPN_InvokeDefault(_npp, _historyCallback, &arg, 1, &result);
    NPN_ReleaseVariantValue(&arg);
    NPN_ReleaseVariantValue(&result);
  }
}

- (void)findAll:(NSString*)string caseSensitive:(bool)caseSensitive
{
  PDFDocument* doc = [_pdfView document];
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

- (PDFView*)pdfView
{
  return _pdfView;
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


- (BOOL)hasMethod:(NPIdentifier)name
{
  return name == IDENT_FIND || name == IDENT_FINDALL || name == IDENT_ZOOM || name == IDENT_REMOVEHIGHLIGHTS
      || name == IDENT_SETHISTORYCALLBACK || name == IDENT_SETTABCALLBACK;
}

static NSString* variantToNSString(NPVariant variant) {
  NPString str = NPVARIANT_TO_STRING(variant);
  // copy the data and add a null terminating character
  char data[str.utf8length+1];
  memcpy(data, str.utf8characters, str.utf8length);
  data[str.utf8length] = '\0';
  return [NSString stringWithUTF8String:data];
}

- (BOOL)invokeMethod:(NPIdentifier)name args:(const NPVariant*)args len:(uint32_t)num_args result:(NPVariant*)result
{
  if (name == IDENT_FIND) {
    if (num_args != 3 || !NPVARIANT_IS_STRING(args[0]) || !NPVARIANT_IS_BOOLEAN(args[1])
        || !NPVARIANT_IS_BOOLEAN(args[2])) {
      return NO;
    }
    NSString* str = variantToNSString(args[0]);    
    bool caseSensitive = NPVARIANT_TO_BOOLEAN(args[1]);
    bool forwards = NPVARIANT_TO_BOOLEAN(args[2]);
    int res = [self find:str caseSensitive:caseSensitive forwards:forwards];
    INT32_TO_NPVARIANT(res, *result);
    return YES;
  }
  if (name == IDENT_FINDALL) {
    if (num_args != 2 || !NPVARIANT_IS_STRING(args[0]) || !NPVARIANT_IS_BOOLEAN(args[1])) {
      return NO;
    }
    NSString* str = variantToNSString(args[0]);
    bool caseSensitive = NPVARIANT_TO_BOOLEAN(args[1]);
    [self findAll:str caseSensitive:caseSensitive];
    return YES;
  }
  if (name == IDENT_ZOOM) {
    if (num_args != 1 || !NPVARIANT_IS_INT32(args[0])) {
      return NO;
    }
    // -1: zoom out, 1: zoom in, 0: reset
    int zoomArg = NPVARIANT_TO_INT32(args[0]);
    switch (zoomArg) {
      case -1:
        [_pdfView zoomOut:nil];
        break;
      case 0:
        [_pdfView setScaleFactor:1.0];
        break;
      case 1:
        [_pdfView zoomIn:nil];
        break;
      default:
        return NO;
    }
    return YES;
  }
  if (name == IDENT_REMOVEHIGHLIGHTS) {
    if (num_args != 0) {
      return NO;
    }
    [self removeHighlights];
    return YES;
  }
  if (name == IDENT_SETTABCALLBACK) {
    if (num_args != 1 || !NPVARIANT_IS_OBJECT(args[0])) {
      return NO;
    }
    [self setTabCallback:NPVARIANT_TO_OBJECT(args[0])];
    return YES;
  }
  if (name == IDENT_SETHISTORYCALLBACK) {
    if (num_args != 1 || !NPVARIANT_IS_OBJECT(args[0])) {
      return NO;
    }
    [self setHistoryCallback:NPVARIANT_TO_OBJECT(args[0])];
    return YES;
  }
  return NO;
}

@end