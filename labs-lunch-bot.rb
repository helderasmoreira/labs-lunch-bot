require 'slack-ruby-bot'
require 'json'
require 'aws-sdk'

class LabsLunchBot < SlackRubyBot::Bot
  @valid_for = 60

  s3 = Aws::S3::Resource.new
  @data_object = s3.bucket('labs-lunch-bot').object('data.json')

  @data = @data_object.exists? ? JSON.parse(@data_object.get.body.string) : {}
  @data['restaurants'] ||= {}

  help do
    title 'Labs Lunch Bot'
    desc "This bot helps us classify our lunch places. "\
     "The idea is for one of us to open up the voting and in the next 60 minutes everyone can cast their vote. "\
     "Afterwards while listing the bot will calculate the average automatically, color code it accordingly and also show everyone's votes. "

    command 'list' do
      desc 'List all the restaurants we classified so far, ordered by timestamp.'
    end

    command 'rank' do
      desc 'List all the restaurants we classified so far, ordered by descending vote average .'
    end

    command 'new-vote' do
      desc "Start a new vote for a restaurant. The new vote will be available for 60 minutes. Usage: new-vote <name>"
    end

    command 'rename' do
      desc "Rename the current voting. Usage: rename <new-name>"
    end

    command 'set-owner' do
      desc 'Updates the owner (the person who decided on the restaurant) for the current vote. Usage: set-owner <owner>'
    end

    command 'vote' do
      desc 'Cast your vote for the current vote. If you do it multiple times within the time the voting is open, your vote will be overwritten. Usage: vote <digit>'
    end
  end

  match /^list$/i do |client, data, match|
    if @data['restaurants'].size == 0
      client.say(text: "There are no stored votings.", channel: data.channel)
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

  match /^rank$/i do |client, data, match|
    if @data['restaurants'].size == 0
      client.say(text: "There are no stored votings.", channel: data.channel)
    else
      @data['restaurants'].each do |name, data|
        votes = data['votes'].values
        data['average'] ||= (votes.inject{ |sum, el| sum + el }.to_f / votes.size)
      end

      @data['restaurants'].sort_by { |r| r[1]['average'] }.reverse.each do |k,v|
        client.web_client.chat_postMessage(
          channel: data.channel,
          as_user: true,
          attachments: [prettify(k, v)]
        )
      end
    end
  end

  match /^current$/i do |client, data, match|
    _ongoing = ongoing

    if _ongoing.present?
      restaurant = @data['restaurants'][_ongoing]
      remaining = @valid_for - minutes_elapsed(DateTime.parse(restaurant['timestamp']))
      nr_votes = restaurant['votes'].size
      client.say(text: "Ongoing voting for: #{_ongoing}. Remaining time: #{remaining} minutes. Votes so far: #{nr_votes}.", channel: data.channel)
    else
      client.say(text: "There's no ongoing voting.", channel: data.channel)
    end
  end

  match /^new-vote (?<name>.*)$/i do |client, data, match|
    if ongoing.present?
      client.say(text: "There's a valid voting taking place. Cast your vote instead.", channel: data.channel)
    elsif exists?(match[:name])
      client.say(text: "#{match[:name]} already exists. You need an unique name.", channel: data.channel)
    else
      @data['restaurants'][match[:name]] = { 'timestamp' => DateTime.now.to_s, 'owner' => nil, 'votes' => {} }
      save
      client.say(text: "Creating new entry valid for #{@valid_for} minutes. Use \"set-owner <owner>\" to say who suggested it and cast your votes.", channel: data.channel)
    end
  end

  match /^rename (?<name>.*)$/i do |client, data, match|
    _ongoing = ongoing

    if ongoing.nil?
      client.say(text: "There's no ongoing voting.", channel: data.channel)
    elsif exists?(match[:name])
      client.say(text: "#{match[:name]} already exists. You need an unique name.", channel: data.channel)
    else
      @data['restaurants'][match[:name]] = @data['restaurants'][_ongoing]
      @data['restaurants'].delete(_ongoing)
      save
      client.say(text: "Renamed #{_ongoing} to #{match[:name]}.", channel: data.channel)
    end
  end

  match /^set-owner (?<user>.*)$/i do |client, data, match|
    _ongoing = ongoing

    if _ongoing.nil?
      client.say(text: "There's no ongoing voting.", channel: data.channel)
    else
      @data['restaurants'][_ongoing]['owner'] = match[:user]
      save
      client.say(text: "Setting owner for #{_ongoing}.", channel: data.channel)
    end
  end

  match /^vote (?<number>\d)$/i do |client, data, match|
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

  # missing from help on purpose :->
  match /^delete (?<name>.*)$/i do |client, data, match|
    if exists?(match[:name])
      @data['restaurants'].delete(match[:name])
      save
      client.say(text: "Deleted #{match[:name]}.", channel: data.channel)
    else
      client.say(text: "#{match[:name]} not found.", channel: data.channel)
    end
  end

  def self.prettify(name, info)
    votes = info['votes'].map { |k, v| v }
    average = (info['average'] || votes.inject{ |sum, el| sum + el }.to_f / votes.size).round(1)

    color =
      case average
      when 0..4
        '#FF0000'
      when 4..6
        '#FF8C00'
      when 6..9
        '#00FF00'
      end

    {
      title: name,
      text: "Owned by: #{info['owner']}\n"\
        "Average: #{average}\n"\
        "Votes:\n#{info['votes'].map { |k,v| "#{k}: #{v}"}.join("\n")}",
      color: color
    }
  end

  def self.save
    @data_object.put(body: JSON.pretty_generate(@data))
  end

  def self.exists?(name)
    @data['restaurants'].has_key?(name)
  end

  def self.ongoing
    @data['restaurants'].find { |k, v| valid? DateTime.parse(v['timestamp']) }.try(&:first)
  end

  def self.valid?(datetime)
    minutes_elapsed(datetime) < @valid_for
  end

  def self.minutes_elapsed(datetime)
    ((DateTime.now - datetime) * 24 * 60).to_i
  end
end

LabsLunchBot.run
