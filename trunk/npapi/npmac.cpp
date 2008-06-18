/* ***** BEGIN LICENSE BLOCK *****
 * Version: MPL 1.1/GPL 2.0/LGPL 2.1
 *
 * The contents of this file are subject to the Mozilla Public License Version
 * 1.1 (the "License"); you may not use this file except in compliance with
 * the License. You may obtain a copy of the License at
 * http://www.mozilla.org/MPL/
 *
 * Software distributed under the License is distributed on an "AS IS" basis,
 * WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
 * for the specific language governing rights and limitations under the
 * License.
 *
 * The Original Code is mozilla.org code.
 *
 * The Initial Developer of the Original Code is
 * Netscape Communications Corporation.
 * Portions created by the Initial Developer are Copyright (C) 1998
 * the Initial Developer. All Rights Reserved.
 *
 * Contributor(s):
 *
 * Alternatively, the contents of this file may be used under the terms of
 * either the GNU General Public License Version 2 or later (the "GPL"), or
 * the GNU Lesser General Public License Version 2.1 or later (the "LGPL"),
 * in which case the provisions of the GPL or the LGPL are applicable instead
 * of those above. If you wish to allow use of your version of this file only
 * under the terms of either the GPL or the LGPL, and not to allow others to
 * use your version of this file under the terms of the MPL, indicate your
 * decision by deleting the provisions above and replace them with the notice
 * and other provisions required by the GPL or the LGPL. If you do not delete
 * the provisions above, a recipient may use your version of this file under
 * the terms of any one of the MPL, the GPL or the LGPL.
 *
 * ***** END LICENSE BLOCK ***** */

//::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
//
// npmac.cpp
//
//::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

#include <string.h>

#include <Carbon/Carbon.h>

#include "npapi.h"
#include "mozincludes.h"

//
// Define PLUGIN_TRACE to 1 to have the wrapper functions emit
// DebugStr messages whenever they are called.
//
//#define PLUGIN_TRACE 1

#if PLUGIN_TRACE
#define PLUGINDEBUGSTR(msg)		::DebugStr(msg)
#else
#define PLUGINDEBUGSTR(msg)    ((void) 0)
#endif

#ifdef __ppc__

// glue for mapping outgoing Macho function pointers to TVectors
struct TFPtoTVGlue{
    void* glue[2];
};

struct pluginFuncsGlueTable {
    TFPtoTVGlue     newp;
    TFPtoTVGlue     destroy;
    TFPtoTVGlue     setwindow;
    TFPtoTVGlue     newstream;
    TFPtoTVGlue     destroystream;
    TFPtoTVGlue     asfile;
    TFPtoTVGlue     writeready;
    TFPtoTVGlue     write;
    TFPtoTVGlue     print;
    TFPtoTVGlue     event;
    TFPtoTVGlue     urlnotify;
    TFPtoTVGlue     getvalue;
    TFPtoTVGlue     setvalue;

    TFPtoTVGlue     shutdown;
} gPluginFuncsGlueTable;

static inline void* SetupFPtoTVGlue(TFPtoTVGlue* functionGlue, void* fp)
{
    functionGlue->glue[0] = fp;
    functionGlue->glue[1] = 0;
    return functionGlue;
}

#define PLUGIN_TO_HOST_GLUE(name, fp) (SetupFPtoTVGlue(&gPluginFuncsGlueTable.name, (void*)fp))

// glue for mapping netscape TVectors to Macho function pointers
struct TTVtoFPGlue {
    uint32 glue[6];
};

