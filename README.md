# Exponent Server SDK Ruby
[![Build Status](https://travis-ci.org/expo/exponent-server-sdk-ruby.svg?branch=master)](https://travis-ci.org/expo/exponent-server-sdk-ruby)

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

### Legacy

There is a legacy client that uses version 1 of the api.  It's simpler but has limitations like only allowing you to publish messages to a single user per call.

```ruby
exponent = Exponent::Push::LegacyClient.new

exponent.publish(
  exponentPushToken: token,
  message: message,
  data: {a: 'b'}, # Any arbitrary data to include with the notification
)
```

### Current

The new client is the preferred way.  This hits the latest version of the api.

```ruby
exponent = Exponent::Push::Client.new

messages = [{
  to: "ExponentPushToken[xxxxxxxxxxxxxxxxxxxxxx]",
  sound: "default",
  body: "Hello world!"
}, {
  to: "ExponentPushToken[yyyyyyyyyyyyyyyyyyyyyy]",
  badge: 1,
  body: "You've got mail"
}]

exponent.publish messages
```

The complete format of the messages can be found [here.](https://docs.expo.io/versions/v16.0.0/guides/push-notifications.html#http2-api)
