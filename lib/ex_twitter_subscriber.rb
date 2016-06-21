require 'active_support'
require 'active_support/subscriber'

class ExTwitterSubscriber < ActiveSupport::Subscriber
  def call(event)
    puts "#{event.payload[:name]} #{event.duration} ms"
  end
end
