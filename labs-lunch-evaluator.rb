require 'slack-ruby-bot'
require 'json'

class LabsLunchEvaluator < SlackRubyBot::Bot
  @data_file_path = 'data.json'
  @valid_for = 30

  data_file = File.read(@data_file_path) if File.file? @data_file_path
  @data = data_file ? JSON.parse(data_file) : {}
  @data['restaurants'] ||= {}

  help do
    title 'Labs Lunch Evaluator'
    desc 'This bot helps us classify our lunch places.'

    command 'list' do
      desc 'List all the restaurants we classified so far.'
    end

    command 'new-vote' do
      desc 'Start a new vote for a restaurant. The new vote will be available for 30 minutes. Usage: new-vote <name>'
    end

    command 'set-owner' do
      desc 'Updates the owner (the person who decided on the restaurant) for the current vote. Usage: set-owner <owner>'
    end

    command 'vote' do
      desc 'Cast your vote for the current vote. If you do it multiple times within the time the voting is open, your vote will be overwritten. Usage: vote <digit>'
    end
  end

  match /^list$/ do |client, data, match|
    if @data['restaurants'].size == 0
      client.say(text: "There's no stored votings.", channel: data.channel)
    else
      @data['restaurants'].each do |k,v|
        client.web_client.chat_postMessage(
          channel: data.channel,
          as_user: true,
          attachments: [prettify(k, v)]
        )
      end
    end
  end

  match /^current$/ do |client, data, match|
    _ongoing = ongoing

    if _ongoing.present?
      client.web_client.chat_postMessage(
        channel: data.channel,
        as_user: true,
        attachments: [prettify(_ongoing, @data['restaurants'][_ongoing])]
      )
    else
      client.say(text: "There's no ongoing voting.", channel: data.channel)
    end
  end

  match /^new-vote (?<name>.*)$/ do |client, data, match|
    if ongoing.present?
      client.say(text: "There's a valid voting taking place. Cast your vote instead.", channel: data.channel)
    else
      @data['restaurants'][match[:name]] = { 'timestamp' => DateTime.now, 'owner' => nil, 'votes' => {} }
      save
      client.say(text: "Creating new entry valid for #{@valid_for} minutes. Use \"set-owner <owner>\" to say who suggested it and cast your votes.", channel: data.channel)
    end
  end

  match /^set-owner (?<user>.*)$/ do |client, data, match|
    _ongoing = ongoing

    if _ongoing.nil?
      client.say(text: "There's no ongoing voting.", channel: data.channel)
    else
      @data['restaurants'][_ongoing]['owner'] = match[:user]
      save
      client.say(text: "Setting owner for #{_ongoing}.", channel: data.channel)
    end
  end

  match /^vote (?<number>\d)$/ do |client, data, match|
    _ongoing = ongoing

    if _ongoing.nil?
      client.say(text: "There's no ongoing voting.", channel: data.channel)
    else
      @data['restaurants'][_ongoing]
      @data['restaurants'][_ongoing]['votes']["<@#{data.user}>"] = match[:number].to_i
      save
      client.say(text: "Vote saved for #{_ongoing}, thanks!", channel: data.channel)
    end
  end

  def self.prettify(name, info)
    votes = info['votes'].map { |k, v| v }
    average = votes.inject{ |sum, el| sum + el }.to_f / votes.size
    {
      title: name,
      text: "Owned by: #{info['owner']}\nVotes:\n#{info['votes'].map { |k,v| "#{k}: #{v}"}.join("\n")}\nAverage: #{average}",
      color: average >= 5 ? '#00FF00' : '#FF0000'
    }
  end

  def self.save
    File.open(@data_file_path, 'w') do |f|
      f.puts JSON.pretty_generate(@data)
    end
  end

  def self.ongoing
    @data['restaurants'].find { |k, v| valid? DateTime.parse(v['timestamp']) }.try(&:first)
  end

  def self.valid?(datetime)
    ((DateTime.now - datetime) * 24 * 60).to_i < @valid_for
  end
end

LabsLunchEvaluator.run
