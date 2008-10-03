Components.utils.import("resource://gre/modules/XPCOMUtils.jsm");

function getChromeWindowForWindow(window) {
  var wm = Components.classes["@mozilla.org/appshell/window-mediator;1"].
      getService(Components.interfaces.nsIWindowMediator);
  var enumerator = wm.getEnumerator("navigator:browser");
  while(enumerator.hasMoreElements()) {
    var chromeWindow = enumerator.getNext();
    var tabBrowser = chromeWindow.gBrowser;
    if (tabBrowser.getBrowserForDocument(window.top.document) != null) {
      return chromeWindow;
    }
  }
  return null;
}

function getTabBrowserForWindow(window) {
  var chromeWindow = getChromeWindowForWindow(window);
  return chromeWindow && chromeWindow.gBrowser;
}
function getPluginElement(chromeWindow) {
  for (var i = 0; i < plugins.length; i++) {
    if (plugins[i].window == chromeWindow.gBrowser.contentWindow) {
      return plugins[i].plugin;
    }
  }
  return null;
}

function log(string) {
  var console = Components.classes["@mozilla.org/consoleservice;1"].
      getService(Components.interfaces.nsIConsoleService);
  console.logStringMessage(string);
}

function logInternals(obj) {
  var str = '';
  for (var a in obj) {
   str += a +', ';
  }
  log(str);
}

var plugins = [];

function PDFService() {
};

PDFService.prototype = {
  classDescription: "Firefox PDF Plugin Service",
  classID: Components.ID("{862827b0-98ac-4b68-a0c9-4ccd8ff35a02}"),
  contractID: "@sgross.mit.edu/pdfservice;1",
  QueryInterface: XPCOMUtils.generateQI([Components.interfaces.PDFService]),
  
  AdvanceTab: function(window, offset) {
    var browser = getTabBrowserForWindow(window);
    browser.mTabContainer.advanceSelectedTab(offset, true);
  },
  
  GoHistory: function(window, dir) {
    var browser = getTabBrowserForWindow(window);
    if (dir == -1) {
      browser.goBack();
    } else {
      browser.goForward();
    }
  },
  
  Init: function(window, plugin) {
    plugins.push({window:window, plugin:plugin});
    var chromeWindow = getChromeWindowForWindow(window);
    if (!chromeWindow.edu_mit_sgross_pdfplugin_swizzled) {
      var browser = chromeWindow.gBrowser;
      browser._fastFind = new FastFindShim(chromeWindow, browser._fastFind);

      // also 'swizzle' the close function on the find bar to cause the elem to regain focus
      var findBar = chromeWindow.gFindBar;
      findBar.toggleHighlight = createFindbarToggleHighlight(chromeWindow, findBar.toggleHighlight);
      findBar._setHighlightTimeout = createSetHighlightTimeout(chromeWindow, findBar._setHighlightTimeout);
      
      // route zoom commands to the plugin
      var FullZoom = chromeWindow.FullZoom;
      FullZoom.reduce = createZoom(chromeWindow, FullZoom.reduce, -1);
      FullZoom.reset = createZoom(chromeWindow, FullZoom.reset, 0);
      FullZoom.enlarge = createZoom(chromeWindow, FullZoom.enlarge, 1);
      
      chromeWindow.goDoCommand = createGoDoCommand(chromeWindow, chromeWindow.goDoCommand);

      chromeWindow.edu_mit_sgross_pdfplugin_swizzled = true;
    }
  },
  
  CleanUp: function(plugin) {
    for (var i = 0; i < plugins.length; i++) {
      var pair = plugins[i];
      if (pair.plugin == plugin) {
        plugins = plugins.slice(0, i).concat(plugins.slice(i+1, plugins.length));
        return;
      }
    }
  },
  
  Save: function(window, url) {
    var chromeWindow = getChromeWindowForWindow(window);
    chromeWindow.saveURL(url,  null, null, true);
  },
  
  InspectWindow: function(window) {
    var console = Components.classes["@mozilla.org/consoleservice;1"].getService(Components.interfaces.nsIConsoleService);
    var browser = getTabBrowserForWindow(window);
    console.logStringMessage('equal: ' + (window == browser.contentWindow));
    logInternals(getChromeWindowForWindow(window));
    logInternals(browser);
    logInternals(browser.getBrowserForDocument(window.document));
    /*var wm = Components.classes["@mozilla.org/appshell/window-mediator;1"].getService(Components.interfaces.nsIWindowMediator);
    var enumerator = wm.getEnumerator('navigator:browser');
    while(enumerator.hasMoreElements()) {
      var win = enumerator.getNext(), str;
      console.logStringMessage('sam: ' + win.sam + ';' + win.gBrowser.sam);
      console.logStringMessage('browser for doc: ' + win.gBrowser.getBrowserForDocument(window.document));
      console.logStringMessage('new window:' + win + ' ' + win.gBrowser);
      str = '';
      for (var a in win) {
       str += a +', ';
      }
      console.logStringMessage(str);
      win = window;
      console.logStringMessage('new window:' + win + ' ' + win.gBrowser);
      str = '';
      for (var a in win) {
       str += a +', ';
      }
      console.logStringMessage(str);
      win = win.wrappedJSObject;
      console.logStringMessage('new window:' + win + ' ' + win.gBrowser);
      str = '';
      for (var a in win) {
       str += a +', ';
      }
      console.logStringMessage(str);
      win = win.top;
      console.logStringMessage('new window:' + win + ' ' + win.gBrowser);
      str = '';
      for (var a in win) {
       str += a +', ';
      }
      console.logStringMessage(str);
    }*/
  }
}

