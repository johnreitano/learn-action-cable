#!/usr/bin/env bash

brew install redis

brew services restart redis

rails new action-cable-demo-code --webpack --skip-sprockets

cd action-cable-demo-code

yarn add --force bootstrap jquery popper.js

sed -i'' "s/gem 'tzinfo-data'/# gem 'tzinfo-data'/" Gemfile
bundle add cable_ready
yarn add cable_ready
sed -i'' 's/adapter: async/adapter: redis\n  url: <%= ENV.fetch\("REDIS_URL"\) { "redis:\/\/localhost:6379\/1" } %>/' config/cable.yml
sed -i'' "s/# For details.*/root 'pages#home'/" config/routes.rb
rails g controller pages home --no-stylesheets

mkdir -p app/javascript/images app/javascript/scss app/javascript/js 
cat > app/javascript/images/index.js << DONE
const images = require.context('../images', true)
const imagePath = (name) => images(name, true)

DONE

mkdir -p app/javascript/scss
cat > app/javascript/scss/global.scss <<DONE
@import '~bootstrap/scss/bootstrap';

DONE

mkdir -p app/javascript/js
cat > app/javascript/js/index.js <<DONE
window.App || (window.App = {});
require("./channels")

DONE

cat > app/javascript/packs/application.js <<DONE
require("@rails/ujs").start()
require("turbolinks").start()
require("@rails/activestorage").start()

import 'bootstrap'
require("../images")
import '../scss/global.scss'
require("../js")

DONE

cat > config/webpack/environment.js <<DONE
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

rails g channel Room --force
# move app/javascript/channels to app/javascript/js/channels
mkdir -p app/javascript/channels app/javascript/js/channels
[ "$(ls -A app/javascript/channels/ 2> /dev/null)" ] && mv -f app/javascript/channels/* app/javascript/js/channels/ || echo "no channels to move"
rmdir app/javascript/channels

cat > app/javascript/js/channels/room_channel.js <<DONE
import consumer from "./consumer"

document.addEventListener('turbolinks:load', () => {
  console.log("room_channel.js has loaded...")

  let roomId = 1;
  window.App.subscription = consumer.subscriptions.create({ channel: "RoomChannel", room_id: roomId }, {
    connected() {
      console.log("connected to room ", roomId)
    },

    disconnected() {
      console.log("disconnected...")
    },

    received(data) {
      console.log("received data", data)
    }
  });
})

DONE

cat > app/channels/room_channel.rb <<DONE
class RoomChannel < ApplicationCable::Channel
  def subscribed
    puts "subscribed to room #{params[:room_id]}"
    stream_from "room_channel_#{params[:room_id]}"
  end

  def broadcastMessage(data)
    ActionCable.server.broadcast "room_channel_1", data
  end

  def unsubscribed
    puts "unsubscribed from room #{params[:room_id]}"
    # Any cleanup needed when channel is unsubscribed
  end
end

DONE

rails server -p 4000
