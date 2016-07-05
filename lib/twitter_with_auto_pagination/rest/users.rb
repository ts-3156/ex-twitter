require 'twitter_with_auto_pagination/rest/utils'

module TwitterWithAutoPagination
  module REST
    module Users
      include TwitterWithAutoPagination::REST::Utils

      def verify_credentials(*args)
        options = {skip_status: true}.merge(args.extract_options!)
        fetch_cache_or_call_api(__method__, args) {
          call_old_method("old_#{__method__}", *args, options)
        }
      end

      def user?(*args)
        options = args.extract_options!

        args[0] = verify_credentials(skip_status: true).id if args.empty?
        fetch_cache_or_call_api(__method__, args[0], options) {
          call_api(__method__, args[0], options) { super(args[0], options) }
          # call_old_method("old_#{__method__}", args[0], options)
        }
      end

      def user(*args)
        options = args.extract_options!
        args[0] = verify_credentials(skip_status: true).id if args.empty?
        fetch_cache_or_call_api(__method__, args[0], options) {
          call_old_method("old_#{__method__}", args[0], options)
        }
      end

      # use compact, not use sort and uniq
      # specify reduce: false to use tweet for inactive_*
      # TODO Perhaps `old_users` automatically merges result...
      def users(*args)
        options = args.extract_options!
        options[:reduce] = false
        users_per_workers = args.first.compact.each_slice(100).to_a
        processed_users = []

        Parallel.each_with_index(users_per_workers, in_threads: [users_per_workers.size, 10].min) do |users_per_worker, i|
          _users = fetch_cache_or_call_api(__method__, users_per_worker, options) {
            call_old_method("old_#{__method__}", users_per_worker, options)
          }

          processed_users << {i: i, users: _users}
        end

        processed_users.sort_by{|p| p[:i] }.map{|p| p[:users] }.flatten.compact
      end
    end
  end
end