struct netscapeFuncsGlueTable {
    TTVtoFPGlue             geturl;
    TTVtoFPGlue             posturl;
    TTVtoFPGlue             requestread;
    TTVtoFPGlue             newstream;
    TTVtoFPGlue             write;
    TTVtoFPGlue             destroystream;
    TTVtoFPGlue             status;
    TTVtoFPGlue             uagent;
    TTVtoFPGlue             memalloc;
    TTVtoFPGlue             memfree;
    TTVtoFPGlue             memflush;
    TTVtoFPGlue             reloadplugins;
    TTVtoFPGlue             getJavaEnv;
    TTVtoFPGlue             getJavaPeer;
    TTVtoFPGlue             geturlnotify;
    TTVtoFPGlue             posturlnotify;
    TTVtoFPGlue             getvalue;
    TTVtoFPGlue             setvalue;
    TTVtoFPGlue             invalidaterect;
    TTVtoFPGlue             invalidateregion;
    TTVtoFPGlue             forceredraw;
    TTVtoFPGlue             getstringidentifier;
    TTVtoFPGlue             getstringidentifiers;
    TTVtoFPGlue             getintidentifier;
    TTVtoFPGlue             identifierisstring;
    TTVtoFPGlue             utf8fromidentifier;
    TTVtoFPGlue             intfromidentifier;
    TTVtoFPGlue             createobject;
    TTVtoFPGlue             retainobject;
    TTVtoFPGlue             releaseobject;
    TTVtoFPGlue             invoke;
    TTVtoFPGlue             invokeDefault;
    TTVtoFPGlue             evaluate;
    TTVtoFPGlue             getproperty;
    TTVtoFPGlue             setproperty;
    TTVtoFPGlue             removeproperty;
    TTVtoFPGlue             hasproperty;
    TTVtoFPGlue             hasmethod;
    TTVtoFPGlue             releasevariantvalue;
    TTVtoFPGlue             setexception;
    TTVtoFPGlue             pushpopupsenabledstate;
    TTVtoFPGlue             poppopupsenabledstate;
    TTVtoFPGlue             enumerate;
    TTVtoFPGlue             pluginthreadasynccall;
    TTVtoFPGlue             construct;
} gNetscapeFuncsGlueTable;

static void* SetupTVtoFPGlue(TTVtoFPGlue* functionGlue, void* tvp)
{
    static const TTVtoFPGlue glueTemplate = { 0x3D800000, 0x618C0000, 0x800C0000, 0x804C0004, 0x7C0903A6, 0x4E800420 };

    memcpy(functionGlue, &glueTemplate, sizeof(TTVtoFPGlue));
    functionGlue->glue[0] |= ((UInt32)tvp >> 16);
    functionGlue->glue[1] |= ((UInt32)tvp & 0xFFFF);
    ::MakeDataExecutable(functionGlue, sizeof(TTVtoFPGlue));
    return functionGlue;
}

#define HOST_TO_PLUGIN_GLUE(name, fp) (SetupTVtoFPGlue(&gNetscapeFuncsGlueTable.name, (void*)fp))

#else

#define PLUGIN_TO_HOST_GLUE(name, fp) (fp)
#define HOST_TO_PLUGIN_GLUE(name, fp) (fp)

#endif /* __ppc__ */



//::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
//
// Globals
//
//::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

NPNetscapeFuncs	gNetscapeFuncs;		// Function table for procs in Netscape called by plugin

//::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
//
// Wrapper functions for all calls from the plugin to Netscape.
// These functions let the plugin developer just call the APIs
// as documented and defined in npapi.h, without needing to know
// about the function table and call macros in npupp.h.
//
//::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::


void NPN_Version(int* plugin_major, int* plugin_minor, int* netscape_major, int* netscape_minor)
{
	*plugin_major = NP_VERSION_MAJOR;
	*plugin_minor = NP_VERSION_MINOR;
	*netscape_major = gNetscapeFuncs.version >> 8;		// Major version is in high byte
	*netscape_minor = gNetscapeFuncs.version & 0xFF;	// Minor version is in low byte
}

NPError NPN_GetURLNotify(NPP instance, const char* url, const char* window, void* notifyData)
{
	int navMinorVers = gNetscapeFuncs.version & 0xFF;
	NPError err;
	
	if( navMinorVers >= NPVERS_HAS_NOTIFICATION )
	{
		err = CallNPN_GetURLNotifyProc(gNetscapeFuncs.geturlnotify, instance, url, window, notifyData);
	}
	else
	{
		err = NPERR_INCOMPATIBLE_VERSION_ERROR;
	}
	return err;
}

NPError NPN_GetURL(NPP instance, const char* url, const char* window)
{
	return CallNPN_GetURLProc(gNetscapeFuncs.geturl, instance, url, window);
}

