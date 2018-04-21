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
  # @example
  #
  def call(*args, **kwargs)
    @input = { args: args, kwargs: kwargs }
    @output = yield
    @meta = { checked: [] }
    match_guarantees!
    match_expectations!
  rescue GuaranteesError, ExpectationsError
    raise
  rescue StandardError
    # use logger here
    puts "Unexpected error, meta: #{@meta.inspect}"
    raise
  end
  alias :match! :call

  private

  class GuaranteesError < StandardError; end
  def match_guarantees!
    return if self.class.private_instance_methods
      .select { |method_name| method_name.to_s.start_with?("guarantee_")  }
      .all? do |method_name|
        @meta[:checked] << method_name
        send(method_name)
      end
    raise GuaranteesError, @meta
  end

  class ExpectationsError < StandardError; end
  def match_expectations!
    return if self.class.private_instance_methods
      .select { |method_name| method_name.to_s.start_with?("expect_")  }
      .any? do |method_name|
        @meta[:checked] << method_name
        send(method_name)
      end
    raise ExpectationsError, @meta
  end
end
