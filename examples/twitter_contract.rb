require 'io/console'
require 'twitter' # install gem 'twitter'

class TwitterSearch
  DEFAULT_TIMEOUTS = { connect: 2, read: 2 }.freeze

  def initialize(credentials, timeouts = nil)
    @credentials = credentials
    @timeouts = timeouts || DEFAULT_TIMEOUTS
  end

  def call(search_query)
    client.search(search_query)
  end

  def client
    @client ||= ::Twitter::REST::Client.new(
      @credentials.merge(timeouts: @timeouts)
    )
  end
end

require_relative '../poro_contract.rb'
class TwitterContract < POROContract
  private

  def twitter_response
    @output
  end

  # Guarantees

  def guarantee_hash_response
    @meta[:response_type] = twitter_response.class.to_s
    return unless twitter_response.respond_to?(:to_hash)
    @twitter_response_hash = twitter_response.to_hash
    true
  end

  def guarantee_response_structure
    @statuses = @twitter_response_hash[:statuses]&.select do |s|
      !s.dig(:user, :id).nil?
    end
    @meta[:statuses_count_without_user_id] =
      @twitter_response_hash[:statuses].count - @statuses.count
    !@statuses.nil? && @meta[:statuses_count_without_user_id].zero?
  end

  # Expectations

  def expect_empty_search
    @statuses.empty?
  end

  def expect_successful_search
    users_without_screen_name =
      @statuses.select { |s| s.dig(:user, :screen_name).nil? }.tap do |statuses|
        @meta[:user_ids_without_screen_name] = statuses.map { |s| s.dig(:user, :id) }
      end
    users_without_followers_count =
      @statuses.select { |s| s.dig(:user, :followers_count).nil? }.tap do |statuses|
        @meta[:user_ids_without_followers_count] = statuses.map { |s| s.dig(:user, :id) }
      end

    users_without_screen_name.empty? && users_without_followers_count.empty?
  end
end

def run_search
  response = nil
  puts "Enter Twitter access string (login, access_token, access_token_secret, consumer_key, consumer_secret) joined by `::`"
  access_string = STDIN.noecho(&:gets).chomp
  access_data = access_string.split("::")
  keys = %i(login access_token access_token_secret consumer_key consumer_secret)
  credentials = Hash[keys.zip(access_data)]

  twitter_search = TwitterSearch.new(credentials)

  puts "Enter TwitterSearch query:"
  search_query = gets.chomp

  TwitterContract.new.match!(search_query) do
    response = twitter_search.call(search_query)
  end

  puts JSON.pretty_generate(response)
end
