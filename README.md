# Exponent Server SDK Ruby
[![Build Status](https://travis-ci.org/expo/exponent-server-sdk-ruby.svg?branch=master)](https://travis-ci.org/expo/exponent-server-sdk-ruby)

Use to send push notifications to Exponent Experiences from a Ruby server.

If you have problems with the code in this repository, please file issues & bug reports at https://github.com/expo/expo. Thanks!

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

The push client is the preferred way.  This hits the latest version of the api.

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
