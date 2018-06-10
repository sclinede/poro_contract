# Plain Old Ruby Object Implementation of Contract
### (see more Advanced version with Statistics tracking and Sampling, [in the branch `full-toolbox`](https://github.com/sclinede/poro_contract/tree/full-toolbox))

This project contains the most simple implementation of Contract written in Ruby (and maybe later in other languages).

The Contract is inspired by Design by Contracts approach and pushes Fail Fast techinque further.

So, Contract is a class with the only public method (POROContract#match!), that validates some action/behavior agains Contract Rules:
 - Guarantees - the rules that SHOULD be valid for each check of behavior
 - Expectations - list of all expected states that COULD be valid for the behavior check

Contract validates, that:
 - ALL Guarantees were met
 - AT LEAST ONE Expectations was met

Otherwise, Contract raises an exception with details, at least on what step behavior was broken.

```ruby
class TwitterContract < POROContract
  private

  # Guarantees

  def guarantee_hash_response
    @meta[:response_type] = @twitter_response.class.to_s
    return unless @twitter_response.respond_to?(:to_hash)
    @twitter_response = @twitter_response.to_hash
    true
  end

  def guarantee_non_empty_json_response_body
    @meta[:response_body] = @twitter_response["body"].to_s
    return if (data = JSON.parse(@twitter_response["body"])).empty?
    @meta["response_data"] = data
    true
  end

  # Expectations

  def expect_client_error_response_code
    @meta[:response_code] = @twitter_response["code"]
    (400..499).include?(@twitter_response["code"].to_i)
  end

  def expect_server_error_response_code
    @meta[:response_code] = @twitter_response["code"]
    (500..599).include?(@twitter_response["code"].to_i)
  end

  def expect_full_response_data
    @meta[:response_code] = @twitter_response["code"]
    return unless (200..299).include?(@twitter_response["code"].to_i)
    retweet_data = @meta["response_data"].to_h
      .values_at("id", "favorite_count","retweeted_status").compact
    @meta[:retweet_data_sample] = retweet_data
    retweet_data.size.eql?(3)
  end
end

response = nil

TwitterContract.new.match! { response = TwitterSearch.call("anycable/anycable") }

# So the only way to get here is to pass the Contract validation.
# Otherwise, you'll get a detailed exception what was wrong.
puts response
```
