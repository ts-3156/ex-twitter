module Utils
  # for backward compatibility
  def uid
    @uid
  end

  def __uid
    @uid
  end

  def __uid_i
    @uid.to_i
  end

  # for backward compatibility
  def screen_name
    @screen_name
  end

  def __screen_name
    @screen_name
  end

  def instrument(operation, key, options = nil)
    payload = {operation: operation, key: key}
    payload.merge!(options) if options.is_a?(Hash)
    ActiveSupport::Notifications.instrument('call.ex_twitter', payload) { yield(payload) }
  end

  def call_old_method(method_name, *args)
    options = args.extract_options!
    begin
      self.call_count += 1
      _options = {method_name: method_name, call_count: self.call_count, args: args}.merge(options)
      instrument('api call', args[0], _options) { send(method_name, *args, options) }
    rescue Twitter::Error::TooManyRequests => e
      logger.warn "#{__method__}: call=#{method_name} #{args.inspect} #{e.class} Retry after #{e.rate_limit.reset_in} seconds."
      raise e
    rescue Twitter::Error::ServiceUnavailable => e
      logger.warn "#{__method__}: call=#{method_name} #{args.inspect} #{e.class} #{e.message}"
      raise e
    rescue Twitter::Error::InternalServerError => e
      logger.warn "#{__method__}: call=#{method_name} #{args.inspect} #{e.class} #{e.message}"
      raise e
    rescue Twitter::Error::Forbidden => e
      logger.warn "#{__method__}: call=#{method_name} #{args.inspect} #{e.class} #{e.message}"
      raise e
    rescue Twitter::Error::NotFound => e
      logger.warn "#{__method__}: call=#{method_name} #{args.inspect} #{e.class} #{e.message}"
      raise e
    rescue => e
      logger.warn "#{__method__}: call=#{method_name} #{args.inspect} #{e.class} #{e.message}"
      raise e
    end
  end

  # user_timeline, search
  def collect_with_max_id(method_name, *args)
    options = args.extract_options!
    options[:call_count] = 3 unless options.has_key?(:call_count)
    last_response = call_old_method(method_name, *args, options)
    last_response = yield(last_response) if block_given?
    return_data = last_response
    call_count = 1

    while last_response.any? && call_count < options[:call_count]
      options[:max_id] = last_response.last.kind_of?(Hash) ? last_response.last[:id] : last_response.last.id
      last_response = call_old_method(method_name, *args, options)
      last_response = yield(last_response) if block_given?
      return_data += last_response
      call_count += 1
    end

    return_data.flatten
  end

  # friends, followers
  def collect_with_cursor(method_name, *args)
    options = args.extract_options!
    last_response = call_old_method(method_name, *args, options).attrs
    return_data = (last_response[:users] || last_response[:ids])

    while (next_cursor = last_response[:next_cursor]) && next_cursor != 0
      options[:cursor] = next_cursor
      last_response = call_old_method(method_name, *args, options).attrs
      return_data += (last_response[:users] || last_response[:ids])
    end

    return_data
  end

  require 'digest/md5'

  # currently ignore options
  def file_cache_key(method_name, user)
    delim = ':'
    identifier =
      case
        when method_name == :search
          "str#{delim}#{user.to_s}"
        when method_name == :mentions_timeline
          "myself#{delim}#{user.to_s}"
        when method_name == :home_timeline
          "myself#{delim}#{user.to_s}"
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
        else raise "#{method_name.inspect} #{user.inspect}"
      end

    "#{method_name}#{delim}#{identifier}"
  end

  def namespaced_key(method_name, user)
    file_cache_key(method_name, user)
  end

  PROFILE_SAVE_KEYS = %i(
      id
      name
      screen_name
      location
      description
      url
      protected
      followers_count
      friends_count
      listed_count
      favourites_count
      utc_offset
      time_zone
      geo_enabled
      verified
      statuses_count
      lang
      status
      profile_image_url_https
      profile_banner_url
      profile_link_color
      suspended
      verified
      entities
      created_at
    )

  STATUS_SAVE_KEYS = %i(
    created_at
    id
    text
    source
    truncated
    coordinates
    place
    entities
    user
    contributors
    is_quote_status
    retweet_count
    favorite_count
    favorited
    retweeted
    possibly_sensitive
    lang
  )

  # encode
  def encode_json(obj, caller_name, options = {})
    options[:reduce] = true unless options.has_key?(:reduce)
    result =
      case caller_name
        when :user_timeline, :home_timeline, :mentions_timeline, :favorites # Twitter::Tweet
          JSON.pretty_generate(obj.map { |o| o.attrs })

        when :search # Hash
          data =
            if options[:reduce]
              obj.map { |o| o.to_hash.slice(*STATUS_SAVE_KEYS) }
            else
              obj.map { |o| o.to_hash }
            end
          JSON.pretty_generate(data)

        when :friends, :followers # Hash
          data =
            if options[:reduce]
              obj.map { |o| o.to_hash.slice(*PROFILE_SAVE_KEYS) }
            else
              obj.map { |o| o.to_hash }
            end
          JSON.pretty_generate(data)

        when :friend_ids, :follower_ids # Integer
          JSON.pretty_generate(obj)

        when :user # Twitter::User
          JSON.pretty_generate(obj.to_hash.slice(*PROFILE_SAVE_KEYS))

        when :users, :friends_advanced, :followers_advanced # Twitter::User
          data =
            if options[:reduce]
              obj.map { |o| o.to_hash.slice(*PROFILE_SAVE_KEYS) }
            else
              obj.map { |o| o.to_hash }
            end
          JSON.pretty_generate(data)

        when :user? # true or false
          obj

        when :friendship? # true or false
          obj

        else
          raise "#{__method__}: caller=#{caller_name} key=#{options[:key]} obj=#{obj.inspect}"
      end
    result
  end

  # decode
  def decode_json(json_str, caller_name, options = {})
    obj = json_str.kind_of?(String) ? JSON.parse(json_str) : json_str
    result =
      case
        when obj.nil?
          obj

        when obj.kind_of?(Array) && obj.first.kind_of?(Hash)
          obj.map { |o| Hashie::Mash.new(o) }

        when obj.kind_of?(Array) && obj.first.kind_of?(Integer)
          obj

        when obj.kind_of?(Hash)
          Hashie::Mash.new(obj)

        when obj === true || obj === false
          obj

        when obj.kind_of?(Array) && obj.empty?
          obj

        else
          raise "#{__method__}: caller=#{caller_name} key=#{options[:key]} obj=#{obj.inspect}"
      end
    result
  end

  def fetch_cache_or_call_api(method_name, user, options = {})
    key = namespaced_key(method_name, user)
    options.update(key: key)

    data =
      if options[:cache] == :read
        instrument('Cache Read(Force)', key, caller: method_name) { cache.read(key) }
      else
        if block_given?
          cache.fetch(key, expires_in: 1.hour, race_condition_ttl: 5.minutes) do
            _d = yield
            instrument('serialize', key, caller: method_name) { encode_json(_d, method_name, options) }
          end
        else
          instrument('read', key, caller: method_name, hit: cache.exist?(key)) { cache.read(key) }
        end
      end

    instrument('deserialize', key, caller: method_name) { decode_json(data, method_name, options) }
  end
end