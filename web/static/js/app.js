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
import $ from "jquery"

//$(document).ready(function(){
// $("#msgid").html("This is Hello World by JQuery");
//});

// Import local files
//
// Local files can be imported directly using relative
// paths "./socket" or full ones "web/static/js/socket".

import socket from "./socketTorr"

window.toggle_displayBasedOn = function(idCondition, id) {
   var e = document.getElementById(id);
   var eCondition = document.getElementById(idCondition);
   if(eCondition.style.display == 'block') {
       e.style.display = 'none';
    } else {
       e.style.display = 'block';
    }
}
window.toggle_display = function(id) {
   var e = document.getElementById(id);
   if(e.style.display == 'block') {
      e.style.display = 'none';
   } else {
      e.style.display = 'block';
      deferImages(e);
   }
}

window.deferImages = function(container, imgUrl) {
  var imgDefer = container.getElementsByClassName('lazy');
  for (var i=0; i<imgDefer.length; i++) {
    if(imgDefer[i].getAttribute('data-src')) {
      imgDefer[i].setAttribute('src',imgDefer[i].getAttribute('data-src'));
    }
  }
}



window.openModal = function(idModal) {
  document.getElementById(idModal).style.display = "block";
}

window.closeModal = function(idModal) {
  document.getElementById(idModal).style.display = "none";
}

var slideIndex = 1;

window.plusSlides = function(idModal, n) {
  window.showSlides(idModal, slideIndex += n);
}

window.currentSlide = function(idModal, n) {
  window.showSlides(idModal, slideIndex = n);
}

window.showSlides = function(idModal, n) {
  var i;
  var idModalElem = document.getElementById(idModal);
  var slides = idModalElem.getElementsByClassName("mySlides");
  var dots = idModalElem.getElementsByClassName("lightbox");
  var captionText = document.getElementById("caption");
  if (n > slides.length) {slideIndex = 1}
  if (n < 1) {slideIndex = slides.length}
  for (i = 0; i < slides.length; i++) {
      slides[i].style.display = "none";
  }
  for (i = 0; i < dots.length; i++) {
      dots[i].className = dots[i].className.replace(" active", "");
  }
  slides[slideIndex-1].style.display = "block";
  dots[slideIndex-1].className += " active";
  captionText.innerHTML = dots[slideIndex-1].alt;
}