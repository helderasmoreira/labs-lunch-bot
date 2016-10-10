require 'slack-ruby-bot'

class LabsLunchEvaluator < SlackRubyBot::Bot
  command 'ping' do |client, data, match|
    client.say(text: 'pong', channel: data.channel)
  end
end

LabsLunchEvaluator.run
