# frozen_string_literal: true

require 'exponent-server-sdk'

class Test
  def initialize
    # @client = Exponent::Push::Client.new

    # OR use GZIP to be AWESOME
    @client = Exponent::Push::Client.new(gzip: true)
  end

  def too_many_messages
    (0..101).map { create_message }
  end

  def create_message
    {
      # REPLACE WITH YOUR EXPONENT PUSH TOKEN LIKE:
      # to: 'ExponentPushToken[g5sIEbOm2yFdzn5VdSSy9n]',
      to: "ExponentPushToken[#{(0...22).map { ('a'..'z').to_a[rand(26)] }.join}]",
      sound: 'default',
      title: 'Hello World',
      subtitle: 'This is a Push Notification',
      body: 'Here\'s a little message for you...',
      data: {
        user_id: 1,
        points: 23_434
      },
      ttl: 10,
      expiration: 1_886_207_332,
      priority: 'default',
      badge: 0,
      channelId: 'game'
    }
  end

  def test
    # messages = too_many_messages
    messages = [create_message]

    response_handler = @client.send_messages(messages)
    puts response_handler.response.response_body
  end
end

Test.new.test
