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

      def handle_response(response)
        case response.code.to_s
        when /(^4|^5)/
          error = extract_error(parse_json(response))
          raise Error, "#{error.fetch('code')} -> #{error.fetch('message')}"
        else
          handle_success(parse_json(response).fetch('data').first)
        end
      end

      def parse_json(response)
        JSON.parse(response.body)
      end

      def extract_error(body)
        if body.respond_to?(:fetch)
          body.fetch('errors').first { unknown_error }
        else
          unknown_error
        end
      end

      attr_reader :http_client

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

      def handle_success(data)
        return data if data.fetch('status') == 'ok'
        raise Exponent::Push::Error, "#{data['details']['error']} -> #{data['message']}"
      end

      def unknown_error
        {
          'code' => 'Unknown code',
          'message' => 'Unknown message'
        }
      end
    end
  end
end
