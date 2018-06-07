require 'json'
require 'logger'

class POROContract
  class Statistics
    TEMPLATE = "[contracts-match] %<payload>s;"

    attr_reader :logger
    def initialize(contract_name, logger)
      @contract_name = contract_name
      @logger = logger || Logger.new(STDOUT)
    end

    def store_match(rule, meta)
      logger.debug { log_data(rule: rule, meta: meta) }
    end

    def store_guarantee_failure(error, meta)
      logger.debug { log_data(rule: :guarantee_failure, meta: meta) }
    end

    def store_expectation_failure(error, meta)
      logger.debug { log_data(rule: :expectation_failure, meta: meta) }
    end

    def store_unexpected_error(error, meta)
      logger.debug { log_data(rule: :unexpected_error, error: error, meta: meta) }
    end

    private

    def log_data(**kwargs)
      TEMPLATE % {payload: payload(**kwargs)}
    end

    def payload(rule:, meta: nil, error: nil)
      JSON.dump({
        time: Time.now, contract_name: @contract_name, rule: rule, meta: meta, error: error,
      }.compact)
    end
  end
end
