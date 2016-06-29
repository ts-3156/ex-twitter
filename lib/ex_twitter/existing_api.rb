module ExTwitter
  module ExistingApi
    def verify_credentials(*args)
      options = {skip_status: true}.merge(args.extract_options!)
      fetch_cache_or_call_api(__method__, args) {
        call_old_method("old_#{__method__}", *args, options)
      }
    end

    def friendship?(*args)
      options = args.extract_options!
      fetch_cache_or_call_api(__method__, args) {
        call_old_method("old_#{__method__}", *args, options)
      }
    end

    def user?(*args)
      options = args.extract_options!
      args[0] = verify_credentials(skip_status: true).id if args.empty?
      fetch_cache_or_call_api(__method__, args[0], options) {
        call_old_method("old_#{__method__}", args[0], options)
      }
    end

    def user(*args)
      options = args.extract_options!
      args[0] = verify_credentials(skip_status: true).id if args.empty?
      fetch_cache_or_call_api(__method__, args[0], options) {
        call_old_method("old_#{__method__}", args[0], options)
      }
    end

    def friend_ids(*args)
      options = {count: 5000, cursor: -1}.merge(args.extract_options!)
      args[0] = verify_credentials(skip_status: true).id if args.empty?
      fetch_cache_or_call_api(__method__, args[0], options) {
        collect_with_cursor("old_#{__method__}", *args, options)
      }
    end

    def follower_ids(*args)
      options = {count: 5000, cursor: -1}.merge(args.extract_options!)
      args[0] = verify_credentials(skip_status: true).id if args.empty?
      fetch_cache_or_call_api(__method__, args[0], options) {
        collect_with_cursor("old_#{__method__}", *args, options)
      }
    end

    # specify reduce: false to use tweet for inactive_*
    def friends(*args)
      options = {count: 200, include_user_entities: true, cursor: -1}.merge(args.extract_options!)
      options[:reduce] = false unless options.has_key?(:reduce)
      args[0] = verify_credentials(skip_status: true).id if args.empty?
      fetch_cache_or_call_api(__method__, args[0], options) {
        collect_with_cursor("old_#{__method__}", *args, options)
      }
    end

    # specify reduce: false to use tweet for inactive_*
    def followers(*args)
      options = {count: 200, include_user_entities: true, cursor: -1}.merge(args.extract_options!)
      options[:reduce] = false unless options.has_key?(:reduce)
      args[0] = verify_credentials(skip_status: true).id if args.empty?
      fetch_cache_or_call_api(__method__, args[0], options) {
        collect_with_cursor("old_#{__method__}", *args, options)
      }
    end

    # use compact, not use sort and uniq
    # specify reduce: false to use tweet for inactive_*
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
    rescue => e # debug
      logger.warn "#{__method__}: #{args.inspect} #{e.class} #{e.message}"
      raise e
    end

    def home_timeline(*args)
      options = {count: 200, include_rts: true, call_limit: 3}.merge(args.extract_options!)
      fetch_cache_or_call_api(__method__, user.screen_name, options) {
        collect_with_max_id("old_#{__method__}", options)
      }
    end

    def user_timeline(*args)
      options = {count: 200, include_rts: true, call_limit: 3}.merge(args.extract_options!)
      args[0] = verify_credentials(skip_status: true).id if args.empty?
      fetch_cache_or_call_api(__method__, args[0], options) {
        collect_with_max_id("old_#{__method__}", *args, options)
      }
    end

    def mentions_timeline(*args)
      options = {count: 200, include_rts: true, call_limit: 1}.merge(args.extract_options!)
      fetch_cache_or_call_api(__method__, user.screen_name, options) {
        collect_with_max_id("old_#{__method__}", options)
      }
    end

    def favorites(*args)
      options = {count: 100, call_count: 1}.merge(args.extract_options!)
      args[0] = verify_credentials(skip_status: true).id if args.empty?
      fetch_cache_or_call_api(__method__, args[0], options) {
        collect_with_max_id("old_#{__method__}", *args, options)
      }
    end

    def search(*args)
      options = {count: 100, result_type: :recent, call_limit: 1}.merge(args.extract_options!)
      options[:reduce] = false
      fetch_cache_or_call_api(__method__, args[0], options) {
        collect_with_max_id("old_#{__method__}", *args, options) { |response| response.attrs[:statuses] }
      }
    end
  end
end