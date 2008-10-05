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
(function() {

var browser;
var cmdFind;
var cmdFindAgain;

var mimeTypes = {
 "application/pdf" : true,
 "text/pdf" : true
};

function init() {
  browser = document.getElementById('content');
  cmdFind = document.getElementById('cmd_find');
  cmdFindAgain = document.getElementById('cmd_findAgain');

  // enable/disable find menu items correctly
  var proto = nsBrowserStatusHandler.prototype;
  // this needs to be set before the plugin is loaded
  proto.onStateChange = createStateChangeHandler(proto.onStateChange);
}

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

addEventListener('load', init, false);

})();
