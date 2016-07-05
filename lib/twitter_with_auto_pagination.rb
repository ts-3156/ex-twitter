require 'twitter'

require 'twitter_with_auto_pagination/log_subscriber'

module TwitterWithAutoPagination
end

require 'twitter_with_auto_pagination/rest/api'

module Twitter
  module REST
    class Client
      prepend TwitterWithAutoPagination::REST::API

      def initialize(options = {})
        @cache = ActiveSupport::Cache::FileStore.new(File.join('tmp', 'api_cache'))
        @call_count = 0

        @uid = options.has_key?(:uid) ? options.delete(:uid).to_i : nil
        @screen_name = options.has_key?(:screen_name) ? options.delete(:screen_name).to_s : nil

        logger =
          if options.has_key?(:logger)
            options.delete(:logger)
          else
            Dir.mkdir('log') unless File.exists?('log')
            Logger.new('log/twitter_with_auto_pagination.log')
          end
        logger.level = options.has_key?(:log_level) ? options.delete(:log_level) : :debug
        @@logger = @logger = logger

        super
      end

      def self.logger
        @@logger
      end

      attr_accessor :call_count
      attr_reader :cache, :authenticated_user, :logger

      INDENT = 4
    end
  end
end