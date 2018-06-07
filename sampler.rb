class POROContract
  class Sampler
    ROOT_PATH = File.join("/tmp", "contracts")
    PATH_TEMPLATE = "%<contract_name>s/%<rule>s/%<period>i.dump"
    DEFAULT_PERIOD_SIZE = 60 * 60 # every hour

    attr_reader :contract_name, :period_size, :context
    def initialize(contract, period_size)
      @context = contract
      @contract_name = contract.class.name
      @period_size = period_size || default_period_size
    end

    def sample(rule)
      return unless need_sample?(rule)
      capture(rule)
      sample_path(rule)
    end

    def need_sample?(rule)
      !File.exist?(sample_path(rule))
    end

    def capture(rule)
      FileUtils.mkdir_p(File.dirname(sample_path(rule)))
      File.write(sample_path(rule), context.serialize)
    end

    # to use in interactive Ruby session
    def read(path = nil, rule: nil, period: nil)
      path ||= sample_path(rule, period)
      raise ArgumentError unless path
      context.deserialize(File.read(path))
    end

    def sample_path(rule, period = current_period)
      File.join(
        ROOT_PATH,
        PATH_TEMPLATE % {contract_name: contract_name, rule: rule, period: period}
      )
    end

    private

    def current_period
      Time.now.to_i / (period_size || 1).to_i
    end

    def default_period_size
      ENV["CONTRACT_#{contract_name}_SAMPLE_PERIOD_SIZE"] || DEFAULT_PERIOD_SIZE
    end
  end
end
