//
//  PDFPluginShim.h
//  pdfplugin
//
//  Created by Sam Gross on 10/4/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "PDFPlugin.h"

@class PluginInstance;

class PDFPluginShim : public PDFPlugin
{
public:
  NS_DECL_ISUPPORTS
  NS_DECL_PDFPLUGIN

  PDFPluginShim(PluginInstance* plugin);

private:
  ~PDFPluginShim();
  const PluginInstance* _plugin;
};

