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
#import "PDFPluginShim.h"
#import "PluginInstance.h"

#include "nsStringAPI.h"

NS_IMPL_ISUPPORTS1(PDFPluginShim, PDFPlugin)

PDFPluginShim::PDFPluginShim(PluginInstance* plugin) : _plugin(plugin)
{
  /* member initializers and constructor code */
}

PDFPluginShim::~PDFPluginShim()
{
  /* destructor code */
}

/* void Copy (); */
NS_IMETHODIMP PDFPluginShim::Copy()
{
  [_plugin copy];
  return NS_OK;
}

/* boolean Find (in ACString str, in boolean caseSensitive, in boolean forward); */
NS_IMETHODIMP PDFPluginShim::Find(const nsAString & str, PRBool caseSensitive, PRBool forward, PRBool *_retval)
{
  char* data = ToNewUTF8String(str);
  NSString* nsString = [NSString stringWithUTF8String:data];
  NS_Free(data);
  
  *_retval = [_plugin find:nsString caseSensitive:caseSensitive forwards:forward];

  return NS_OK;
}

/* boolean FindAll (in ACString str, in boolean caseSensitive); */
NS_IMETHODIMP PDFPluginShim::FindAll(const nsAString & str, PRBool caseSensitive)
{
  char* data = ToNewUTF8String(str);
  NSString* nsString = [NSString stringWithUTF8String:data];
  NS_Free(data);

  [_plugin findAll:nsString caseSensitive:caseSensitive];
  
  return NS_OK;
}

/* void RemoveHighlights (); */
NS_IMETHODIMP PDFPluginShim::RemoveHighlights()
{
  [_plugin removeHighlights];
  return NS_OK;
}

/* void Zoom (in long arg); */
NS_IMETHODIMP PDFPluginShim::Zoom(PRInt32 arg)
{
  if (![_plugin zoom:arg]) {
    return NS_ERROR_INVALID_ARG;
  }
  return NS_OK;  
}
