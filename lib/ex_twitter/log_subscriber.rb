require 'active_support'
require 'active_support/core_ext'


module ExTwitter
  class LogSubscriber < ActiveSupport::LogSubscriber

    def initialize
      super
      @odd = false
    end

    def cache_any(event)
      return unless logger.debug?

      payload = event.payload
      name  = "#{payload.delete(:name)} (#{event.duration.round(1)}ms)"
      name = colorize_payload_name(name, payload[:name], AS: true)
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

    def call(event)
      return unless logger.debug?

      payload = event.payload
      name = "#{payload.delete(:operation)} (#{event.duration.round(1)}ms)"

      name = colorize_payload_name(name, payload[:name])
      # sql  = color(sql, sql_color(sql), true)

      key = payload.delete(:key)
      debug { "#{name} #{key} #{(payload.inspect)}" }
    end

    private

    def colorize_payload_name(name, payload_name, options = {})
      if options[:AS]
        color(name, MAGENTA, true)
      else
        color(name, CYAN, true)
      end
    end

    def sql_color(sql)
      case sql
        when /\A\s*rollback/mi
          RED
        when /select .*for update/mi, /\A\s*lock/mi
          WHITE
        when /\A\s*select/i
          BLUE
        when /\A\s*insert/i
          GREEN
        when /\A\s*update/i
          YELLOW
        when /\A\s*delete/i
          RED
        when /transaction\s*\Z/i
          CYAN
        else
          MAGENTA
      end
    end

    def logger
      ExTwitter::Client.logger
    end
  end
end
