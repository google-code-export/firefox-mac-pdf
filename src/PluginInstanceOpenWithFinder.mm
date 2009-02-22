/*
 * Copyright (C) 2005, 2006, 2007 Apple Inc. All rights reserved.
 * Copyright (c) 2008 Samuel Gross.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * 1.  Redistributions of source code must retain the above copyright
 *     notice, this list of conditions and the following disclaimer. 
 * 2.  Redistributions in binary form must reproduce the above copyright
 *     notice, this list of conditions and the following disclaimer in the
 *     documentation and/or other materials provided with the distribution. 
 * 3.  Neither the name of Apple Computer, Inc. ("Apple") nor the names of
 *     its contributors may be used to endorse or promote products derived
 *     from this software without specific prior written permission. 
 *
 * THIS SOFTWARE IS PROVIDED BY APPLE AND ITS CONTRIBUTORS "AS IS" AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL APPLE OR ITS CONTRIBUTORS BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */
#import "PluginInstance.h"
#import <unistd.h>

// This includes source code from the WebPDFView.mm in the WebKit project

static inline id WebCFAutorelease(CFTypeRef obj)
{
  if (obj)
      CFMakeCollectable(obj);
  [(id)obj autorelease];
  return (id)obj;
}


@interface PluginInstance (FileInternal)
- (NSString *)_path;
- (NSString *)_temporaryPDFDirectoryPath;
@end

@implementation PluginInstance (OpenWithFinder)

- (NSData *)convertPostScriptDataSourceToPDF:(NSData *)data
{
    // Convert PostScript to PDF using Quartz 2D API
    // http://developer.apple.com/documentation/GraphicsImaging/Conceptual/drawingwithquartz2d/dq_ps_convert/chapter_16_section_1.html

    CGPSConverterCallbacks callbacks = { 0, 0, 0, 0, 0, 0, 0, 0 };    
    CGPSConverterRef converter = CGPSConverterCreate(0, &callbacks, 0);

    CGDataProviderRef provider = CGDataProviderCreateWithCFData((CFDataRef)data);

    CFMutableDataRef result = CFDataCreateMutable(kCFAllocatorDefault, 0);

    CGDataConsumerRef consumer = CGDataConsumerCreateWithCFData(result);

    // Error handled by detecting zero-length 'result' in caller
    CGPSConverterConvert(converter, provider, consumer, 0);

    CFRelease(converter);
    CFRelease(provider);
    CFRelease(consumer);

    return WebCFAutorelease(result);
}

- (void)openWithFinder
{  
  // We don't want to write the file until we have a document to write.
  if (! [_pdfView document]) {
    NSBeep();
    return;
  }
  NSString *opath = [self _path];
  if (opath) {
    if (!written) {
      // Create a PDF file with the minimal permissions (only accessible to the current user, see 4145714)
      NSNumber *permissions = [[NSNumber alloc] initWithInt:S_IRUSR];
      NSDictionary *fileAttributes = [[NSDictionary alloc] initWithObjectsAndKeys:permissions, NSFilePosixPermissions, nil];
      [permissions release];

      [[NSFileManager defaultManager] createFileAtPath:opath 
                                      contents:_data
                                      attributes:fileAttributes];
      [fileAttributes release];
      written = YES;
    }
      
    if (![[NSWorkspace sharedWorkspace] openFile:opath]) {
        // NSWorkspace couldn't open file.  Do we need an alert
        // here?  We ignore the error elsewhere.
    }
  }
}

- (NSString *)_path
{
  // Generate path once.
  if (path)
    return path;

  NSURLResponse *urlResponse = [[NSURLResponse alloc] 
                                    initWithURL:[NSURL URLWithString:_url]
                                    MIMEType:_mimeType
                                    expectedContentLength:-1
                                    textEncodingName:nil];
  NSString *filename = [urlResponse suggestedFilename];
  [urlResponse release];

  NSFileManager *manager = [NSFileManager defaultManager]; 
  NSString *temporaryPDFDirectoryPath = [self _temporaryPDFDirectoryPath];
  
  if (!temporaryPDFDirectoryPath) {
    // This should never happen; if it does we'll fail silently on non-debug builds.
    // ASSERT_NOT_REACHED();
    return nil;
  }
  
  path = [temporaryPDFDirectoryPath stringByAppendingPathComponent:filename];
  if ([manager fileExistsAtPath:path]) {
    NSString *pathTemplatePrefix = [temporaryPDFDirectoryPath stringByAppendingPathComponent:@"XXXXXX-"];
    NSString *pathTemplate = [pathTemplatePrefix stringByAppendingString:filename];
    // fileSystemRepresentation returns a const char *; copy it into a char * so we can modify it safely
    char *cPath = strdup([pathTemplate fileSystemRepresentation]);
    int fd = mkstemps(cPath, strlen(cPath) - strlen([pathTemplatePrefix fileSystemRepresentation]) + 1);
    if (fd < 0) {
      // Couldn't create a temporary file! Should never happen; if it does we'll fail silently on non-debug builds.
      // ASSERT_NOT_REACHED();
      path = nil;
    } else {
      close(fd);
      path = [manager stringWithFileSystemRepresentation:cPath length:strlen(cPath)];
    }
    free(cPath);
  }
  
  [path retain];

  return path;
}

- (NSString *)_temporaryPDFDirectoryPath
{
  // Returns nil if the temporary PDF directory didn't exist and couldn't be created
  
  static NSString *_temporaryPDFDirectoryPath = nil;
  
  if (!_temporaryPDFDirectoryPath) {
    NSString *temporaryDirectoryTemplate = [NSTemporaryDirectory() stringByAppendingPathComponent:@"FirefoxMacPDFs-XXXXXX"];
    char *cTemplate = strdup([temporaryDirectoryTemplate fileSystemRepresentation]);
    
    if (!mkdtemp(cTemplate)) {
        // This should never happen; if it does we'll fail silently on non-debug builds.
        // ASSERT_NOT_REACHED();
    } else {
        // cTemplate has now been modified to be the just-created directory name. This directory has 700 permissions,
        // so only the current user can add to it or view its contents.
        _temporaryPDFDirectoryPath = [[[NSFileManager defaultManager] stringWithFileSystemRepresentation:cTemplate length:strlen(cTemplate)] retain];
    }
    
      free(cTemplate);
  }
  
  return _temporaryPDFDirectoryPath;
}

@end
