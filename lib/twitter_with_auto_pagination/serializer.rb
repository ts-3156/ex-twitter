module TwitterWithAutoPagination
  class Serializer
    CODER = JSON

    class << self
      def encode(obj, options = {})
        instrument(options) do
          (!!obj == obj) ? obj : CODER.dump(obj)
        end
      end

      def decode(str, options = {})
        instrument(options) do
          str.kind_of?(String) ? CODER.parse(str, symbolize_names: true) : str
        end
      end

      private

      def instrument(options, &block)
        parent = caller[0][/`([^']*)'/, 1]
        payload = {operation: parent, args: options[:args]}
        ActiveSupport::Notifications.instrument("#{payload[:operation]}.twitter", payload) { yield(payload) }
      end
    end
  end
end