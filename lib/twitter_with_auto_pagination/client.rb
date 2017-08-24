require 'forwardable'

require 'twitter_with_auto_pagination/logger'
require 'twitter_with_auto_pagination/cache'
require 'twitter_with_auto_pagination/log_subscriber'
require 'twitter_with_auto_pagination/analysis/api'
require 'twitter_with_auto_pagination/rest/api'
require 'twitter_with_auto_pagination/rate_limit'
require 'twitter_with_auto_pagination/parallel'

module TwitterWithAutoPagination
  class Client
    extend Forwardable

    attr_reader :cache, :twitter

    def_delegators :@twitter, :perform_get, :access_token, :access_token_secret, :consumer_key, :consumer_secret

    include TwitterWithAutoPagination::RateLimit
    include TwitterWithAutoPagination::Parallel
    include TwitterWithAutoPagination::REST::API
    include TwitterWithAutoPagination::Analysis::API

    def initialize(*args)
      options = args.extract_options!

      @cache = TwitterWithAutoPagination::Cache.new
      Logging.logger = logger = TwitterWithAutoPagination::Logger.new(options)

      unless subscriber_attached?
        @@subscriber_attached = true
        if logger.debug?
          # Super slow
          TwitterWithAutoPagination::AllLogSubscriber.attach_to :twitter
          TwitterWithAutoPagination::ASLogSubscriber.attach_to :active_support
        elsif logger.info?
          TwitterWithAutoPagination::ApiCallLogSubscriber.attach_to :twitter
        end
      end

      @twitter = Twitter::REST::Client.new(options)
    end

    def self.logger
      Logging.logger
    end

    def subscriber_attached?
      @@subscriber_attached ||= false
    end

    # Deprecated
    def call_count
      -1
    end
  end
end