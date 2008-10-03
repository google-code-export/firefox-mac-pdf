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
const pdfUtility = {
  _initialized: false,

  init: function() {
    if (_initialized) {
      return;
    }
    
    _initialized = true;
  },

};
document.getElementById('content').sam = 'sam i am';
var sam = 'i am sam';
//this.sam = 'i am sam i am';
(function() {

// The XUL browser element (set in init())
var browser;
var cmdFind;
var cmdFindAgain;

function init() {
  browser = document.getElementById('content');
  cmdFind = document.getElementById('cmd_find');
  cmdFindAgain = document.getElementById('cmd_findAgain');

  // enable/disable find menu items correctly
  var proto = nsBrowserStatusHandler.prototype;
  // this needs to be set before the plugin is loaded
  proto.onStateChange = createStateChangeHandler(proto.onStateChange);
  
  // We have to use the load event since DOMContentLoaded isn't called for pages
  // handled by a plugin.
  //browser.addEventListener("load", onPageLoad, false);
}

var mimeTypes = {
 "application/pdf" : true,
 "text/pdf" : true
};

var lastBrowserDocument = null;
var lastBrowserPlugin = null;
/**
 * TODO: document me
 */
function getPluginElement() {
  // Check if the page contains the plugin instance
  var doc = browser.contentWindow.document;
  var html = doc.documentElement;
  if (!(html && html.tagName == 'HTML' && html.childNodes.length == 1)) {
    return null;
  }
  var body = html.firstChild;
  if (!(body && body.tagName == 'BODY' && body.childNodes.length == 1)) {
    return null;
  }
  var embed = body.firstChild;
  if (!(embed && embed.tagName == 'EMBED' && mimeTypes[embed.type])) {
    return null;
  }
  return embed;
}

/**
 * Wraps a nsITypeAheadFind object to route find queries to the plugin when appropriate
 */
function FastFindShim(fastfind) {
  this.fastfind = fastfind;
  for (let prop in fastfind) {
   if (fastfind.__lookupGetter__(prop)) {
     this.__defineGetter__(prop, createDelegateGetter(this.fastfind, prop));
   }
  }
}

/**
 * Delegates gets to underlying fastfind.
 */
function createDelegateGetter(fastfind, prop) {
  if (prop == 'searchString') {
    return function() {
      // TODO: improve condition based on last search type (PDF versus HTML)
      return getPluginElement() ? this.lastSearchString : fastfind[prop];
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
    var elem = getPluginElement();
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
      var findBar = document.getElementById('FindToolbar');
      if (findBar.getElement("highlight").checked) {
        plugin.findAll(str, this.fastfind.caseSensitive);
      }
      return ret;
    }
  }
  return this.fastfind[id].apply(this.fastfind, args);
}

// set when we wrap the fast find component
var swizzle = false;

/**
 * Called when a page's DOM structure is loaded.
 */
function onPageLoad(event) {
  var elem = getPluginElement();
  if (!elem) {
    // the loaded page isn't a elem page, so ignore it
    return;
  }
  // set the fast find shim
  if (!swizzle) {
    swizzle = true;
    browser._fastFind = new FastFindShim(browser._fastFind);
    // also 'swizzle' the close function on the find bar to cause the elem to regain focus
    var findBar = document.getElementById('FindToolbar');
    findBar.toggleHighlight = createFindbarToggleHighlight(findBar.toggleHighlight);
    findBar._setHighlightTimeout = createSetHighlightTimeout(findBar._setHighlightTimeout);
    // route zoom commands to the plugin
    FullZoom.reduce = createZoom(FullZoom.reduce, -1);
    FullZoom.reset = createZoom(FullZoom.reset, 0);
    FullZoom.enlarge = createZoom(FullZoom.enlarge, 1);
    goDoCommand = createGoDoCommand(goDoCommand);
  }
}

/**
 * Creates a function that calls toggleHighlight on the plugin.
 */
function createFindbarToggleHighlight(orig) {
  return function(shouldHighlight) {
    var elem = getPluginElement();
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
function createSetHighlightTimeout(orig) {
  return function() {
    if (!getPluginElement()) {
      orig.call(this);
    }
  };
}

function createZoom(orig, arg) {
  return function() {
    var elem = getPluginElement();
    if (elem) {
      elem.wrappedJSObject.zoom(arg);
    } else {
      orig.call(this);
    }
  }
}

function createStateChangeHandler(o) {
  return function(aWebProgress, aRequest, aStateFlags, aStatus) {
    // remove the attribute to force a change if disabled is set
    document.getElementById('isImage').removeAttribute('disabled');
    o.call(this, aWebProgress, aRequest, aStateFlags, aStatus);
    if (getPluginElement()) {
      cmdFind.removeAttribute('disabled');
      cmdFindAgain.removeAttribute('disabled');
    }
  }
}

function createGoDoCommand(orig) {
  return function(cmd) {
    var elem;
    if (cmd == 'cmd_copy' && (elem = getPluginElement())) {
      elem.wrappedJSObject.copy();
    } else {
      return orig.call(this, cmd);
    }
  }
}

addEventListener('load', init, false);

})();
