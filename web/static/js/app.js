// Brunch automatically concatenates all files in your
// watched paths. Those paths can be configured at
// config.paths.watched in "brunch-config.js".
//
// However, those files will only be executed if
// explicitly imported. The only exception are files
// in vendor, which are never wrapped in imports and
// therefore are always executed.

// Import dependencies
//
// If you no longer want to use a dependency, remember
// to also remove its path from "config.paths.watched".
import "phoenix_html"

// Import local files
//
// Local files can be imported directly using relative
// paths "./socket" or full ones "web/static/js/socket".

import socket from "./socketTorr"

window.toggle_visibility = function(id) {
   var e = document.getElementById(id);
   if(e.style.display == 'block')
      e.style.display = 'none';
   else {
      e.style.display = 'block';
      deferImages(e);
   }
}

window.deferImages = function(container, imgUrl) {
  var imgDefer = container.getElementsByClassName('lazy');
  for (var i=0; i<imgDefer.length; i++) {
    if(imgDefer[i].getAttribute('data-src')) {
//      imgDefer[i].setAttribute('src',imgDefer[i].getAttribute('data-src'));
      preloadImg(imgDefer[i])
    }
  }
}

window.preloadImg = function(imgElem) {
	setTimeout(function() {
		// XHR to request a JS and a CSS
		var xhr = new XMLHttpRequest();
		xhr.onreadystatechange = function() {
        if (xhr.readyState == XMLHttpRequest.DONE) {
            imgElem.setAttribute('src', imgElem.getAttribute('data-src'));
        }
    }
//		xhr.responseType = "blob";
		xhr.open('GET', imgElem.getAttribute('data-src'));
    xhr.setRequestHeader("Referer", "http://zamunda.net/");
		xhr.send('');
		// preload image
		new Image().src = imgElem.getAttribute('data-src');
	}, 1000);
};