require_relative 'sampler.rb'
require_relative 'statistics.rb'

# Base class for writting contracts.
# the only public method is POROContract#call (or alias POROContract#match!)
#
# The purpose is to validate some action against your expectations.
# There are 2 kind of them:
# - Guarantee - state that SHOULD be recognized for after every the actions
# - Expectation - state that COULD be recognized after the action
#
# The key behavior is:
# - First verify that all Guarantees are met, then
# - Then move to Expectation and verify that at least one of them met.
# - If any of those checks fail - we should recieve detailed exception - why.
#
# There are 2 kind of exceptions:
# - GuaranteeError - happens if one of the Guarantees failes
# - ExpectationsError - happens if none of Expextations were meet.
#
# Both of them raise with the @meta object, which contains extra debugging info.
class POROContract
  attr_reader :logger, :sampler, :stats
  def initialize(logger: nil, period: nil)
    contract_name = self.class.name
    @sampler = Sampler.new(self, period)
    @stats = Statistics.new(contract_name, logger)
  end

  def serialize
    Marshal.dump(input: @input, output: @output, meta: @meta)
  end

  def deserialize(state_dump)
    Marshal.load(state_dump)
  end

  def call(*args, **kwargs)
    @meta = { checked: [] }
    return yield unless enabled?
    @input = { args: args, kwargs: kwargs }
    @output = yield
    match_guarantees!
    match_expectations!
  rescue GuaranteesError => error
    stats.store_guarantee_failure(error, meta_with_sample(:guarantee_failure))
    raise
  rescue ExpectationsError => error
    stats.store_expectation_failure(error, meta_with_sample(:expectation_failure))
    raise
  rescue StandardError => error
    stats.store_unexpected_error(error, meta_with_sample(:unexpected_error))
    raise
  end
  alias :match! :call

  private

  def meta_with_sample(rule)
    @meta.merge!(input: @input)
    if sampler.need_sample?(rule)
      @meta.merge(sample_path: sampler.sample(rule))
    else
      @meta
    end
  end

  def enabled?
    !!ENV["CONTRACT_#{self.class.name}"]
  end

  class GuaranteesError < StandardError; end
  def match_guarantees!
    return if self.class.private_instance_methods
      .select { |method_name| method_name.to_s.start_with?("guarantee_")  }
      .all? do |method_name|
        @meta[:checked] << method_name
        !!send(method_name)
      end
    raise GuaranteesError, @meta
  end

  class ExpectationsError < StandardError; end
  def match_expectations!
    return if self.class.private_instance_methods
      .select { |method_name| method_name.to_s.start_with?("expect_")  }
      .any? do |method_name|
        @meta[:checked] << method_name
        next unless !!send(method_name)
        stats.store_match(method_name, meta_with_sample(method_name))
        true
      end
    raise ExpectationsError, @meta
  end
end
