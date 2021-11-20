# Exponent Server SDK Ruby

[![Build Status](https://travis-ci.org/expo/expo-server-sdk-ruby.svg?branch=master)](https://travis-ci.org/expo/expo-server-sdk-ruby)
[![Gem Version](https://badge.fury.io/rb/exponent-server-sdk.svg)](https://badge.fury.io/rb/exponent-server-sdk)

Use to send push notifications to Exponent Experiences from a Ruby server.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'exponent-server-sdk'
```

And then execute:

```shell
$ bundle
```

Or install it yourself as:

```shell
$ gem install exponent-server-sdk
```

## Usage

### Client

The push client is the preferred way. This hits the latest version of the api.

Optional arguments: `gzip: true`

```ruby
client = Exponent::Push::Client.new
# client = Exponent::Push::Client.new(gzip: true)  # for compressed, faster requests

messages = [{
  to: "ExponentPushToken[xxxxxxxxxxxxxxxxxxxxxx]",
  sound: "default",
  body: "Hello world!"
}, {
  to: "ExponentPushToken[yyyyyyyyyyyyyyyyyyyyyy]",
  badge: 1,
  body: "You've got mail"
}]

# @Deprecated
# client.publish(messages)

# MAX 100 messages at a time
handler = client.send_messages(messages)

# Array of all errors returned from the API
# puts handler.errors

# you probably want to delay calling this because the service might take a few moments to send
# I would recommend reading the expo documentation regarding delivery delays
client.verify_deliveries(handler.receipt_ids)

```

See the getting started example. If you clone this repo, you can also use it to test locally by entering your ExponentPushToken. Otherwise it serves as a good copy pasta example to get you going.

The complete format of the messages can be found [here.](https://docs.expo.io/push-notifications/sending-notifications/#message-request-format)

## Contributing

If you have problems with the code in this repository, please file issues & bug reports. We encourage you
to submit a pull request with a solution or a failing test to reproduce your issue. Thanks!
