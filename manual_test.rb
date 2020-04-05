require_relative 'lib/exponent-server-sdk'

client = Exponent::Push::Client.new

# OR use GZIP to be AWESOME
# client = Exponent::Push::Client.new(gzip: true)

messages = [{
              to:    'ExponentPushToken[HbuLbNFwb5_ENuljvAePLs]',
              sound: 'default',
              title: "You're Winning!",
              body:  'You just won EVERTHING!',
              data:  {
                       type:    'WINNINGS',
                       message: 'You just won EVERTHING!'

                     }.to_json
            }]
client.publish messages
