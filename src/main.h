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
#ifndef _MAIN_H_
#define _MAIN_H_

#include "mozincludes.h"

NPError	NPP_New(NPMIMEType pluginType, NPP instance, uint16 mode,
                 int16 argc, char* argn[], char* argv[], NPSavedData* saved);
NPError	NPP_Destroy(NPP instance, NPSavedData** save);
NPError	NPP_SetWindow(NPP instance, NPWindow* window);
NPError	NPP_NewStream(NPP instance, NPMIMEType type, NPStream* stream,
                       NPBool seekable, uint16* stype);
NPError	NPP_DestroyStream(NPP instance, NPStream* stream, NPReason reason);
int32		NPP_WriteReady(NPP instance, NPStream* stream);
int32		NPP_Write(NPP instance, NPStream* stream, int32 offset, int32 len,
                   void* buffer);
void		NPP_StreamAsFile(NPP instance, NPStream* stream, const char* fname);
void		NPP_Print(NPP instance, NPPrint* platformPrint);
int16		NPP_HandleEvent(NPP instance, void* event);
void		NPP_URLNotify(NPP instance, const char* URL, NPReason reason,
                       void* notifyData);
NPError	NPP_GetValue(NPP instance, NPPVariable variable, void *value);
NPError	NPP_SetValue(NPP instance, NPNVariable variable, void *value);

#endif