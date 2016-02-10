require 'exponent-server-sdk/version'
require 'cgi'

module Exponent
  module Push
    def self.is_exponent_push_token?(token)
      token.start_with?('ExponentPushToken')
    end

    class Client
      def publish options
        data = options.delete(:data)
        response = HTTParty.post('https://exp.host/--/api/notify/' + CGI.escape(options.to_json), {
          body: data.to_json,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json'
          }
        })

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