NPError NPN_PostURLNotify(NPP instance, const char* url, const char* window, uint32 len, const char* buf, NPBool file, void* notifyData)
{
	int navMinorVers = gNetscapeFuncs.version & 0xFF;
	NPError err;
	
	if( navMinorVers >= NPVERS_HAS_NOTIFICATION )
	{
		err = CallNPN_PostURLNotifyProc(gNetscapeFuncs.posturlnotify, instance, url, 
														window, len, buf, file, notifyData);
	}
	else
	{
		err = NPERR_INCOMPATIBLE_VERSION_ERROR;
	}
	return err;
}

NPError NPN_PostURL(NPP instance, const char* url, const char* window, uint32 len, const char* buf, NPBool file)
{
	return CallNPN_PostURLProc(gNetscapeFuncs.posturl, instance, url, window, len, buf, file);
}

NPError NPN_RequestRead(NPStream* stream, NPByteRange* rangeList)
{
	return CallNPN_RequestReadProc(gNetscapeFuncs.requestread, stream, rangeList);
}

NPError NPN_NewStream(NPP instance, NPMIMEType type, const char* window, NPStream** stream)
{
	int navMinorVers = gNetscapeFuncs.version & 0xFF;
	NPError err;
	
	if( navMinorVers >= NPVERS_HAS_STREAMOUTPUT )
	{
		err = CallNPN_NewStreamProc(gNetscapeFuncs.newstream, instance, type, window, stream);
	}
	else
	{
		err = NPERR_INCOMPATIBLE_VERSION_ERROR;
	}
	return err;
}

int32 NPN_Write(NPP instance, NPStream* stream, int32 len, void* buffer)
{
	int navMinorVers = gNetscapeFuncs.version & 0xFF;
	NPError err;
	
	if( navMinorVers >= NPVERS_HAS_STREAMOUTPUT )
	{
		err = CallNPN_WriteProc(gNetscapeFuncs.write, instance, stream, len, buffer);
	}
	else
	{
		err = NPERR_INCOMPATIBLE_VERSION_ERROR;
	}
	return err;
}

NPError	NPN_DestroyStream(NPP instance, NPStream* stream, NPError reason)
{
	int navMinorVers = gNetscapeFuncs.version & 0xFF;
	NPError err;
	
	if( navMinorVers >= NPVERS_HAS_STREAMOUTPUT )
	{
		err = CallNPN_DestroyStreamProc(gNetscapeFuncs.destroystream, instance, stream, reason);
	}
	else
	{
		err = NPERR_INCOMPATIBLE_VERSION_ERROR;
	}
	return err;
}

void NPN_Status(NPP instance, const char* message)
{
	CallNPN_StatusProc(gNetscapeFuncs.status, instance, message);
}

const char* NPN_UserAgent(NPP instance)
{
	return CallNPN_UserAgentProc(gNetscapeFuncs.uagent, instance);
}

void* NPN_MemAlloc(uint32 size)
{
	return CallNPN_MemAllocProc(gNetscapeFuncs.memalloc, size);
}

void NPN_MemFree(void* ptr)
{
	CallNPN_MemFreeProc(gNetscapeFuncs.memfree, ptr);
}

uint32 NPN_MemFlush(uint32 size)
{
	return CallNPN_MemFlushProc(gNetscapeFuncs.memflush, size);
}

void NPN_ReloadPlugins(NPBool reloadPages)
{
	CallNPN_ReloadPluginsProc(gNetscapeFuncs.reloadplugins, reloadPages);
}

#ifdef OJI
JRIEnv* NPN_GetJavaEnv(void)
{
	return CallNPN_GetJavaEnvProc( gNetscapeFuncs.getJavaEnv );
}

jobject  NPN_GetJavaPeer(NPP instance)
{
	return CallNPN_GetJavaPeerProc( gNetscapeFuncs.getJavaPeer, instance );
}
#endif

NPError NPN_GetValue(NPP instance, NPNVariable variable, void *value)
{
	return CallNPN_GetValueProc( gNetscapeFuncs.getvalue, instance, variable, value);
}

NPError NPN_SetValue(NPP instance, NPPVariable variable, void *value)
{
	return CallNPN_SetValueProc( gNetscapeFuncs.setvalue, instance, variable, value);
}

