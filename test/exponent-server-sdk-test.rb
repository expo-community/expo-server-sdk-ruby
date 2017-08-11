require 'minitest/autorun'
require 'exponent-server-sdk'

class ExponentServerSdkTest < Minitest::Test
  def test_publish
    mock = MiniTest::Mock.new
    response_mock = MiniTest::Mock.new
    exponent = Exponent::Push::Client.new mock

    response_mock.expect(:code, 200)

    messages = [{
      to: "ExponentPushToken[xxxxxxxxxxxxxxxxxxxxxx]",
      sound: "default",
      body: "Hello world!"
    }, {
      to: "ExponentPushToken[yyyyyyyyyyyyyyyyyyyyyy]",
      badge: 1,
      body: "You've got mail"
    }]

    args = [
      'https://exp.host/--/api/v2/push/send',
      {
        body: messages.to_json,
        headers: {
          'Content-Type' => 'application/json',
          'Accept' => 'application/json',
          'Accept-Encoding' => 'gzip, deflate'
        }
      }
    ]
    mock.expect(:post, response_mock, args)

    messages = [{
      to: "ExponentPushToken[xxxxxxxxxxxxxxxxxxxxxx]",
      sound: "default",
      body: "Hello world!"
    }, {
      to: "ExponentPushToken[yyyyyyyyyyyyyyyyyyyyyy]",
      badge: 1,
      body: "You've got mail"
    }]

    exponent.publish(messages)

    mock.verify
  end

  def test_publish_with_error
    mock = MiniTest::Mock.new
    response_mock = MiniTest::Mock.new
    exponent = Exponent::Push::Client.new mock

    response_mock.expect(:code, 400)

    messages = [{
      to: "ExponentPushToken[xxxxxxxxxxxxxxxxxxxxxx]",
      sound: "default",
      body: "Hello world!"
    }, {
      to: "ExponentPushToken[yyyyyyyyyyyyyyyyyyyyyy]",
      badge: 1,
      body: "You've got mail"
    }]

    args = [
      'https://exp.host/--/api/v2/push/send',
      {
        body: messages.to_json,
        headers: {
          'Content-Type' => 'application/json',
          'Accept' => 'application/json',
          'Accept-Encoding' => 'gzip, deflate'
        }
      }
    ]
    mock.expect(:post, response_mock, args)

    messages = [{
      to: "ExponentPushToken[xxxxxxxxxxxxxxxxxxxxxx]",
      sound: "default",
      body: "Hello world!"
    }, {
      to: "ExponentPushToken[yyyyyyyyyyyyyyyyyyyyyy]",
      badge: 1,
      body: "You've got mail"
    }]

    assert_raises Exponent::Push::Errors::InvalidPushTokenError do 
      exponent.publish(messages)
    end

    mock.verify
  end
end
