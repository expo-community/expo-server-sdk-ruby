require 'exponent-server-sdk/version'
require 'typhoeus'
require 'json'

module Exponent
  def self.is_exponent_push_token?(token)
    token.start_with?('ExponentPushToken')
  end

  module Push

    class Client

      def initialize(new_http_client = nil)
        @http_client = new_http_client || Typhoeus
      end

      def publish(messages)
        handle_response(push_notifications(messages))
      end

      private

      attr_reader :http_client

      def handle_response(response)
        case response.code.to_s
        when /(^4|^5)/
          raise build_error_from_failure(parse_json(response))
        else
          handle_success(parse_json(response))
        end
      end

      def parse_json(response)
        JSON.parse(response.body)
      end

      def build_error_from_failure(response)
        build_error_with_handling(response) do
          extract_error_from_response(response)
        end
      end

      def extract_error_from_response(response)
        error = response.fetch('errors').first
        error_name = error.fetch('code')
        message = error.fetch('message')

        validate_error_name(Exponent::Push.error_names.include?(error_name)) do
          Exponent::Push.const_get("#{error_name}Error")
        end.new(message)
      end

      def build_error_with_handling(response)
        yield(response)
      rescue KeyError
        unknown_error_format(response)
      end

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

      def handle_success(response)
        extract_data(response).tap do |data|
          validate_status(data.fetch('status'), response)
        end
      end

      def validate_status(status, response)
        raise build_error_from_success(response) unless status == 'ok'
      end

      def build_error_from_success(response)
        build_error_with_handling(response) do
          extract_error_from_success(response)
        end
      end

      def extract_error_from_success(response)
        data    = extract_data(response)
        message = data.fetch('message')

        get_error_class(data.fetch('details').fetch('error')).new(message)
      end

      def get_error_class(error_name)
        validate_error_name(Exponent::Push.error_names.include?(error_name)) do
          Exponent::Push.const_get("#{error_name}Error")
        end
      end

      def validate_error_name(condition)
        condition ? yield : Exponent::Push::UnknownError
      end

      def extract_data(response)
        response.fetch('data').first
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