void NPN_InvalidateRect(NPP instance, NPRect *rect)
{
	CallNPN_InvalidateRectProc( gNetscapeFuncs.invalidaterect, instance, rect);
}

void NPN_InvalidateRegion(NPP instance, NPRegion region)
{
	CallNPN_InvalidateRegionProc( gNetscapeFuncs.invalidateregion, instance, region);
}

void NPN_ForceRedraw(NPP instance)
{
	CallNPN_ForceRedrawProc( gNetscapeFuncs.forceredraw, instance);
}

void NPN_PushPopupsEnabledState(NPP instance, NPBool enabled)
{
	CallNPN_PushPopupsEnabledStateProc( gNetscapeFuncs.pushpopupsenabledstate, instance, enabled);
}

void NPN_PopPopupsEnabledState(NPP instance)
{
	CallNPN_PopPopupsEnabledStateProc( gNetscapeFuncs.poppopupsenabledstate, instance);
}

NPObject *NPN_CreateObject(NPP npp, NPClass *aClass)
{
  return CallNPN_CreateObjectProc(gNetscapeFuncs.createobject, npp, aClass);
}

NPObject *NPN_RetainObject(NPObject *obj)
{
  return CallNPN_RetainObjectProc(gNetscapeFuncs.retainobject, obj);
}

void NPN_ReleaseObject(NPObject *obj)
{
  CallNPN_ReleaseObjectProc(gNetscapeFuncs.releaseobject, obj);
}

bool NPN_Invoke(NPP npp, NPObject* obj, NPIdentifier methodName,
                const NPVariant *args, uint32_t argCount, NPVariant *result)
{
  return CallNPN_InvokeProc(gNetscapeFuncs.invoke, npp, obj, methodName, args, argCount, result);
}

bool NPN_InvokeDefault(NPP npp, NPObject* obj, const NPVariant *args,
                       uint32_t argCount, NPVariant *result)
{
  return CallNPN_InvokeDefaultProc(gNetscapeFuncs.invokeDefault, npp, obj, args, argCount, result);
}

bool NPN_Evaluate(NPP npp, NPObject* obj, NPString *script,
                  NPVariant *result)
{
  return CallNPN_EvaluateProc(gNetscapeFuncs.evaluate, npp, obj, script, result);
}

bool NPN_GetProperty(NPP npp, NPObject* obj, NPIdentifier propertyName,
                     NPVariant *result)
{
  return CallNPN_GetPropertyProc(gNetscapeFuncs.getproperty, npp, obj, propertyName, result);
}

bool NPN_SetProperty(NPP npp, NPObject* obj, NPIdentifier propertyName,
                     const NPVariant *value)
{
  return CallNPN_SetPropertyProc(gNetscapeFuncs.setproperty, npp, obj, propertyName, value);
}

bool NPN_RemoveProperty(NPP npp, NPObject* obj, NPIdentifier propertyName)
{
  return CallNPN_RemovePropertyProc(gNetscapeFuncs.removeproperty, npp, obj, propertyName);
}

bool NPN_HasProperty(NPP npp, NPObject* obj, NPIdentifier propertyName)
{
  return CallNPN_HasPropertyProc(gNetscapeFuncs.hasproperty, npp, obj, propertyName);
}

bool NPN_HasMethod(NPP npp, NPObject* obj, NPIdentifier methodName)
{
  return CallNPN_HasMethodProc(gNetscapeFuncs.hasmethod, npp, obj, methodName);
}

void NPN_ReleaseVariantValue(NPVariant *variant)
{
  CallNPN_ReleaseVariantValueProc(gNetscapeFuncs.releasevariantvalue, variant);
}

void NPN_SetException(NPObject* obj, const NPUTF8 *message)
{
  CallNPN_SetExceptionProc(gNetscapeFuncs.setexception, obj, message);
}

NPIdentifier NPN_GetStringIdentifier(const NPUTF8 *name)
{
  return CallNPN_GetStringIdentifierProc(gNetscapeFuncs.getstringidentifier, name);
}



#pragma mark -

