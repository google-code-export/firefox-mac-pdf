//
//  PDFPluginShim.mm
//  pdfplugin
//
//  Created by Sam Gross on 10/4/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

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
  NSLog(@"PDFPluginShim::~PDFPluginShim");
  /* destructor code */
}

/* void Copy (); */
NS_IMETHODIMP PDFPluginShim::Copy()
{
  [_plugin copy];
  return NS_OK;
}

/* boolean Find (in ACString str, in boolean caseSensitive, in boolean forward); */
NS_IMETHODIMP PDFPluginShim::Find(const nsACString & str, PRBool caseSensitive, PRBool forward, PRBool *_retval)
{
  const char* data; // not null terminated
  PRUint32 len = NS_CStringGetData(str, &data);
  NSString* nsString = [NSString stringWithCString:data length:len];
  
  *_retval = [_plugin find:nsString caseSensitive:caseSensitive forwards:forward];
  return NS_OK;
}

/* boolean FindAll (in ACString str, in boolean caseSensitive); */
NS_IMETHODIMP PDFPluginShim::FindAll(const nsACString & str, PRBool caseSensitive)
{
  const char* data; // not null terminated
  PRUint32 len = NS_CStringGetData(str, &data);
  NSString* nsString = [NSString stringWithCString:data length:len];

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


