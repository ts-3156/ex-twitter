require 'hashie'
require 'digest/md5'

module TwitterWithAutoPagination
  module REST
    module Utils
      def uid_or_screen_name?(object)
        object.kind_of?(String) || object.kind_of?(Integer)
      end

      def authenticating_user?(target)
        user.id.to_i == user(target).id.to_i
      end

      def authorized_user?(target)
        target_user = user(target)
        !target_user.protected? || friendship?(user.id.to_i, target_user.id.to_i)
      end

      def credentials_hash
        Digest::MD5.hexdigest(access_token + access_token_secret + consumer_key + consumer_secret)
      end

      def instrument(operation, key, options = nil)
        payload = {operation: operation}
        payload.merge!(options) if options.is_a?(Hash)
        ActiveSupport::Notifications.instrument('call.twitter_with_auto_pagination', payload) { yield(payload) }
      end

      def call_api(method, *args)
        api_options = args.extract_options!
        self.call_count += 1
        options = {method: method.name, call_count: self.call_count, args: [*args, api_options]}
        begin
          instrument('request', nil, options) { method.call(*args, api_options) }
        rescue Twitter::Error::TooManyRequests => e
          logger.warn "#{__method__}: #{e.class} #{e.message} Retry after #{e.rate_limit.reset_in} seconds. #{options.inspect}"
          raise e
        rescue Twitter::Error::ServiceUnavailable, Twitter::Error::InternalServerError,
          Twitter::Error::Forbidden, Twitter::Error::NotFound => e
          logger.warn "#{__method__}: #{e.class} #{e.message} #{options.inspect}"
          raise e
        rescue => e
          logger.warn "CATCH ME! #{__method__}: #{e.class} #{e.message} #{options.inspect}"
          raise e
        end
      end

      # user_timeline, search
      def collect_with_max_id(method, *args)
        options = args.extract_options!
        call_limit = options.delete(:call_limit) || 3
        return_data = []
        call_num = 0

        while call_num < call_limit
          last_response = call_api(method, *args, options)
          last_response = yield(last_response) if block_given?
          call_num += 1
          return_data += last_response
          if last_response.nil? || last_response.empty?
            break
          else
            options[:max_id] = last_response.last.kind_of?(Hash) ? last_response.last[:id] : last_response.last.id
          end
        end

        return_data
      end

      # friends, followers
      def collect_with_cursor(method, *args)
        options = args.extract_options!
        call_limit = options.delete(:call_limit) || 30
        return_data = []
        call_num = 0

        while call_num < call_limit
          last_response = call_api(method, *args, options).attrs
          call_num += 1
          return_data += (last_response[:users] || last_response[:ids] || last_response[:lists])
          options[:cursor] = last_response[:next_cursor]
          if options[:cursor].nil? || options[:cursor] == 0
            break
          end
        end

        return_data
      end

      def normalize_key(method, user, options = {})
        delim = ':'
        identifier =
          case
            when method == :verify_credentials
              "token-hash#{delim}#{credentials_hash}"
            when method == :search
              "str#{delim}#{user.to_s}"
            when method == :list_members
              "list_id#{delim}#{user.to_s}"
            when method == :mentions_timeline
              "#{user.kind_of?(Integer) ? 'id' : 'sn'}#{delim}#{user.to_s}"
            when method == :home_timeline
              "#{user.kind_of?(Integer) ? 'id' : 'sn'}#{delim}#{user.to_s}"
            when method.in?([:users, :replying]) && options[:super_operation].present?
              case
                when user.kind_of?(Array) && user.first.kind_of?(Integer)
                  "#{options[:super_operation]}-ids#{delim}#{Digest::MD5.hexdigest(user.join(','))}"
                when user.kind_of?(Array) && user.first.kind_of?(String)
                  "#{options[:super_operation]}-sns#{delim}#{Digest::MD5.hexdigest(user.join(','))}"
                else
                  raise "#{method.inspect} #{user.inspect}"
              end
            when user.kind_of?(Integer)
              "id#{delim}#{user.to_s}"
            when user.kind_of?(Array) && user.first.kind_of?(Integer)
              "ids#{delim}#{Digest::MD5.hexdigest(user.join(','))}"
            when user.kind_of?(Array) && user.first.kind_of?(String)
              "sns#{delim}#{Digest::MD5.hexdigest(user.join(','))}"
            when user.kind_of?(String)
              "sn#{delim}#{user}"
            when user.kind_of?(Twitter::User)
              "user#{delim}#{user.id.to_s}"
            else
              raise "#{method.inspect} #{user.inspect}"
          end

        "#{method}#{delim}#{identifier}"
      end

      CODER = JSON

      def encode(obj)
        obj.in?([true, false]) ? obj : CODER.dump(obj)
      end

      def decode(str)
        obj = str.kind_of?(String) ? CODER.load(str) : str
        to_mash(obj)
      end

      def to_mash(obj)
        case
          when obj.kind_of?(Array)
            obj.map { |o| to_mash(o) }
          when obj.kind_of?(Hash)
            Hashie::Mash.new(obj.map { |k, v| [k, to_mash(v)] }.to_h)
          else
            obj
        end
      end

      def fetch_cache_or_call_api(method, user, options = {})
        key = normalize_key(method, user, options)

        fetch_result =
          cache.fetch(key, expires_in: 1.hour, race_condition_ttl: 5.minutes) do
            block_result = yield
            instrument('serialize', nil, key: key, caller: method) { encode(block_result) }
          end

        instrument('deserialize', nil, key: key, caller: method) { decode(fetch_result) }
      end
    end
  end
end
