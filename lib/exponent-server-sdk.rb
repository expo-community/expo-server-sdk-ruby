require 'exponent-server-sdk/version'
require 'typhoeus'
require 'json'

module Exponent
  def self.is_exponent_push_token?(token)
    token.start_with?('ExponentPushToken')
  end

  module Push

    class Client
      def initialize(http_client      = Typhoeus,
                     response_handler = ResponseHandler.new)
        @http_client      = http_client
        @response_handler = response_handler
      end

      def publish(messages)
        response_handler.handle(push_notifications(messages))
      end

      private

      attr_reader :http_client, :response_handler

      def push_notifications(messages)
        http_client.post(
          push_url,
          body: messages.to_json,
          headers: headers
        )
      end

      def push_url
        'https://exp.host/--/api/v2/push/send'
      end

      def headers
        {
          'Content-Type' => 'application/json',
          'Accept'       => 'application/json'
        }
      end
    end

    class ResponseHandler
      def initialize(error_builder = ErrorBuilder.new)
        @error_builder = error_builder
      end

      def handle(response)
        case response.code.to_s
        when /(^4|^5)/
          raise build_error_from_failure(parse_json(response))
        else
          handle_success(parse_json(response))
        end
      end

      private

      attr_reader :error_builder

      def parse_json(response)
        JSON.parse(response.body)
      end

      def build_error_from_failure(response)
        error_builder.build_from_erroneous(response)
      end

      def handle_success(response)
        extract_data(response).tap do |data|
          validate_status(data.fetch('status'), response)
        end
      end

      def extract_data(response)
        response.fetch('data').first
      end

      def validate_status(status, response)
        raise build_error_from_success(response) unless status == 'ok'
      end

      def build_error_from_success(response)
        error_builder.build_from_successful(response)
      end
    end

    class ErrorBuilder
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
      rescue KeyError
        unknown_error_format(response)
      end

      def from_erroneous_response(response)
        error      = response.fetch('errors').first
        error_name = error.fetch('code')
        message    = error.fetch('message')

        get_error_class(error_name).new(message)
      end

      def from_successful_response(response)
        data    = response.fetch('data').first
        message = data.fetch('message')

        get_error_class(data.fetch('details').fetch('error')).new(message)
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
        Exponent::Push::UnknownError.new("Unknown error format: #{response}")
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
