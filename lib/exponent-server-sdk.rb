require 'exponent-server-sdk/version'
require 'exponent-server-sdk/too_many_messages_error'
require 'typhoeus'
require 'json'

# Basic Usage:
#
# Create new client
# client = Exponent::Push::Client.new(**args)
#
# Send UPTO ~~100~~ messages per call,
# https://docs.expo.io/versions/latest/guides/push-notifications/#message-format
# response_handler = client.send_messages([list of formatted messages])
#
# Check the response to see if any errors were re
# response_handler.errors?
#
# To process each error, iterate over the errors array
# which contains each Error class instance
# response_handler.errors
#
# There is an array of invalid ExponentPushTokens that were found in the initial /send call
# response_handler.invalid_push_tokens['ExponentPushToken[1212121212121212]']
#
# You can use the handler to get receipt_ids
# response_handler.receipt_ids
#
# You can pass an array of receipt_ids to verify_deliveries method and
# it will populate a new ResponseHandler with any errors
# receipt_response = client.verify_deliveries(receipt_ids)

module Exponent
  def self.is_exponent_push_token?(token)
    token.start_with?('ExponentPushToken')
  end

  module Push
    class Client
      def initialize(**args)
        @http_client = args[:http_client] || Typhoeus
        @error_builder = ErrorBuilder.new
        # future versions will deprecate this
        @response_handler = args[:response_handler] || ResponseHandler.new
        @gzip             = args[:gzip] == true
      end

      # returns a string response with parsed success json or error
      # @deprecated
      def publish(messages)
        warn '[DEPRECATION] `publish` is deprecated. Please use `send_messages` instead.'
        @response_handler.handle(push_notifications(messages))
      end

      # returns response handler that provides access to errors? and other response inspection methods
      def send_messages(messages, **args)
        # https://docs.expo.io/versions/latest/guides/push-notifications/#message-format
        raise TooManyMessagesError, 'Only 100 message objects at a time allowed.' if messages.length > 100

        response = push_notifications(messages)

        # each call to send_messages will return a new instance of ResponseHandler
        handler = args[:response_handler] || ResponseHandler.new
        handler.process_response(response)
        handler
      end

      def verify_deliveries(receipt_ids, **args)
        response = get_receipts(receipt_ids)
        handler  = args[:response_handler] || ResponseHandler.new
        handler.process_response(response)
        handler
      end

      private

      def push_notifications(messages)
        @http_client.post(
          push_url,
          body: messages.to_json,
          headers: headers,
          accept_encoding: @gzip
        )
      end

      def push_url
        'https://exp.host/--/api/v2/push/send'
      end

      def get_receipts(receipt_ids)
        @http_client.post(
          receipts_url,
          body: { ids: receipt_ids }.to_json,
          headers: headers,
          accept_encoding: @gzip
        )
      end

      def receipts_url
        'https://exp.host/--/api/v2/push/getReceipts'
      end

      def headers
        headers = {
          'Content-Type' => 'application/json',
          'Accept' => 'application/json'
        }
        headers
      end
    end

    class ResponseHandler
      attr_reader :response, :invalid_push_tokens, :receipt_ids, :errors

      def initialize(error_builder = ErrorBuilder.new)
        @error_builder       = error_builder
        @response            = nil
        @receipt_ids         = []
        @invalid_push_tokens = []
        @errors              = []
      end

      def process_response(response)
        @response = response

        case response.code.to_s
        when /(^4|^5)/
          raise @error_builder.parse_response(response)
        else
          sort_results
        end
      end

      def errors?
        @errors.any?
      end

      # @deprecated
      def handle(response)
        warn '[DEPRECATION] `handle` is deprecated. Please use `process_response` instead.'
        @response = response
        case response.code.to_s
        when /(^4|^5)/
          raise build_error_from_failure
        else
          extract_data
        end
      end

      private

      def sort_results
        data = body&.fetch('data', nil) || nil

        # something is definitely wrong
        return if data.nil?

        # Array indicates a response from the /send endpoint
        # Hash indicates a response from the /getReceipts endpoint
        if data.is_a? Array
          data.each do |push_ticket|
            receipt_id = push_ticket.fetch('id', nil)
            if push_ticket.fetch('status', nil) == 'ok'
              @receipt_ids.push(receipt_id) unless receipt_id.nil?
            else
              process_error(push_ticket)
            end
          end
        else
          process_receipts(data)
        end
      end

      def process_receipts(receipts)
        receipts.each do |receipt_id, receipt|
          @receipt_ids.push(receipt_id) unless receipt_id.nil?
          process_error(receipt) unless receipt.fetch('status') == 'ok'
        end
      end

      def process_error(push_ticket)
        message     = push_ticket.fetch('message')
        matches     = message.match(/ExponentPushToken\[(...*)\]/)
        error_class = @error_builder.parse_push_ticket(push_ticket)

        @invalid_push_tokens.push(matches[0]) unless matches.nil?

        @errors.push(error_class) unless @errors.include?(error_class)
      end

      def body
        # memoization FTW!
        @body ||= JSON.parse(@response.body)
      rescue SyntaxError
        # Sometimes the server returns an empty string.
        # It must be escaped before we can process it.
        @body = JSON.parse(@response.body.to_json)
      rescue StandardError
        # Prevent nil errors in old version of ruby when using fetch
        @body = {}
      end

      ##### DEPRECATED METHODS #####

      # @deprecated
      def build_error_from_failure
        @error_builder.build_from_erroneous(body)
      end

      # @deprecated
      def extract_data
        data = body.fetch('data')
        if data.is_a? Hash
          validate_status(data.fetch('status'), body)
          data
        elsif data.is_a? Array
          data.map do |receipt|
            validate_status(receipt.fetch('status'), body)
            receipt
          end
        else
          {}
        end
      end

      # @deprecated
      def validate_status(status, response)
        raise build_error_from_success(response) unless status == 'ok'
      end

      # @deprecated
      def build_error_from_success(response)
        @error_builder.build_from_successful(response)
      end
    end

    class ErrorBuilder
      def parse_response(response)
        with_error_handling(response) do
          error      = response.fetch('errors')
          error_name = error.fetch('code')
          message    = error.fetch('message')

          get_error_class(error_name).new(message)
        end
      end

      def parse_push_ticket(push_ticket)
        with_error_handling(push_ticket) do
          message = push_ticket.fetch('message')
          get_error_class(push_ticket.fetch('details').fetch('error')).new(message)
        end
      end

      %i[erroneous successful].each do |selector|
        define_method(:"build_from_#{selector}") do |response|
          with_error_handling(response) do
            send "from_#{selector}_response", response
          end
        end
      end

      private

      def with_error_handling(response)
        yield(response)
      rescue KeyError, NoMethodError
        unknown_error_format(response)
      end

      def validate_error_name(condition)
        condition ? yield : Exponent::Push::UnknownError
      end

      def get_error_class(error_name)
        validate_error_name(Exponent::Push.error_names.include?(error_name)) do
          Exponent::Push.const_get("#{error_name}Error")
        end
      end

      def unknown_error_format(response)
        Exponent::Push::UnknownError.new("Unknown error format: #{response.respond_to?(:body) ? response.body : response}")
      end

      ##### DEPRECATED METHODS #####

      # @deprecated
      def from_erroneous_response(response)
        error      = response.fetch('errors').first
        error_name = error.fetch('code')
        message    = error.fetch('message')

        get_error_class(error_name).new(message)
      end

      # @deprecated
      def from_successful_response(response)
        delivery_result = response.fetch('data').first
        message         = delivery_result.fetch('message')
        get_error_class(delivery_result.fetch('details').fetch('error')).new(message)
      end
    end

    Error = Class.new(StandardError)

    def self.error_names
      %w[DeviceNotRegistered MessageTooBig
         MessageRateExceeded InvalidCredentials
         Unknown]
    end

    error_names.each do |error_name|
      const_set "#{error_name}Error", Class.new(Error)
    end
  end
end
