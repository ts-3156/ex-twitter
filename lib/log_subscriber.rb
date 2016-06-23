require 'active_support'
require 'active_support/core_ext'


class LogSubscriber < ActiveSupport::LogSubscriber
  IGNORE_PAYLOAD_NAMES = ["SCHEMA", "EXPLAIN"]

  def initialize
    super
    @odd = false
  end

  def call(event)
    return unless logger.debug?

    payload = event.payload

    name  = "#{payload.delete(:operation)} (#{event.duration.round(1)}ms)"
    # sql   = payload[:sql]

    name = colorize_payload_name(name, payload[:name])
    # sql  = color(sql, sql_color(sql), true)

    key = payload.delete(:key)
    debug { "#{name}: #{key} #{(payload.inspect)}" }
  end

  private

  def colorize_payload_name(name, payload_name)
    if payload_name.blank? || payload_name == "SQL" # SQL vs Model Load/Exists
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
    ExTwitter.logger
  end
end

