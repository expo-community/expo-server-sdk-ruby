require 'exponent-server-sdk/version'

require 'httparty'

module Exponent
  module Push
    def self.is_exponent_push_token?(token)
      token.start_with?('ExponentPushToken')
    end

    class LegacyClient

      def initialize(new_http_client=nil)
        @http_client = new_http_client || HTTParty
      end

      def publish(options)
        data = options.delete(:data)
        response = @http_client.post('https://exp.host/--/api/notify/' + ERB::Util.url_encode([options].to_json),
          :body => data.to_json,
          :headers => {
            'Content-Type' => 'application/json'
          }
        )

        case response.code
          when 400
            raise Exponent::Push::Errors::InvalidPushTokenError
        end
      end
    end

    class Client

      def initialize(new_http_client=nil)
        @http_client = new_http_client || HTTParty
      end

      def publish(messages)
        response = @http_client.post('https://exp.host/--/api/v2/push/send',
          body: messages.to_json,
          headers: {
            'Content-Type' => 'application/json',
            'Accept' => 'application/json',
            'Accept-Encoding' => 'gzip, deflate'
          }
        )

        case response.code
          when 400
            raise Exponent::Push::Errors::InvalidPushTokenError
        end
      end
    end

    module Errors
      class InvalidPushTokenError < StandardError
      end
    end
  end
end
