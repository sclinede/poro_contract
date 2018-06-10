require 'io/console'
require 'twitter' # install gem 'twitter'

class TwitterSearch
  DEFAULT_TIMEOUTS = { connect: 2, read: 2 }.freeze

  def initialize(credentials, timeouts = nil)
    @credentials = credentials
    @timeouts = timeouts || DEFAULT_TIMEOUTS
  end

  def call(search_query)
    @search_query = search_query
    TwitterSearchContract.new.match!(search_query) do
      @response = client.search(search_query)
    end
  end

  def print_stats
    return unless @response

    users = {}
    @response.to_h[:statuses].each do |status|
      users[status.dig(:user, :screen_name)] = status.dig(:user, :followers_count)
    end

    if users.empty?
      puts "Nothing found in last week Tweets for: `#{@search_query}`. Sorry!"
      return
    end

    puts "Interest stats about `#{@search_query}`:"
    puts "Engagement (number of users affected) ~ #{users.values.sum} users"
    puts "Top user stats: "
    users.sort_by { |_, v| -v }
         .take(10)
         .each { |username, followers| puts " - #{username} has #{followers} followers" }

    nil
  end

  def client
    @client ||= ::Twitter::REST::Client.new(
      @credentials.merge(timeouts: @timeouts)
    )
  end
end

require_relative '../poro_contract.rb'
class TwitterSearchContract < POROContract
  private

  def twitter_response
    @output
  end

  # Guarantees

  def guarantee_response_structure
    @meta[:response_type] = twitter_response.class.to_s
    return unless twitter_response.respond_to?(:to_hash)

    twitter_response_hash = twitter_response.to_hash
    @tweets = response_tweets(twitter_response_hash)

    !@tweets.nil? &&
      tweets_count_without_user_id(twitter_response_hash, @tweets).zero?
  end

  # Expectations

  def expect_empty_search
    @tweets.empty?
  end

  def expect_non_empty_search
    users_without_name(@tweets).empty? &&
      users_without_followers_data(@tweets).empty?
  end

  # Helpers

  def response_tweets(response_hash)
    response_hash[:statuses]&.select do |s|
      !s.dig(:user, :id).nil?
    end
  end

  def tweets_count_without_user_id(response_hash, tweets)
    @meta[:tweets_count_without_user_id] =
      response_hash[:statuses].count - tweets.count
  end

  def users_without_name(tweets)
    tweets.select { |s| s.dig(:user, :screen_name).nil? }.tap do |statuses|
      @meta[:user_ids_without_screen_name] = statuses.map { |s| s.dig(:user, :id) }
    end
  end

  def users_without_followers_data(tweets)
    tweets.select { |s| s.dig(:user, :followers_count).nil? }.tap do |statuses|
      @meta[:user_ids_without_followers_count] = statuses.map { |s| s.dig(:user, :id) }
    end
  end
end

def credentials
  return $credentials if defined? $credentials
  puts "Enter Twitter access string (login, access_token, access_token_secret, consumer_key, consumer_secret) joined by `::`"
  access_string = STDIN.noecho(&:gets).chomp
  access_data = access_string.split("::")
  keys = %i(login access_token access_token_secret consumer_key consumer_secret)
  $credentials = Hash[keys.zip(access_data)]
end
alias ask_credentials credentials

def search(search_query, credentials = ask_credentials)
  twitter_search = TwitterSearch.new(credentials)
  twitter_search.call(search_query)
  twitter_search.print_stats
end
