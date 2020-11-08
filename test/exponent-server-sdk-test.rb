# frozen_string_literal: true

require 'minitest/autorun'
require 'exponent-server-sdk'
require 'exponent-server-sdk/too_many_messages_error'

class ExponentServerSdkTest < Minitest::Test
  def setup
    @mock          = MiniTest::Mock.new
    @response_mock = MiniTest::Mock.new
    @client        = Exponent::Push::Client.new(http_client: @mock)
    @client_gzip   = Exponent::Push::Client.new(http_client: @mock, gzip: true)
  end

  def test_send_messages_with_success
    @response_mock.expect(:code, 200)
    @response_mock.expect(:body, success_body.to_json)

    @mock.expect(:post, @response_mock, client_args)

    response = @client.send_messages(messages)
    assert_equal(response.errors?, false)

    @mock.verify
  end

  def test_send_messages_alternate_message_format_with_success
    @response_mock.expect(:code, 200)
    @response_mock.expect(:body, success_body.to_json)

    alternate_messages = alternate_format_messages
    @mock.expect(:post, @response_mock, alternative_client_args(alternate_messages))

    response = @client.send_messages(alternate_messages)
    assert_equal(response.errors?, false)

    @mock.verify
  end

  def test_send_messages_with_gzip_success
    @response_mock.expect(:code, 200)
    @response_mock.expect(:body, success_body.to_json)

    @mock.expect(:post, @response_mock, gzip_client_args)

    response = @client_gzip.send_messages(messages)
    assert_equal(response.errors?, false)

    @mock.verify
  end

  def test_send_messages_with_empty_string_response_body
    @response_mock.expect(:code, 400)
    @response_mock.expect(:body, '')

    @mock.expect(:post, @response_mock, client_args)

    exception = assert_raises Exponent::Push::UnknownError do
      handler = @client.send_messages(messages)
      # this first assertion is just stating that errors will be false when
      # an exception is thrown on the request, not the content of the request
      # 400/500 level errors are not delivery errors, they are functionality errors
      assert_equal(handler.response.errors?, false)
      assert_equal(handler.response.body, {})
      assert_equal(handler.response.code, 400)
    end

    assert_match(/Unknown error format/, exception.message)

    @mock.verify
  end

  def test_send_messages_with_nil_response_body
    @response_mock.expect(:code, 400)
    @response_mock.expect(:body, nil)

    @mock.expect(:post, @response_mock, client_args)

    exception = assert_raises Exponent::Push::UnknownError do
      handler = @client.send_messages(messages)
      # this first assertion is just stating that errors will be false when
      # an exception is thrown on the request, not the content of the request
      # 400/500 level errors are not delivery errors, they are functionality errors
      assert_equal(handler.response.errors?, false)
      assert_equal(handler.response.body, {})
      assert_equal(handler.response.code, 400)
    end

    assert_match(/Unknown error format/, exception.message)

    @mock.verify
  end

  def test_send_messages_with_gzip_empty_string_response
    @response_mock.expect(:code, 400)
    @response_mock.expect(:body, '')

    @mock.expect(:post, @response_mock, gzip_client_args)

    exception = assert_raises Exponent::Push::UnknownError do
      handler = @client_gzip.send_messages(messages)
      # this first assertion is just stating that errors will be false when
      # an exception is thrown on the request, not the content of the request
      # 400/500 level errors are not delivery errors, they are functionality errors
      assert_equal(handler.response.errors?, false)
      assert_equal(handler.response.body, {})
      assert_equal(handler.response.code, 400)
    end

    assert_match(/Unknown error format/, exception.message)

    @mock.verify
  end

  def test_send_messages_with_gzip_nil_response_body
    @response_mock.expect(:code, 400)
    @response_mock.expect(:body, nil)

    @mock.expect(:post, @response_mock, gzip_client_args)

    exception = assert_raises Exponent::Push::UnknownError do
      handler = @client_gzip.send_messages(messages)
      # this first assertion is just stating that errors will be false when
      # an exception is thrown on the request, not the content of the request
      # 400/500 level errors are not delivery errors, they are functionality errors
      assert_equal(handler.response.errors?, false)
      assert_equal(handler.response.body, {})
      assert_equal(handler.response.code, 400)
    end

    assert_match(/Unknown error format/, exception.message)

    @mock.verify
  end

  def test_send_messages_with_unknown_error
    @response_mock.expect(:code, 400)
    @response_mock.expect(:body, error_body.to_json)

    @mock.expect(:post, @response_mock, client_args)

    exception = assert_raises Exponent::Push::UnknownError do
      @client.send_messages(messages)
    end

    assert_equal("Unknown error format: #{error_body.to_json}", exception.message)

    @mock.verify
  end

  def test_send_messages_with_gzip_unknown_error
    @response_mock.expect(:code, 400)
    @response_mock.expect(:body, error_body.to_json)

    @mock.expect(:post, @response_mock, gzip_client_args)

    exception = assert_raises Exponent::Push::UnknownError do
      @client_gzip.send_messages(messages)
    end

    assert_match(/Unknown error format/, exception.message)

    @mock.verify
  end

  def test_send_messages_with_device_not_registered_error
    @response_mock.expect(:code, 200)
    @response_mock.expect(:body, not_registered_device_error_body.to_json)
    token   = 'ExponentPushToken[42]'
    message = "\"#{token}\" is not a registered push notification recipient"

    @mock.expect(:post, @response_mock, client_args)

    response_handler = @client.send_messages(messages)
    assert_equal(message, response_handler.errors.first.message)
    assert(response_handler.errors.first.instance_of?(Exponent::Push::DeviceNotRegisteredError))
    assert(response_handler.invalid_push_tokens.include?(token))
    assert(response_handler.errors?)

    @mock.verify
  end

  def test_send_messages_too_many_messages
    message = 'Only 100 message objects at a time allowed.'

    e = assert_raises TooManyMessagesError do
      @client.send_messages(too_many_messages)
    end

    assert_equal(e.message, message)
  end

  def test_send_messages_with_message_too_big_error
    @response_mock.expect(:code, 200)
    @response_mock.expect(:body, message_too_big_error_body.to_json)
    message = 'Message too big'

    @mock.expect(:post, @response_mock, client_args)

    response_handler = @client.send_messages(messages)
    assert(response_handler.errors.first.instance_of?(Exponent::Push::MessageTooBigError))
    assert_equal(message, response_handler.errors.first.message)
    assert(response_handler.errors?)

    @mock.verify
  end

  def test_send_messages_with_message_rate_exceeded_error
    @response_mock.expect(:code, 200)
    @response_mock.expect(:body, message_rate_exceeded_error_body.to_json)
    message = 'Message rate exceeded'

    @mock.expect(:post, @response_mock, client_args)

    response_handler = @client.send_messages(messages)
    assert(response_handler.errors.first.instance_of?(Exponent::Push::MessageRateExceededError))
    assert_equal(message, response_handler.errors.first.message)

    @mock.verify
  end

  def test_send_messages_with_invalid_credentials_error
    @response_mock.expect(:code, 200)
    @response_mock.expect(:body, invalid_credentials_error_body.to_json)
    message = 'Invalid credentials'

    @mock.expect(:post, @response_mock, client_args)

    response_handler = @client.send_messages(messages)
    assert(response_handler.errors.first.instance_of?(Exponent::Push::InvalidCredentialsError))
    assert_equal(message, response_handler.errors.first.message)

    @mock.verify
  end

  def test_send_messages_with_apn_error
    @response_mock.expect(:code, 200)
    @response_mock.expect(:body, apn_error_body.to_json)

    @mock.expect(:post, @response_mock, client_args)

    response_handler = @client.send_messages(messages)
    assert(response_handler.errors.first.instance_of?(Exponent::Push::UnknownError))
    assert_match(/Unknown error format/, response_handler.errors.first.message)

    @mock.verify
  end

  def test_get_receipts_with_success_receipt
    @response_mock.expect(:code, 200)
    @response_mock.expect(:body, receipt_success_body.to_json)
    receipt_ids = [success_receipt]

    @mock.expect(:post, @response_mock, receipt_client_args(receipt_ids))

    response_handler = @client.verify_deliveries(receipt_ids)
    assert_match(success_receipt, response_handler.receipt_ids.first)

    @mock.verify
  end

  def test_get_receipts_with_error_receipt
    @response_mock.expect(:code, 200)
    @response_mock.expect(:body, receipt_error_body.to_json)
    receipt_ids = [error_receipt]

    @mock.expect(:post, @response_mock, receipt_client_args(receipt_ids))

    response_handler = @client.verify_deliveries(receipt_ids)
    assert_match(error_receipt, response_handler.receipt_ids.first)
    assert_equal(true, response_handler.errors?)
    assert_equal(1, response_handler.errors.count)
    assert(response_handler.errors.first.instance_of?(Exponent::Push::DeviceNotRegisteredError))

    @mock.verify
  end

  def test_get_receipts_with_variable_success_receipts
    @response_mock.expect(:code, 200)
    @response_mock.expect(:body, multiple_receipts.to_json)
    receipt_ids = [error_receipt, success_receipt]

    @mock.expect(:post, @response_mock, receipt_client_args(receipt_ids))

    response_handler = @client.verify_deliveries(receipt_ids)
    assert_match(error_receipt, response_handler.receipt_ids.first)
    assert_match(success_receipt, response_handler.receipt_ids.last)
    assert_equal(true, response_handler.errors?)
    assert_equal(1, response_handler.errors.count)
    assert(response_handler.errors.first.instance_of?(Exponent::Push::DeviceNotRegisteredError))

    @mock.verify
  end

  def test_get_receipts_with_gzip_success_receipt
    @response_mock.expect(:code, 200)
    @response_mock.expect(:body, receipt_success_body.to_json)
    receipt_ids = [success_receipt]

    @mock.expect(:post, @response_mock, gzip_receipt_client_args(receipt_ids))

    response_handler = @client_gzip.verify_deliveries(receipt_ids)
    assert_match(success_receipt, response_handler.receipt_ids.first)

    @mock.verify
  end

  def test_get_receipts_with_gzip_error_receipt
    @response_mock.expect(:code, 200)
    @response_mock.expect(:body, receipt_error_body.to_json)
    receipt_ids = [error_receipt]

    @mock.expect(:post, @response_mock, gzip_receipt_client_args(receipt_ids))

    response_handler = @client_gzip.verify_deliveries(receipt_ids)
    assert_match(error_receipt, response_handler.receipt_ids.first)
    assert_equal(true, response_handler.errors?)
    assert_equal(1, response_handler.errors.count)
    assert(response_handler.errors.first.instance_of?(Exponent::Push::DeviceNotRegisteredError))

    @mock.verify
  end

  def test_get_receipts_with_gzip_variable_success_receipts
    @response_mock.expect(:code, 200)
    @response_mock.expect(:body, multiple_receipts.to_json)
    receipt_ids = [error_receipt, success_receipt]

    @mock.expect(:post, @response_mock, gzip_receipt_client_args(receipt_ids))

    response_handler = @client_gzip.verify_deliveries(receipt_ids)
    assert_match(error_receipt, response_handler.receipt_ids.first)
    assert_match(success_receipt, response_handler.receipt_ids.last)
    assert_equal(true, response_handler.errors?)
    assert_equal(1, response_handler.errors.count)
    assert(response_handler.errors.first.instance_of?(Exponent::Push::DeviceNotRegisteredError))

    @mock.verify
  end

  # DEPRECATED -- TESTS BELOW HERE RELATE TO CODE THAT WILL BE REMOVED

  def test_publish_with_success
    @response_mock.expect(:code, 200)
    @response_mock.expect(:body, success_body.to_json)

    @mock.expect(:post, @response_mock, client_args)

    @client.publish(messages)

    @mock.verify
  end

  def test_publish_with_gzip_success
    @response_mock.expect(:code, 200)
    @response_mock.expect(:body, success_body.to_json)

    @mock.expect(:post, @response_mock, gzip_client_args)

    @client_gzip.publish(messages)

    @mock.verify
  end

  def test_publish_with_gzip
    @response_mock.expect(:code, 200)
    @response_mock.expect(:body, success_body.to_json)

    @mock.expect(:post, @response_mock, gzip_client_args)

    @client_gzip.publish(messages)

    @mock.verify
  end

  def test_publish_with_unknown_error
    @response_mock.expect(:code, 400)
    @response_mock.expect(:body, error_body.to_json)
    message = 'An unknown error occurred.'

    @mock.expect(:post, @response_mock, client_args)

    exception = assert_raises Exponent::Push::UnknownError do
      @client.publish(messages)
    end

    assert_equal(message, exception.message)

    @mock.verify
  end

  def test_publish_with_device_not_registered_error
    @response_mock.expect(:code, 200)
    @response_mock.expect(:body, not_registered_device_error_body.to_json)
    message = '"ExponentPushToken[42]" is not a registered push notification recipient'

    @mock.expect(:post, @response_mock, client_args)

    exception = assert_raises Exponent::Push::DeviceNotRegisteredError do
      @client.publish(messages)
    end

    assert_equal(message, exception.message)

    @mock.verify
  end

  def test_publish_with_message_too_big_error
    @response_mock.expect(:code, 200)
    @response_mock.expect(:body, message_too_big_error_body.to_json)
    message = 'Message too big'

    @mock.expect(:post, @response_mock, client_args)

    exception = assert_raises Exponent::Push::MessageTooBigError do
      @client.publish(messages)
    end

    assert_equal(message, exception.message)

    @mock.verify
  end

  def test_publish_with_message_rate_exceeded_error
    @response_mock.expect(:code, 200)
    @response_mock.expect(:body, message_rate_exceeded_error_body.to_json)
    message = 'Message rate exceeded'

    @mock.expect(:post, @response_mock, client_args)

    exception = assert_raises Exponent::Push::MessageRateExceededError do
      @client.publish(messages)
    end

    assert_equal(message, exception.message)

    @mock.verify
  end

  def test_publish_with_invalid_credentials_error
    @response_mock.expect(:code, 200)
    @response_mock.expect(:body, invalid_credentials_error_body.to_json)
    message = 'Invalid credentials'

    @mock.expect(:post, @response_mock, client_args)

    exception = assert_raises Exponent::Push::InvalidCredentialsError do
      @client.publish(messages)
    end

    assert_equal(message, exception.message)

    @mock.verify
  end

  def test_publish_with_apn_error
    @response_mock.expect(:code, 200)
    @response_mock.expect(:body, apn_error_body.to_json)

    @mock.expect(:post, @response_mock, client_args)

    exception = assert_raises Exponent::Push::UnknownError do
      @client.publish(messages)
    end

    assert_match(/Unknown error format/, exception.message)

    @mock.verify
  end

  private

  def success_body
    { 'data' => [{ 'status' => 'ok' }] }
  end

  def success_receipt
    'YYYYYYYY-YYYY-YYYY-YYYY-YYYYYYYYYYYY'
  end

  def error_receipt
    'XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX'
  end

  def receipt_success_body
    {
      'data' => {
        'YYYYYYYY-YYYY-YYYY-YYYY-YYYYYYYYYYYY' => {
          'status' => 'ok'
        }
      }
    }
  end

  def receipt_error_body
    {
      'data' => {
        'XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX' => {
          'status' => 'error',
          'message' => 'The Apple Push Notification service failed to send the notification',
          'details' => {
            'error' => 'DeviceNotRegistered'
          }
        }
      }
    }
  end

  def multiple_receipts
    {
      'data' => {
        'XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX' => {
          'status' => 'error',
          'message' => 'The Apple Push Notification service failed to send the notification',
          'details' => {
            'error' => 'DeviceNotRegistered'
          }
        },
        'YYYYYYYY-YYYY-YYYY-YYYY-YYYYYYYYYYYY' => {
          'status' => 'ok'
        }
      }
    }
  end

  def error_body
    {
      'errors' => [{
        'code' => 'INTERNAL_SERVER_ERROR',
        'message' => 'An unknown error occurred.'
      }]
    }
  end

  def message_too_big_error_body
    build_error_body('MessageTooBig', 'Message too big')
  end

  def not_registered_device_error_body
    build_error_body(
      'DeviceNotRegistered',
      '"ExponentPushToken[42]" is not a registered push notification recipient'
    )
  end

  def message_rate_exceeded_error_body
    build_error_body('MessageRateExceeded', 'Message rate exceeded')
  end

  def invalid_credentials_error_body
    build_error_body('InvalidCredentials', 'Invalid credentials')
  end

  def apn_error_body
    {
      'data' => [{
        'status' => 'error',
        'message' =>
                         'Could not find APNs credentials for you (your_app). Check whether you are trying to send a notification to a detached app.'
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
          'Accept' => 'application/json'
        },
        accept_encoding: false
      }
    ]
  end

  def alternative_client_args(messages)
    [
      'https://exp.host/--/api/v2/push/send',
      {
        body: messages.to_json,
        headers: {
          'Content-Type' => 'application/json',
          'Accept' => 'application/json'
        },
        accept_encoding: false
      }
    ]
  end

  def gzip_client_args
    [
      'https://exp.host/--/api/v2/push/send',
      {
        body: messages.to_json,
        headers: {
          'Content-Type' => 'application/json',
          'Accept' => 'application/json'
        },
        accept_encoding: true
      }
    ]
  end

  def receipt_client_args(receipt_ids)
    [
      'https://exp.host/--/api/v2/push/getReceipts',
      {
        body: { ids: receipt_ids }.to_json,
        headers: {
          'Content-Type' => 'application/json',
          'Accept' => 'application/json'
        },
        accept_encoding: false
      }
    ]
  end

  def gzip_receipt_client_args(receipt_ids)
    [
      'https://exp.host/--/api/v2/push/getReceipts',
      {
        body: { ids: receipt_ids }.to_json,
        headers: {
          'Content-Type' => 'application/json',
          'Accept' => 'application/json'
        },
        accept_encoding: true
      }
    ]
  end

  def alternate_format_messages
    [{
      to: [
        'ExponentPushToken[xxxxxxxxxxxxxxxxxxxxxx]',
        'ExponentPushToken[yyyyyyyyyyyyyyyyyyyyyy]'
      ],
      badge: 1,
      sound: 'default',
      body: 'You got a completely unique message from us! /s'
    }]
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

  def too_many_messages
    (0..101).map { create_message }
  end

  def create_message
    id = (0...22).map { ('a'..'z').to_a[rand(26)] }.join
    {
      to: "ExponentPushToken[#{id}]",
      sound: 'default',
      body: 'Hello world!'
    }
  end

  def build_error_body(error_code, message)
    {
      'data' => [{
        'status' => 'error',
        'message' => message,
        'details' => { 'error' => error_code }
      }]
    }
  end
end
