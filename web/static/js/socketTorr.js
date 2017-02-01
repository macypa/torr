// NOTE: The contents of this file will only be executed if
// you uncomment its entry in "web/static/js/app.js".

// To use Phoenix channels, the first step is to import Socket
// and connect at the socket path in "lib/my_app/endpoint.ex":
import {Socket} from "phoenix"

let socket = new Socket("/socketTorr", {params: {token: window.userToken}})

// When you connect, you'll often need to authenticate the client.
// For example, imagine you have an authentication plug, `MyAuth`,
// which authenticates the session and assigns a `:current_user`.
// If the current user exists you can assign the user's token in
// the connection for use in the layout.
//
// In your "web/router.ex":
//
//     pipeline :browser do
//       ...
//       plug MyAuth
//       plug :put_user_token
//     end
//
//     defp put_user_token(conn, _) do
//       if current_user = conn.assigns[:current_user] do
//         token = Phoenix.Token.sign(conn, "user socket", current_user.id)
//         assign(conn, :user_token, token)
//       else
//         conn
//       end
//     end
//
// Now you need to pass this token to JavaScript. You can do so
// inside a script tag in "web/templates/layout/app.html.eex":
//
//     <script>window.userToken = "<%= assigns[:user_token] %>";</script>
//
// You will need to verify the user token in the "connect/2" function
// in "web/channels/user_socket.ex":
//
//     def connect(%{"token" => token}, socket) do
//       # max_age: 1209600 is equivalent to two weeks in seconds
//       case Phoenix.Token.verify(socket, "user socket", token, max_age: 1209600) do
//         {:ok, user_id} ->
//           {:ok, assign(socket, :user, user_id)}
//         {:error, reason} ->
//           :error
//       end
//     end
//
// Finally, pass the token on connect as below. Or remove it
// from connect if you don't care about authentication.
socket.connect()

// Now that you are connected, you can join channels with a topic:
let channel = socket.channel("torrent:"+window.userToken, {})

let searchTerm         = document.querySelector("#searchTerm")
let pageSize           = document.querySelector("#page_size")
let imgSize           = document.querySelector("#img_size")
let catalogMode           = document.querySelector("#catalogMode")
let torrentsContainer  = document.querySelector("#torrents")

addEvent(document.querySelector("#searchTerm"), "keyup", keyEventDelay );
addEvent(document.querySelector("#page_size"), "keyup", keyEventDelay );

addEvent(document.querySelector("#searchDescription"), "click", clickEvent );
addEvent(document.querySelector("#catalogMode"), "click", clickEvent );
addEvent(document.querySelector("#sort_name"), "click", sortEvent );
addEvent(document.querySelector("#sort_type"), "click", sortEvent );
addEvent(document.querySelector("#sort_genre"), "click", sortEvent );
addEvent(document.querySelector("#sort_added"), "click", sortEvent );
addEvent(document.querySelector("#sort_size"), "click", sortEvent );

function addEvent(element, eventName, callback) {
    if (element.addEventListener) {
        element.addEventListener(eventName, callback, false);
    } else if (element.attachEvent) {
        element.attachEvent("on" + eventName, callback);
    }
}

function keyEvent(event) {
  sendRequest(getParams())
}

function sortEvent(event) {
  var params = getParams()
  updateParams(params, "sort", event.target.id.replace(/sort_/i, "") + "_asc")
  sendRequest(params)
}

function clickEvent(event) {
  var params = getParams()
  updateParams(params, event.target.id, "on")
  sendRequest(params)
}

function getParams() {
  var params = getUrlParams({})
  params["search"] = searchTerm.value
  params["page_size"] = pageSize.value
  params["img_size"] = imgSize.value
  params["page"] = 1
  return params
}

function sendRequest(params) {
  channel.push("new_msg", params)
//    document.location.hash = searchTerm.value
  history.pushState(searchTerm.value, '', '/torrents?' + composeUrlParams(params));
}

var timeout = null;
function keyEventDelay(event) {
  if(event.keyCode === 13){
    keyEvent(event);
  } else {
    var that = this;
    if (timeout != null) {
        clearTimeout(timeout);
    }
    timeout = setTimeout(function () {
        keyEvent(event);
    }, 300);
  }
}


