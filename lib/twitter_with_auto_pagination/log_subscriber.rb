module TwitterWithAutoPagination
  module Logging
    def truncated_payload(payload)
      return payload.inspect if !payload.has_key?(:args) || !payload[:args].is_a?(Array) || payload[:args].empty? || !payload[:args][0].is_a?(Array)

      args = payload[:args].dup
      args[0] =
        if args[0].size > 3
          "[#{args[0].take(3).join(', ')} ... #{args[0].size}]"
        else
          args[0].inspect
        end

      {args: args}.merge(payload.except(:args)).inspect
    end

    module_function

    def logger
      @@logger
    end

    def logger=(logger)
      @@logger = logger
    end
  end

  class ApiCallLogSubscriber < ActiveSupport::LogSubscriber
    include Logging

    def api_call(event)
      payload = event.payload
      name = "TW::#{payload.delete(:operation)} (#{event.duration.round(1)}ms)"
      name = color(name, YELLOW, true) # WHITE, RED, GREEN, BLUE, CYAN, MAGENTA, YELLOW
      info { "#{name}#{" #{truncated_payload(payload)}" unless payload.empty?}" }
    end
  end

  class AllLogSubscriber < ApiCallLogSubscriber
    include Logging

    def api_call(*args)
      super
    end

    def twitter_any(event)
      payload = event.payload
      payload.delete(:name)
      name = "TW::#{payload.delete(:operation)} (#{event.duration.round(1)}ms)"
      name = color(name, CYAN, true) # WHITE, RED, GREEN, BLUE, CYAN, MAGENTA, YELLOW
      debug { "#{name}#{" #{truncated_payload(payload)}" unless payload.empty?}" }
    end

    %w(request encode decode).each do |operation|
      class_eval <<-METHOD, __FILE__, __LINE__ + 1
        def #{operation}(event)
          event.payload[:name] = '#{operation}'
          twitter_any(event)
        end
      METHOD
    end
  end

  class ASLogSubscriber < ActiveSupport::LogSubscriber
    def cache_any(event)
      return unless logger.debug?

      payload = event.payload
      name = "AS::#{payload[:name]} (#{event.duration.round(1)}ms)"
      name = color(name, MAGENTA, true)
      debug { "#{name} #{(payload.except(:name, :expires_in, :race_condition_ttl).inspect)}" }
    end

    # Ignore generate and fetch_hit
    %w(read write delete exist?).each do |operation|
      class_eval <<-METHOD, __FILE__, __LINE__ + 1
        def cache_#{operation}(event)
          event.payload[:name] = '#{operation}'
          cache_any(event)
        end
      METHOD
    end

    private

    def logger
      Logging.logger
    end
  end
end