require 'exponent-server-sdk/version'
require 'typhoeus'
require 'json'

module Exponent
  def self.is_exponent_push_token?(token)
    token.start_with?('ExponentPushToken')
  end

  module Push
    Error = Class.new(StandardError)

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
          raise Error, build_error_from_failure(parse_json(response))
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
        error = response.fetch('errors').first { unknown_error_format(response) }
        "#{error.fetch('code')} -> #{error.fetch('message')}"
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
          'Content-Type'    => 'application/json',
          'Accept'          => 'application/json',
          'Accept-Encoding' => 'gzip, deflate'
        }
      end

      def handle_success(response)
        data = extract_data(response)
        if data.fetch('status') == 'ok'
          data
        else
          raise Error, build_error_from_success(response)
        end
      end

      def build_error_from_success(response)
        build_error_with_handling(response) do
          extract_error_from_success(response)
        end
      end

      def extract_error_from_success(response)
        data = extract_data(response)
        message = data.fetch('message')

        if data['details']
          "#{data.fetch('details').fetch('error')} -> #{message}"
        else
          "#{data.fetch('status')} -> #{message}"
        end
      end

      def extract_data(response)
        response.fetch('data').first
      end

      def unknown_error_format(response)
        "Unknown error format: #{response}"
      end
    end
  end
end
