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
#include "npapi.h"
#include "npruntime.h"

#include "PDFService.h"
#include "nsCOMPtr.h"
#include "nsServiceManagerUtils.h"


NPError NPP_Initialize() {
  return NPERR_NO_ERROR;
}

void NPP_Shutdown() {
}

NPError NPP_New(NPMIMEType pluginType, NPP npp, uint16 mode, int16 argc, char* argn[], char* argv[], NPSavedData* saved) {
  NSLog(@"NPP_New(npp=%8p,mode=%d,argc=%d)\n", npp, mode, argc);
  if (npp == NULL) {
    return NPERR_INVALID_INSTANCE_ERROR;
  }
  
  // Check if the browser supports the CoreGraphics drawing model
  NPBool supportsCoreGraphics = FALSE;
  NPError err = NPN_GetValue(npp, NPNVsupportsCoreGraphicsBool, &supportsCoreGraphics);
  if (err != NPERR_NO_ERROR || !supportsCoreGraphics) {
    NSLog(@"firefox-mac-pdf: does not support core graphics");
    return NPERR_INCOMPATIBLE_VERSION_ERROR;
  }
  
  // Set the drawing model
  err = NPN_SetValue(npp, NPPVpluginDrawingModel, (void*) NPDrawingModelCoreGraphics);
  if (err != NPERR_NO_ERROR) {
    NSLog(@"firefox-mac-pdf: does not support drawing model");
    return NPERR_INCOMPATIBLE_VERSION_ERROR;
  }
  
  // select the Carbon event model
  // I'm not absolutely sure that this is necessary, but the documentation
  // suggests that the Cocoa event model is used by default in 64-bit plugins,
  // which will definitely not work for this plugin.
  // The problem with the Cocoa event model is that there is no way to get the
  // browser's NSWindow or NSView, which we need to attach the PDFView
  NPBool supportsCarbonEvents = false;
  if (NPN_GetValue(npp, NPNVsupportsCarbonBool, &supportsCarbonEvents) == NPERR_NO_ERROR && supportsCarbonEvents) {
    NPN_SetValue(npp, NPPVpluginEventModel, (void*)NPEventModelCarbon);
  } else {
    printf("Carbon event model not supported, can't create a plugin instance.\n");
    return NPERR_INCOMPATIBLE_VERSION_ERROR;
  }

  
  nsCOMPtr<PDFService> pdfService(do_GetService("@sgross.mit.edu/pdfservice;1"));
  if (!pdfService) {
    NSLog(@"firefox-mac-pdf: could not get PDF service");
    return NPERR_GENERIC_ERROR;
  }
  
  NPObject* pluginElement;
  err = NPN_GetValue(npp, NPNVPluginElementNPObject, &pluginElement);
  if (err != NPERR_NO_ERROR) {
    NSLog(@"firefox-mac-pdf: could not get PluginElement object");
    return NPERR_GENERIC_ERROR;
  }
  
  NPIdentifier idName = NPN_GetStringIdentifier("plugin_id");
  NPVariant idValue;
  NSString* pluginId = [NSString stringWithFormat:@"%x%x%x%x", arc4random(), 
                            arc4random(), arc4random(), arc4random()];
  STRINGZ_TO_NPVARIANT([pluginId cStringUsingEncoding:NSASCIIStringEncoding], idValue);
  if (!NPN_SetProperty(npp, pluginElement, idName, &idValue)) {
    NSLog(@"firefox-mac-pdf: could not set plugin_id");
    return NPERR_GENERIC_ERROR;
  }

  NSString* mimeType = [NSString stringWithUTF8String:pluginType];

  // allocate the plugin
  npp->pdata = [[PluginInstance alloc] initWithService:pdfService.get()
                                            plugin_id:pluginId
                                            npp:npp
                                            mimeType:mimeType];
  
  return NPERR_NO_ERROR;
}

NPError NPP_Destroy(NPP instance, NPSavedData** save) {
  if (instance == NULL) {
    return NPERR_INVALID_INSTANCE_ERROR;
  }
//  NSLog(@"NPP_Destroy: %d", (int) instance->pdata);
  PluginInstance* plugin = (PluginInstance*) instance->pdata;
  if (plugin) {
    [plugin updatePreferences];
    [plugin release];
    instance->pdata = NULL;
  }
  return NPERR_NO_ERROR;
}