window.onload = function() {
  updatePaginationUrls(composeUrlParams(getUrlParams({})));
}
export var Torrents = {
    show: function(payload) {
        torrentsContainer.innerHTML = '';
        torrentsContainer.insertAdjacentHTML( 'beforeend', `${payload.html}` );

        updatePaginationUrls(composeUrlParams(getUrlParams(payload)));
    }
}

channel.on("new_msg", payload => {
    Torrents.show(payload);
})

channel.join()
  .receive("ok", resp => { console.log("Joined successfully", resp) })
  .receive("error", resp => { console.log("Unable to join", resp) })

export default socket


function getUrlParams(payload) {
  var params = {};
  var locatUrl = location.search

  if (locatUrl) {
    var parts = location.search.substring(1).split('&');
    for (var i = 0; i < parts.length; i++) {
      var nv = parts[i].split('=');
      if (!nv[0]) continue;
      params[nv[0]] = nv[1];
    }
  }
  return params
}

function updateParams(params, key, value) {
  var urlParams = ""

  if (params.hasOwnProperty(key)) {
    if (params[key].includes(value)) {
      var reg = new RegExp(',*'+value, 'i')
      params[key] = params[key].replace(reg, "")
    } else {
      params[key] = params[key] + "," + value
    }
    params[key] = params[key].replace(/^,/i, "")
  } else {
    params[key] = value;
  }
  return params
}

function composeUrlParams(params) {
  var urlParams = ""
  for (var key in params) {
    if (params.hasOwnProperty(key)) {
      if (params[key] != "") {
        urlParams = urlParams + "&" + key + "=" + params[key];
      }
    }
  }
  return urlParams.substring(1)
}

function updatePaginationUrls(urlParams) {
  var anchors = document.getElementsByTagName("a");
  var urlParamsWoutPage = urlParams.replace(/(&|^)page=\d*/i, "").replace(/^&/i, "")

  if (urlParamsWoutPage == "") {
    return
  }
  for (var i = 0; i < anchors.length; i++) {
      if (anchors[i].href.includes("page=")) {
          anchors[i].href = anchors[i].href.replace("page=", urlParamsWoutPage + "&page=")
      }
  }
}

$(function() {

  $('input[type="checkbox"]').change(checkboxChanged);

  function checkboxChanged() {
    var $this = $(this),
        checked = $this.prop("checked"),
        container = $this.parent(),
        siblings = container.siblings();

    container.find('input[type="checkbox"]')
    .prop({
        indeterminate: false,
        checked: checked
    })
    .siblings('label')
    .removeClass('custom-checked custom-unchecked custom-indeterminate')
    .addClass(checked ? 'custom-checked' : 'custom-unchecked');


//    if (checked) {
      var label = $this.siblings('label')[0]
      var params = updateParams(getUrlParams({}), label.getAttribute("name"), label.getAttribute("filterId"))
      sendRequest(params)
//    }

    checkSiblings(container, checked);
  }

  function checkSiblings($el, checked) {
    var parent = $el.parent().parent(),
        all = true,
        indeterminate = false;

    $el.siblings().each(function() {
      return all = ($(this).children('input[type="checkbox"]').prop("checked") === checked);
    });

    if (all && checked) {
      parent.children('input[type="checkbox"]')
      .prop({
          indeterminate: false,
          checked: checked
      })
      .siblings('label')
      .removeClass('custom-checked custom-unchecked custom-indeterminate')
      .addClass(checked ? 'custom-checked' : 'custom-unchecked');

      checkSiblings(parent, checked);
    }
    else if (all && !checked) {
      indeterminate = parent.find('input[type="checkbox"]:checked').length > 0;

      parent.children('input[type="checkbox"]')
      .prop("checked", checked)
      .prop("indeterminate", indeterminate)
      .siblings('label')
      .removeClass('custom-checked custom-unchecked custom-indeterminate')
      .addClass(indeterminate ? 'custom-indeterminate' : (checked ? 'custom-checked' : 'custom-unchecked'));

      checkSiblings(parent, checked);
    }
    else {
      $el.parents("li").children('input[type="checkbox"]')
      .prop({
          indeterminate: true,
          checked: false
      })
      .siblings('label')
      .removeClass('custom-checked custom-unchecked custom-indeterminate')
      .addClass('custom-indeterminate');
    }
  }
});
