require 'twitter_with_auto_pagination/rest/utils'
require 'parallel'

module TwitterWithAutoPagination
  module REST
    module Users
      include TwitterWithAutoPagination::REST::Utils

      def verify_credentials(options = {})
        twitter.send(__method__, {skip_status: true}.merge(options)).to_hash
      end

      def user?(*args)
        twitter.send(__method__, *args)
      end

      def user(*args)
        twitter.send(__method__, *args).to_hash
      end

      MAX_USERS_PER_REQUEST = 100

      # client.users         -> cached
      # users(internal call) -> cached
      # super                -> not cached
      def users(values, options = {})
        if values.size <= MAX_USERS_PER_REQUEST
          return twitter.send(__method__, *values, options).map(&:to_hash)
        end

        users_internal(values, options)
      end

      def blocked_ids(*args)
        twitter.send(__method__, *args).attrs[:ids]
      end

      private

      def users_internal(values, options = {})
        options = options.merge(super_operation: :users)

        parallel(in_threads: 10) do |batch|
          values.each_slice(MAX_USERS_PER_REQUEST) { |targets| batch.users(targets, options) }
        end.flatten
      end
    end
  end
end