//::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
//
// Wrapper functions for all calls from Netscape to the plugin.
// These functions let the plugin developer just create the APIs
// as documented and defined in npapi.h, without needing to 
// install those functions in the function table or worry about
// setting up globals for 68K plugins.
//
//::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

NPError 	Private_Initialize(void);
void 		Private_Shutdown(void);
NPError		Private_New(NPMIMEType pluginType, NPP instance, uint16 mode, int16 argc, char* argn[], char* argv[], NPSavedData* saved);
NPError 	Private_Destroy(NPP instance, NPSavedData** save);
NPError		Private_SetWindow(NPP instance, NPWindow* window);
NPError		Private_NewStream(NPP instance, NPMIMEType type, NPStream* stream, NPBool seekable, uint16* stype);
NPError		Private_DestroyStream(NPP instance, NPStream* stream, NPError reason);
int32		Private_WriteReady(NPP instance, NPStream* stream);
int32		Private_Write(NPP instance, NPStream* stream, int32 offset, int32 len, void* buffer);
void		Private_StreamAsFile(NPP instance, NPStream* stream, const char* fname);
void		Private_Print(NPP instance, NPPrint* platformPrint);
int16 		Private_HandleEvent(NPP instance, void* event);
void        Private_URLNotify(NPP instance, const char* url, NPReason reason, void* notifyData);
jobject		Private_GetJavaClass(void);


NPError Private_Initialize(void)
{
	PLUGINDEBUGSTR("\pInitialize;g;");
	return NPP_Initialize();
}

void Private_Shutdown(void)
{
	PLUGINDEBUGSTR("\pShutdown;g;");
	NPP_Shutdown();
}


NPError	Private_New(NPMIMEType pluginType, NPP instance, uint16 mode, int16 argc, char* argn[], char* argv[], NPSavedData* saved)
{
	PLUGINDEBUGSTR("\pNew;g;");
	return NPP_New(pluginType, instance, mode, argc, argn, argv, saved);
}

NPError Private_Destroy(NPP instance, NPSavedData** save)
{
	PLUGINDEBUGSTR("\pDestroy;g;");
	return NPP_Destroy(instance, save);
}

NPError Private_SetWindow(NPP instance, NPWindow* window)
{
	PLUGINDEBUGSTR("\pSetWindow;g;");
	return NPP_SetWindow(instance, window);
}

NPError Private_NewStream(NPP instance, NPMIMEType type, NPStream* stream, NPBool seekable, uint16* stype)
{
	PLUGINDEBUGSTR("\pNewStream;g;");
	return NPP_NewStream(instance, type, stream, seekable, stype);
}

int32 Private_WriteReady(NPP instance, NPStream* stream)
{
	PLUGINDEBUGSTR("\pWriteReady;g;");
	return NPP_WriteReady(instance, stream);
}

int32 Private_Write(NPP instance, NPStream* stream, int32 offset, int32 len, void* buffer)
{
	PLUGINDEBUGSTR("\pWrite;g;");
	return NPP_Write(instance, stream, offset, len, buffer);
}

void Private_StreamAsFile(NPP instance, NPStream* stream, const char* fname)
{
	PLUGINDEBUGSTR("\pStreamAsFile;g;");
	NPP_StreamAsFile(instance, stream, fname);
}


NPError Private_DestroyStream(NPP instance, NPStream* stream, NPError reason)
{
	PLUGINDEBUGSTR("\pDestroyStream;g;");
	return NPP_DestroyStream(instance, stream, reason);
}

int16 Private_HandleEvent(NPP instance, void* event)
{
	PLUGINDEBUGSTR("\pHandleEvent;g;");
	return NPP_HandleEvent(instance, event);
}

void Private_Print(NPP instance, NPPrint* platformPrint)
{
	PLUGINDEBUGSTR("\pPrint;g;");
	NPP_Print(instance, platformPrint);
}

void Private_URLNotify(NPP instance, const char* url, NPReason reason, void* notifyData)
{
	PLUGINDEBUGSTR("\pURLNotify;g;");
	NPP_URLNotify(instance, url, reason, notifyData);
}


int main(NPNetscapeFuncs* nsTable, NPPluginFuncs* pluginFuncs, NPP_ShutdownUPP* unloadUpp);

