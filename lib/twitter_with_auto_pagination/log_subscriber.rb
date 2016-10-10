module TwitterWithAutoPagination
  class LogSubscriber < ActiveSupport::LogSubscriber

    def initialize
      super
    end

    def call(event)
      return unless logger.debug?

      payload = event.payload
      name = "TW::#{payload.delete(:operation)} (#{event.duration.round(1)}ms)"
      name = color(name, CYAN, true) # WHITE, RED, GREEN, BLUE, CYAN, MAGENTA, YELLOW
      debug { "#{name} #{(payload.inspect)}" }
    end

    private

    def logger
      Twitter::REST::Client.logger
    end
  end

  class ASLogSubscriber < ActiveSupport::LogSubscriber

    def initialize
      super
    end

    def cache_any(event)
      return unless logger.debug?

      payload = event.payload
      name= "AS::#{payload.delete(:name)} (#{event.duration.round(1)}ms)"
      name = color(name, MAGENTA, true)
      debug { "#{name} #{(payload.inspect)}" }
    end

    %w(read write fetch_hit generate delete exist?).each do |operation|
      class_eval <<-METHOD, __FILE__, __LINE__ + 1
          def cache_#{operation}(event)
            event.payload[:name] = '#{operation}'
            cache_any(event)
          end
      METHOD
    end

    private

    def logger
      Twitter::REST::Client.logger
    end
  end
end

TwitterWithAutoPagination::LogSubscriber.attach_to :twitter_with_auto_pagination
TwitterWithAutoPagination::ASLogSubscriber.attach_to :active_support
