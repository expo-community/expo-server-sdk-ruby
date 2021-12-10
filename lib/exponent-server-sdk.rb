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

      attr_reader :post_options, :http_client

      def initialize(http_client: Typhoeus, gzip: nil, **post_options)
        @http_client = http_client
        @post_options = {accept_encoding: gzip == true}.update(post_options)
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
        http_client.post(
          push_url,
          body: messages.to_json,
          headers: headers,
          **post_options
        )
      end

      def push_url
        'https://exp.host/--/api/v2/push/send'
      end

      def get_receipts(receipt_ids)
        http_client.post(
          receipts_url,
          body: { ids: receipt_ids }.to_json,
          headers: headers,
          **post_options
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
          # @aryk - This used to be parsing the response, but the error builder is expecting a hash, so it's most likely
          # the body here. I think this was the root for a lot of issues in the API.
          # raise @error_builder.parse_response(response)
          raise @error_builder.parse_response(body)
        else
          sort_results
        end
      end

      def errors?
        @errors.any?
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
        message      = push_ticket.fetch('message')
        invalid      = message.match(/ExponentPushToken\[(...*)\]/)
        unregistered = message.match(/\"(...*)\"/)
        error_class  = @error_builder.parse_push_ticket(push_ticket)

        @invalid_push_tokens.push(invalid[0])      unless invalid.nil?
        @invalid_push_tokens.push(unregistered[1]) unless unregistered.nil?

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

    end

    class ErrorBuilder
      def parse_response(response)
        with_error_handling(response) do
          error      = response.fetch('errors')
          error      = error[0] if error.is_a?(Array) # with PUSH_TOO_MANY_EXPERIENCE_IDS will get an array of one
          error_name = error.fetch('code')
          message    = error.fetch('message')
          if (details = error['details'])
            details = "#{details[0..500]}..." if details.size > 500 # don't use ruby truncate incase they are using an older version of Ruby
            message << " Details: #{details}"
          end
          get_error_class(error_name).new(message)
        end
      end

      def parse_push_ticket(push_ticket)
        with_error_handling(push_ticket) do
          message = push_ticket.fetch('message')
          get_error_class(push_ticket.fetch('details').fetch('error')).new(message)
        end
      end

      private

      def with_error_handling(response)
        yield
      rescue KeyError, NoMethodError => e
        unknown_error_format(response, e.message)
      end

      def validate_error_name(condition)
        condition ? yield : Exponent::Push::UnknownError
      end

      def get_error_class(error_name)
        error_name = classify(error_name)
        validate_error_name(Exponent::Push.error_names.include?(error_name)) do
          Exponent::Push.const_get("#{error_name}Error")
        end
      end

      # https://stackoverflow.com/a/4072202/7180620
      def classify(str)
        str = str.split('_').collect! { |w| w.capitalize }.join if str=~/^[[A-Z0-9]_]+$/
        str
      end

      def unknown_error_format(response, error_message = nil)
        str = "Unknown error format: #{response.respond_to?(:body) ? response.body : response}"
        str << " | #{error_message}" if error_message
        Exponent::Push::UnknownError.new(str)
      end
    end

    Error = Class.new(StandardError)

    def self.error_names
      %w[DeviceNotRegistered MessageTooBig PushTooManyExperienceIds
         MessageRateExceeded InvalidCredentials InternalServerError
         Unknown]
    end

    error_names.each do |error_name|
      const_set "#{error_name}Error", Class.new(Error)
    end
  end
end
