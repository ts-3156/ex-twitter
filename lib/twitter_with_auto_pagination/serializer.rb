module TwitterWithAutoPagination
  class Serializer
    class << self
      def encode(obj, options = {})
        instrument(options) do
          (!!obj == obj) ? obj : coder.encode(obj)
        end
      end

      def decode(str, options = {})
        instrument(options) do
          str.kind_of?(String) ? coder.decode(str) : str
        end
      end

      def coder
        @@coder ||= JsonCoder.new(JSON)
      end

      def coder=(coder)
        @@coder = Coder.instance(coder)
      end

      private

      def instrument(options, &block)
        parent = caller[0][/`([^']*)'/, 1]
        payload = {operation: parent, args: options[:args]}
        ActiveSupport::Notifications.instrument("#{payload[:operation]}.twitter", payload) { yield(payload) }
      end
    end

    class Coder
      def initialize(coder)
        @coder = coder
      end

      def encode(obj)
        @coder.dump(obj)
      end

      def self.instance(coder)
        if coder == JSON
          JsonCoder.new(coder)
        elsif defined?(Oj) && coder == Oj
          OjCoder.new(coder)
        else
          raise "Invalid coder #{coder}"
        end
      end
    end

    class JsonCoder < Coder
      def decode(str)
        @coder.parse(str, symbolize_names: true)
      end
    end

    class OjCoder < Coder
      def decode(str)
        @coder.load(str, symbol_keys: true)
      end
    end
  end
end