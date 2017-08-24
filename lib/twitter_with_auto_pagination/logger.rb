module TwitterWithAutoPagination
  class Logger < ::Logger

    def initialize(options = {})
      Dir.mkdir('log') unless File.exists?('log')
      super('log/twitter.log')
      self.level = options.has_key?(:log_level) ? options.delete(:log_level) : :debug
    end
  end
end