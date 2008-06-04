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
#include "main.h"

extern "C" {
#pragma export on
  NPError NP_Initialize(NPNetscapeFuncs* browserFuncs);
  NPError NP_GetEntryPoints(NPPluginFuncs* pluginFuncs);
  char *NP_GetMIMEDescription();
  void NP_Shutdown(void);
#pragma export off
}

NPError NP_Initialize(NPNetscapeFuncs* browserFuncs) {
  SetNPNFuncs(browserFuncs);
  return NPERR_NO_ERROR;
}

NPError NP_GetEntryPoints(NPPluginFuncs* pluginFuncs) {
  if (pluginFuncs->size < sizeof(NPPluginFuncs)) {
    return NPERR_INVALID_FUNCTABLE_ERROR;
  }
  pluginFuncs->version       = (NP_VERSION_MAJOR << 8) | NP_VERSION_MINOR;
  pluginFuncs->newp          = NPP_New;
  pluginFuncs->destroy       = NPP_Destroy;
  pluginFuncs->setwindow     = NPP_SetWindow;
  pluginFuncs->newstream     = NPP_NewStream;
  pluginFuncs->destroystream = NPP_DestroyStream;
  pluginFuncs->asfile        = NPP_StreamAsFile;
  pluginFuncs->writeready    = NPP_WriteReady;
  pluginFuncs->write         = NPP_Write;
  pluginFuncs->print         = NPP_Print;
  pluginFuncs->event         = NPP_HandleEvent;
  pluginFuncs->urlnotify     = NPP_URLNotify;
  pluginFuncs->getvalue      = NPP_GetValue;
  pluginFuncs->setvalue      = NPP_SetValue;
  pluginFuncs->javaClass     = NULL;
  return NPERR_NO_ERROR;
}

char *NP_GetMIMEDescription() {
  return "application/pdf:pdf:PDF document";
}

void NP_Shutdown(void) {
  return;
}