/**
 * Wraps a nsITypeAheadFind object to route find queries to the plugin when appropriate
 */
function FastFindShim(chromeWindow, fastfind) {
  this.fastfind = fastfind;
  this.chromeWindow = chromeWindow;
  log('new fastfindshim chromeWindow: ' + this.chromeWindow);
  for (let prop in fastfind) {
   if (fastfind.__lookupGetter__(prop)) {
     this.__defineGetter__(prop, createDelegateGetter(chromeWindow, this.fastfind, prop));
   }
  }
}

/**
 * Delegates gets to underlying fastfind.
 */
function createDelegateGetter(chromeWindow, fastfind, prop) {
  if (prop == 'searchString') {
    return function() {
      // TODO: improve condition based on last search type (PDF versus HTML)
      return getPluginElement(chromeWindow) ? this.lastSearchString : fastfind[prop];
    }
  }
  return function() {
    return fastfind[prop];
  }
}

/**
 * Delegate all other methods to wrapped fastfind object.
 */
FastFindShim.prototype.__noSuchMethod__ = function(id, args) {
  if (id == 'find' || id == 'findAgain') {
    log("FastfindShim." + id + " chromeWindow: " + this.chromeWindow);
    var elem = getPluginElement(this.chromeWindow);
    if (elem) {
      var str, reverse;
      if (id == 'find') {
        str = args[0];
        reverse = false;
      } else { // findAgain
        str = this.lastSearchString;
        reverse = args[0];
      }
      this.lastSearchString = str;
      // unwrap the plugin; see http://developer.mozilla.org/en/docs/XPCNativeWrapper
      var plugin = elem.wrappedJSObject;
      // find must take place before findAll because find cancels any current searches
      var ret = plugin.find(str, this.fastfind.caseSensitive, !reverse);
      var findBar = this.chromeWindow.gFindBar;
      if (findBar.getElement("highlight").checked) {
        plugin.findAll(str, this.fastfind.caseSensitive);
      }
      return ret;
    }
  }
  return this.fastfind[id].apply(this.fastfind, args);
}

/**
 * Creates a function that calls toggleHighlight on the plugin.
 */
function createFindbarToggleHighlight(chromeWindow, orig) {
  return function(shouldHighlight) {
    var elem = getPluginElement(chromeWindow);
    if (elem) {
      var plugin = elem.wrappedJSObject;
      if (shouldHighlight) {
        var word = this._findField.value;
        // TODO: better choice for determining case sensitivity?
        var caseSensitive = this._shouldBeCaseSensitive(word);
        plugin.findAll(word, caseSensitive);
      } else {
        plugin.removeHighlights();
      }
    } else {
      orig.call(this, shouldHighlight);
    }
  };
}

/**
 * Creates a function that only sets the highlight timeout when 
 * the plugin is not present.
 */
function createSetHighlightTimeout(chromeWindow, orig) {
  return function() {
    if (!getPluginElement(chromeWindow)) {
      orig.call(this);
    }
  };
}

function createZoom(chromeWindow, orig, arg) {
  return function() {
    var elem = getPluginElement(chromeWindow);
    if (elem) {
      elem.wrappedJSObject.zoom(arg);
    } else {
      orig.call(this);
    }
  }
}

function createGoDoCommand(chromeWindow, orig) {
  return function(cmd) {
    var elem;
    if (cmd == 'cmd_copy' && (elem = getPluginElement(chromeWindow))) {
      elem.wrappedJSObject.copy();
    } else {
      return orig.call(this, cmd);
    }
  }
}

var components = [PDFService];
function NSGetModule(compMgr, fileSpec) {
  return XPCOMUtils.generateModule(components);
}