bool getVisible(NPWindow*) __attribute ((__noinline__));
bool getVisible(NPWindow* window) {
  NPRect clipRect = window->clipRect;
  return (clipRect.top != clipRect.bottom && clipRect.left != clipRect.right);
}

void maybeAttach(PluginInstance*, NPWindow*) __attribute ((__noinline__));
void maybeAttach(PluginInstance* plugin, NPWindow* window) {
  // attach the plugin if it's not attached and is visible
  NPRect clipRect = window->clipRect;
  if (![plugin attached]) {
    NP_CGContext* npContext = (NP_CGContext*) window->window;
    NSWindow* browserWindow = [[[NSWindow alloc] initWithWindowRef:npContext->window] autorelease];
    int y = [browserWindow frame].size.height - (clipRect.bottom - clipRect.top) - window->y;
    [plugin attachToWindow:browserWindow at:NSMakePoint(window->x, y)];
  }
}

void maybeSetVisible(PluginInstance*, bool) __attribute ((__noinline__));
void maybeSetVisible(PluginInstance* plugin, bool visible) {
  if ([plugin attached]) {
    [plugin setVisible:visible];
  }
}

NPError NPP_SetWindow(NPP instance, NPWindow* window) {
  PluginInstance* plugin = (PluginInstance*)instance->pdata;
  
  bool visible = getVisible(window);
  if (visible) {
    maybeAttach(plugin, window);
  }
  maybeSetVisible(plugin, visible);

  return NPERR_NO_ERROR;
}


NPError NPP_NewStream(NPP instance, NPMIMEType type, NPStream* stream, NPBool seekable, uint16* stype) {
//  NSLog(@"NPP_NewStream end=%d", (int) stream->end);
  NSMutableData* data = [NSMutableData dataWithCapacity:stream->end];
  stream->pdata = [data retain];

  PluginInstance* plugin = (PluginInstance*)instance->pdata;
  [plugin setUrl:[NSString stringWithUTF8String:stream->url]];

  *stype = NP_NORMAL;
  return NPERR_NO_ERROR;
}

NPError NPP_DestroyStream(NPP instance, NPStream* stream, NPReason reason) {
//  NSLog(@"NPP_DestroyStream reason: %d", (int) reason);
  NSMutableData* data = (NSMutableData*) stream->pdata;
  PluginInstance* plugin = (PluginInstance*)instance->pdata;
  if (reason == 0) {
    [plugin setData:data];
  } else {
    [plugin downloadFailed];
  }
  [data release];
  return NPERR_NO_ERROR;
}

int32 NPP_WriteReady(NPP instance, NPStream* stream) {
  //NSLog(@"NPP_WriteReady");
  return 2147483647;
}

int32 NPP_Write(NPP instance, NPStream* stream, int32 offset, int32 len, void* buffer) {
  NSMutableData* data = (NSMutableData*) stream->pdata;
  [data appendBytes:buffer length:len];
  
  PluginInstance* plugin = (PluginInstance*)instance->pdata;
  [plugin setProgress:offset total:stream->end];
  
  return len;
}

void NPP_StreamAsFile(NPP instance, NPStream* stream, const char* fname) {
}

void NPP_Print(NPP instance, NPPrint* platformPrint) {
  PluginInstance* plugin = (PluginInstance*)instance->pdata;
  [plugin print];
}

int16 NPP_HandleEvent(NPP instance, void* _event) {
//  NPEvent* event = (NPEvent*) _event;
//  PluginInstance* plugin = (PluginInstance*)instance->pdata;
//  // seems to be called after plugin is created. use it to give plugin focus
//  const int updateEvt = 6; 
//  if (event->what == NPEventType_GetFocusEvent || event->what == updateEvt) {
//    [plugin requestFocus];
//    return 1;
//  }
  return 0;
}

void NPP_URLNotify(NPP instance, const char* url, NPReason reason, void* notifyData) {
}

NPError NPP_GetValue(NPP npp, NPPVariable variable, void *value) {
  return NPERR_GENERIC_ERROR;
}

NPError NPP_SetValue(NPP instance, NPNVariable variable, void *value) {
  return NPERR_GENERIC_ERROR;
}
