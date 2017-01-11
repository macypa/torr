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
let torrentsContainer = document.querySelector("#torrents")

searchTerm.addEventListener("keypress", event => {
  if(event.keyCode === 13){
    var params = replaceUrlParams("search", searchTerm.value)
    channel.push("new_msg", params)
//    document.location.hash = searchTerm.value
    history.pushState(searchTerm.value, '', '/torrents' + params["locationUrl"]);
  }
})

export var Torrents = {
    show: function(payload) {
        torrentsContainer.innerHTML = '';
        torrentsContainer.insertAdjacentHTML( 'beforeend', `${payload.html}` );
    }
}

channel.on("new_msg", payload => {
    Torrents.show(payload);
})

channel.join()
  .receive("ok", resp => { console.log("Joined successfully", resp) })
  .receive("error", resp => { console.log("Unable to join", resp) })

export default socket

function replaceUrlParams(key, value) {
  var params = {};
  if (location.search) {
      var oldvalue = ""
      var parts = location.search.substring(1).split('&');
      for (var i = 0; i < parts.length; i++) {
          var nv = parts[i].split('=');
          if (!nv[0]) continue;
          if (nv[0] == key) {
            oldvalue = nv[1]
            params[key] = value || true;
          } else {
            params[nv[0]] = nv[1] || true;
          }
      }
      params["locationUrl"] = location.search.replace(key+"="+oldvalue, key+"="+value) || true;
  }
  return params
}