DEFINE_API_C(int) main(NPNetscapeFuncs* nsTable, NPPluginFuncs* pluginFuncs, NPP_ShutdownUPP* unloadUpp)
{
	PLUGINDEBUGSTR("\pmain");

	NPError err = NPERR_NO_ERROR;
	
	//
	// Ensure that everything Netscape passed us is valid!
	//
	if ((nsTable == NULL) || (pluginFuncs == NULL) || (unloadUpp == NULL))
		err = NPERR_INVALID_FUNCTABLE_ERROR;
	
	//
	// Check the “major” version passed in Netscape’s function table.
	// We won’t load if the major version is newer than what we expect.
	// Also check that the function tables passed in are big enough for
	// all the functions we need (they could be bigger, if Netscape added
	// new APIs, but that’s OK with us -- we’ll just ignore them).
	//
	if (err == NPERR_NO_ERROR)
	{
		if ((nsTable->version >> 8) > NP_VERSION_MAJOR)		// Major version is in high byte
			err = NPERR_INCOMPATIBLE_VERSION_ERROR;
	}
		
	
	if (err == NPERR_NO_ERROR)
	{
		//
		// Copy all the fields of Netscape’s function table into our
		// copy so we can call back into Netscape later.  Note that
		// we need to copy the fields one by one, rather than assigning
		// the whole structure, because the Netscape function table
		// could actually be bigger than what we expect.
		//
		
		int navMinorVers = nsTable->version & 0xFF;

		gNetscapeFuncs.version          = nsTable->version;
		gNetscapeFuncs.size             = nsTable->size;
		gNetscapeFuncs.posturl          = (NPN_PostURLUPP)HOST_TO_PLUGIN_GLUE(posturl, nsTable->posturl);
		gNetscapeFuncs.geturl           = (NPN_GetURLUPP)HOST_TO_PLUGIN_GLUE(geturl, nsTable->geturl);
		gNetscapeFuncs.requestread      = (NPN_RequestReadUPP)HOST_TO_PLUGIN_GLUE(requestread, nsTable->requestread);
		gNetscapeFuncs.newstream        = (NPN_NewStreamUPP)HOST_TO_PLUGIN_GLUE(newstream, nsTable->newstream);
		gNetscapeFuncs.write            = (NPN_WriteUPP)HOST_TO_PLUGIN_GLUE(write, nsTable->write);
		gNetscapeFuncs.destroystream    = (NPN_DestroyStreamUPP)HOST_TO_PLUGIN_GLUE(destroystream, nsTable->destroystream);
		gNetscapeFuncs.status           = (NPN_StatusUPP)HOST_TO_PLUGIN_GLUE(status, nsTable->status);
		gNetscapeFuncs.uagent           = (NPN_UserAgentUPP)HOST_TO_PLUGIN_GLUE(uagent, nsTable->uagent);
		gNetscapeFuncs.memalloc         = (NPN_MemAllocUPP)HOST_TO_PLUGIN_GLUE(memalloc, nsTable->memalloc);
		gNetscapeFuncs.memfree          = (NPN_MemFreeUPP)HOST_TO_PLUGIN_GLUE(memfree, nsTable->memfree);
		gNetscapeFuncs.memflush         = (NPN_MemFlushUPP)HOST_TO_PLUGIN_GLUE(memflush, nsTable->memflush);
		gNetscapeFuncs.reloadplugins    = (NPN_ReloadPluginsUPP)HOST_TO_PLUGIN_GLUE(reloadplugins, nsTable->reloadplugins);
		if( navMinorVers >= NPVERS_HAS_LIVECONNECT )
		{
			gNetscapeFuncs.getJavaEnv   = (NPN_GetJavaEnvUPP)HOST_TO_PLUGIN_GLUE(getJavaEnv, nsTable->getJavaEnv);
			gNetscapeFuncs.getJavaPeer  = (NPN_GetJavaPeerUPP)HOST_TO_PLUGIN_GLUE(getJavaPeer, nsTable->getJavaPeer);
		}
		if( navMinorVers >= NPVERS_HAS_NOTIFICATION )
		{	
			gNetscapeFuncs.geturlnotify 	= (NPN_GetURLNotifyUPP)HOST_TO_PLUGIN_GLUE(geturlnotify, nsTable->geturlnotify);
			gNetscapeFuncs.posturlnotify 	= (NPN_PostURLNotifyUPP)HOST_TO_PLUGIN_GLUE(posturlnotify, nsTable->posturlnotify);
		}
		gNetscapeFuncs.getvalue         = (NPN_GetValueUPP)HOST_TO_PLUGIN_GLUE(getvalue, nsTable->getvalue);
		gNetscapeFuncs.setvalue         = (NPN_SetValueUPP)HOST_TO_PLUGIN_GLUE(setvalue, nsTable->setvalue);
		gNetscapeFuncs.invalidaterect   = (NPN_InvalidateRectUPP)HOST_TO_PLUGIN_GLUE(invalidaterect, nsTable->invalidaterect);
		gNetscapeFuncs.invalidateregion = (NPN_InvalidateRegionUPP)HOST_TO_PLUGIN_GLUE(invalidateregion, nsTable->invalidateregion);
		gNetscapeFuncs.forceredraw      = (NPN_ForceRedrawUPP)HOST_TO_PLUGIN_GLUE(forceredraw, nsTable->forceredraw);
      gNetscapeFuncs.getstringidentifier  = (NPN_GetStringIdentifierUPP)HOST_TO_PLUGIN_GLUE(getstringidentifier, nsTable->getstringidentifier);
      gNetscapeFuncs.getstringidentifiers = (NPN_GetStringIdentifiersUPP)HOST_TO_PLUGIN_GLUE(getstringidentifiers, nsTable->getstringidentifiers);
      gNetscapeFuncs.getintidentifier     = (NPN_GetIntIdentifierUPP)HOST_TO_PLUGIN_GLUE(getintidentifier, nsTable->getintidentifier);
      gNetscapeFuncs.identifierisstring   = (NPN_IdentifierIsStringUPP)HOST_TO_PLUGIN_GLUE(identifierisstring, nsTable->identifierisstring);
      gNetscapeFuncs.utf8fromidentifier   = (NPN_UTF8FromIdentifierUPP)HOST_TO_PLUGIN_GLUE(utf8fromidentifier, nsTable->utf8fromidentifier);
      gNetscapeFuncs.intfromidentifier    = (NPN_IntFromIdentifierUPP)HOST_TO_PLUGIN_GLUE(intfromidentifier, nsTable->intfromidentifier);
      gNetscapeFuncs.createobject = (NPN_CreateObjectUPP)HOST_TO_PLUGIN_GLUE(createobject, nsTable->createobject);
      gNetscapeFuncs.retainobject = (NPN_RetainObjectUPP)HOST_TO_PLUGIN_GLUE(retainobject, nsTable->retainobject);
      gNetscapeFuncs.releaseobject = (NPN_ReleaseObjectUPP)HOST_TO_PLUGIN_GLUE(releaseobject, nsTable->releaseobject);
      gNetscapeFuncs.invoke = (NPN_InvokeUPP)HOST_TO_PLUGIN_GLUE(invoke, nsTable->invoke);
      gNetscapeFuncs.invokeDefault = (NPN_InvokeDefaultUPP)HOST_TO_PLUGIN_GLUE(invokeDefault, nsTable->invokeDefault);
      gNetscapeFuncs.evaluate = (NPN_EvaluateUPP)HOST_TO_PLUGIN_GLUE(evaluate, nsTable->evaluate);
      gNetscapeFuncs.getproperty = (NPN_GetPropertyUPP)HOST_TO_PLUGIN_GLUE(getproperty, nsTable->getproperty);
      gNetscapeFuncs.setproperty = (NPN_SetPropertyUPP)HOST_TO_PLUGIN_GLUE(setproperty, nsTable->setproperty);
      gNetscapeFuncs.removeproperty = (NPN_RemovePropertyUPP)HOST_TO_PLUGIN_GLUE(removeproperty, nsTable->removeproperty);
      gNetscapeFuncs.hasproperty = (NPN_HasPropertyUPP)HOST_TO_PLUGIN_GLUE(hasproperty, nsTable->hasproperty);
      gNetscapeFuncs.hasmethod = (NPN_HasMethodUPP)HOST_TO_PLUGIN_GLUE(hasmethod, nsTable->hasmethod);
      gNetscapeFuncs.releasevariantvalue = (NPN_ReleaseVariantValueUPP)HOST_TO_PLUGIN_GLUE(releasevariantvalue, nsTable->releasevariantvalue);
      gNetscapeFuncs.setexception = (NPN_SetExceptionUPP)HOST_TO_PLUGIN_GLUE(setexception, nsTable->setexception);
      gNetscapeFuncs.pushpopupsenabledstate = (NPN_PushPopupsEnabledStateUPP)HOST_TO_PLUGIN_GLUE(pushpopupsenabledstate, nsTable->pushpopupsenabledstate);
      gNetscapeFuncs.poppopupsenabledstate = (NPN_PopPopupsEnabledStateUPP)HOST_TO_PLUGIN_GLUE(poppopupsenabledstate, nsTable->poppopupsenabledstate);
      gNetscapeFuncs.enumerate = (NPN_EnumerateUPP)HOST_TO_PLUGIN_GLUE(enumerate, nsTable->enumerate);
      gNetscapeFuncs.pluginthreadasynccall = (NPN_PluginThreadAsyncCallUPP)HOST_TO_PLUGIN_GLUE(pluginthreadasynccall, nsTable->pluginthreadasynccall);
      gNetscapeFuncs.construct = (NPN_ConstructUPP)HOST_TO_PLUGIN_GLUE(construct, nsTable->construct);
		
		//
		// Set up the plugin function table that Netscape will use to
		// call us.  Netscape needs to know about our version and size
		// and have a UniversalProcPointer for every function we implement.
		//
		pluginFuncs->version        = (NP_VERSION_MAJOR << 8) + NP_VERSION_MINOR;
		pluginFuncs->size           = sizeof(NPPluginFuncs);
		pluginFuncs->newp           = NewNPP_NewProc(PLUGIN_TO_HOST_GLUE(newp, Private_New));
		pluginFuncs->destroy        = NewNPP_DestroyProc(PLUGIN_TO_HOST_GLUE(destroy, Private_Destroy));
		pluginFuncs->setwindow      = NewNPP_SetWindowProc(PLUGIN_TO_HOST_GLUE(setwindow, Private_SetWindow));
		pluginFuncs->newstream      = NewNPP_NewStreamProc(PLUGIN_TO_HOST_GLUE(newstream, Private_NewStream));
		pluginFuncs->destroystream  = NewNPP_DestroyStreamProc(PLUGIN_TO_HOST_GLUE(destroystream, Private_DestroyStream));
		pluginFuncs->asfile         = NewNPP_StreamAsFileProc(PLUGIN_TO_HOST_GLUE(asfile, Private_StreamAsFile));
		pluginFuncs->writeready     = NewNPP_WriteReadyProc(PLUGIN_TO_HOST_GLUE(writeready, Private_WriteReady));
		pluginFuncs->write          = NewNPP_WriteProc(PLUGIN_TO_HOST_GLUE(write, Private_Write));
		pluginFuncs->print          = NewNPP_PrintProc(PLUGIN_TO_HOST_GLUE(print, Private_Print));
		pluginFuncs->event          = NewNPP_HandleEventProc(PLUGIN_TO_HOST_GLUE(event, Private_HandleEvent));	
		if( navMinorVers >= NPVERS_HAS_NOTIFICATION )
		{	
			pluginFuncs->urlnotify = NewNPP_URLNotifyProc(PLUGIN_TO_HOST_GLUE(urlnotify, Private_URLNotify));			
		}
      pluginFuncs->javaClass = NULL;
      pluginFuncs->getvalue       = NewNPP_GetValueProc(PLUGIN_TO_HOST_GLUE(getvalue, NPP_GetValue));
      pluginFuncs->setvalue       = NewNPP_SetValueProc(PLUGIN_TO_HOST_GLUE(setvalue, NPP_SetValue));
		*unloadUpp = NewNPP_ShutdownProc(PLUGIN_TO_HOST_GLUE(shutdown, Private_Shutdown));

		err = Private_Initialize();
	}
	
	return err;
}
