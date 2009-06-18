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
#import "Preferences.h"

#include "xpcom-config.h"
#include "nsIPrefBranch.h"
#include "nsIPrefService.h"
#include "nsCOMPtr.h"
#include "nsDirectoryServiceUtils.h"

@implementation Preferences

+ (BOOL)getBoolPreference:(const char*)key
{
  nsCOMPtr<nsIPrefService> prefsService;
  prefsService = do_GetService("@mozilla.org/preferences-service;1");
  nsCOMPtr<nsIPrefBranch> prefs;
  prefsService->GetBranch("extensions.firefox-pdf-mac.", getter_AddRefs(prefs));
  PRBool value = false;
  prefs->GetBoolPref(key, &value);
  return value;
}

+ (float)getFloatPreference:(const char*)key
{
  nsCOMPtr<nsIPrefService> prefsService;
  prefsService = do_GetService("@mozilla.org/preferences-service;1");
  nsCOMPtr<nsIPrefBranch> prefs;
  prefsService->GetBranch("extensions.firefox-pdf-mac.", getter_AddRefs(prefs));
  char* value = NULL;
  prefs->GetCharPref(key, &value);
  if (value == NULL) {
    return 1.0;
  }
  return [[NSString stringWithCString:value encoding:NSASCIIStringEncoding] floatValue];
}

+ (int)getIntPreference:(const char*)key
{
  nsCOMPtr<nsIPrefService> prefsService;
  prefsService = do_GetService("@mozilla.org/preferences-service;1");
  nsCOMPtr<nsIPrefBranch> prefs;
  prefsService->GetBranch("extensions.firefox-pdf-mac.", getter_AddRefs(prefs));
  int value = 1;
  prefs->GetIntPref(key, &value);
  return value;
}

+ (void)setBoolPreference:(const char*)key value:(BOOL)value
{
  nsCOMPtr<nsIPrefService> prefsService;
  prefsService = do_GetService("@mozilla.org/preferences-service;1");
  nsCOMPtr<nsIPrefBranch> prefs;
  prefsService->GetBranch("extensions.firefox-pdf-mac.", getter_AddRefs(prefs));
  prefs->SetBoolPref(key, value);
}

+ (void)setFloatPreference:(const char*)key value:(float)value
{
  nsCOMPtr<nsIPrefService> prefsService;
  prefsService = do_GetService("@mozilla.org/preferences-service;1");
  nsCOMPtr<nsIPrefBranch> prefs;
  prefsService->GetBranch("extensions.firefox-pdf-mac.", getter_AddRefs(prefs));
  prefs->SetCharPref(key, [[NSString stringWithFormat:@"%f", value] cStringUsingEncoding:NSASCIIStringEncoding]);
}

+ (void)setIntPreference:(const char*)key value:(int)value
{
  nsCOMPtr<nsIPrefService> prefsService;
  prefsService = do_GetService("@mozilla.org/preferences-service;1");
  nsCOMPtr<nsIPrefBranch> prefs;
  prefsService->GetBranch("extensions.firefox-pdf-mac.", getter_AddRefs(prefs));
  prefs->SetIntPref(key, value);
}

@end
