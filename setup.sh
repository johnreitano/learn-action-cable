#!/usr/bin/env bash

brew install redis

brew services restart redis

rails new action-cable-demo-code --webpack --skip-sprockets

cd action-cable-demo-code
bundle remove tzinfo-data
bundle add redis bootstrap
sed -i'' "s/stylesheet_link_tag/stylesheet_pack_tag/" app/views/layouts/application.html.erb

yarn add bootstrap jquery popper.js

sed -i'' 's/adapter: async/adapter: redis\n  url: <%= ENV.fetch\("REDIS_URL"\) { "redis:\/\/localhost:6379\/1" } %>/' config/cable.yml
rails g controller pages home --no-stylesheets
sed -i'' "s/# For details.*/root 'pages#home'/" config/routes.rb

# generate channel and move it to app/javascript/js/channels/
rails g channel Room --force
mkdir -p app/javascript/channels app/javascript/js/channels
[ "$(ls -A app/javascript/channels/ 2> /dev/null)" ] && mv -f app/javascript/channels/* app/javascript/js/channels/ || echo "no channels to move"
rmdir app/javascript/channels

mkdir -p app/javascript/images
cat > app/javascript/images/index.js << DONE
const images = require.context('../images', true)
const imagePath = (name) => images(name, true)

DONE

mkdir -p app/javascript/scss
cat > app/javascript/scss/global.scss <<"DONE"
@import '~bootstrap/scss/bootstrap';

DONE

mkdir -p app/javascript/js
cat > app/javascript/js/index.js <<"DONE"
window.App || (window.App = {});
require("./channels")

DONE

cat > app/javascript/packs/application.js <<"DONE"
require("@rails/ujs").start()
require("turbolinks").start()
require("@rails/activestorage").start()

import 'bootstrap'
require("../images")
import '../scss/global.scss'
require("../js")

DONE

cat > config/webpack/environment.js <<"DONE"
const { environment } = require('@rails/webpacker')
const webpack = require('webpack')

environment.plugins.append('Provide',
    new webpack.ProvidePlugin({
        $: 'jquery',
        jQuery: 'jquery',
        Popper: ['popper.js', 'default']
    })
)
module.exports = environment

DONE

cat > app/javascript/js/channels/room_channel.js <<"DONE"
import consumer from "./consumer"

document.addEventListener('turbolinks:load', () => {
  consumer.subscriptions.create({ channel: "RoomChannel" }, {
    connected() {
      console.log("connected to chat channel")
      this.senderId = Math.floor(Math.random() * Date.now())
      let subscription = this
      $("#message-btn").on("click", function (event) {
        event.preventDefault();
        subscription.perform('broadcastMessage', {
          content: $('#message-box').val(),
          senderId: subscription.senderId
        })
        console.log('client sent message to server')
        $('#message-box').val('')
      });
    },

    disconnected() {
      console.log("disconnected...")
    },

    received(message) {
      console.log("client received message from server", message)
      let label = message.senderId == this.senderId ? 'Me' : 'Them'
      $("#messages-container").append("<div>" + label + ': ' + message.content + "</div>")
    }

  });
})

DONE

cat > app/channels/room_channel.rb <<"DONE"
class RoomChannel < ApplicationCable::Channel
  def subscribed
    puts "subscribed to room"
    stream_from "room_channel"
  end

  def broadcastMessage(message)
    ActionCable.server.broadcast "room_channel", message
  end

  def unsubscribed
    puts "unsubscribed from room"
    # Any cleanup needed when channel is unsubscribed
  end
end

DONE

cat > app/views/pages/home.html.erb <<"DONE"
<h1>My Message App</h1>

<%= form_with(url: '#', local: true) do |form| %>
 <div class="input-group">
    <%= form.text_field :content, placeholder: 'Type your message here...', class: 'form-control', id: 'message-box' %>
    <div class="input-group-append">
      <%= form.submit 'Add Message', class: 'btn btn-primary', id: 'message-btn' %>
    </div>
  </div>
<% end %>

<br>
<br>
<div id="messages-container">

DONE

rails server -p 4000
