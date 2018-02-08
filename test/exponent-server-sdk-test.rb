require 'minitest/autorun'
require 'exponent-server-sdk'

class ExponentServerSdkTest < Minitest::Test
  def setup
    @mock = MiniTest::Mock.new
    @response_mock = MiniTest::Mock.new
    @exponent = Exponent::Push::Client.new(@mock)
  end

  def test_publish_with_success
    @response_mock.expect(:code, 200)
    @response_mock.expect(:body, success_body.to_json)

    @mock.expect(:post, @response_mock, client_args)

    @exponent.publish(messages)

    @mock.verify
  end

  def test_publish_with_error
    @response_mock.expect(:code, 400)
    @response_mock.expect(:body, error_body.to_json)

    @mock.expect(:post, @response_mock, client_args)

    assert_raises Exponent::Push::Error do
      @exponent.publish(messages)
    end

    @mock.verify
  end

  def test_publish_with_success_and_errors
    @response_mock.expect(:code, 200)
    @response_mock.expect(:body, success_with_error_body.to_json)

    @mock.expect(:post, @response_mock, client_args)

    assert_raises Exponent::Push::Error do
      @exponent.publish(messages)
    end

    @mock.verify
  end

  private

  def success_body
    { 'data' => [{ 'status' => 'ok' }] }
  end

  def error_body
    {
      'errors' => [{
        'code' => 'INTERNAL_SERVER_ERROR',
        'message' => 'An unknown error occurred.'
      }]
    }
  end

  def success_with_error_body
    {
      'data' => [{
        'status'  => 'error',
        'message' => '"ExponentPushToken[42]" is not a registered push notification recipient',
        'details' => { 'error' => 'DeviceNotRegistered' }
      }]
    }
  end

  def client_args
    [
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
  end

  def messages
    [{
      to: 'ExponentPushToken[xxxxxxxxxxxxxxxxxxxxxx]',
      sound: 'default',
      body: 'Hello world!'
    }, {
      to: 'ExponentPushToken[yyyyyyyyyyyyyyyyyyyyyy]',
      badge: 1,
      body: "You've got mail"
    }]
  end
end
