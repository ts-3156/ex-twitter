module ExistingApi
  def friendship?(*args)
    options = args.extract_options!
    fetch_cache_or_call_api(:friendship?, args) {
      call_old_method(:old_friendship?, *args, options)
    }
  end

  def user?(*args)
    raise 'this method needs at least one param to use cache' if args.empty?
    options = args.extract_options!
    fetch_cache_or_call_api(:user?, args[0], options) {
      call_old_method(:old_user?, args[0], options)
    }
  end

  def user(*args)
    raise 'this method needs at least one param to use cache' if args.empty?
    options = args.extract_options!
    fetch_cache_or_call_api(:user, args[0], options) {
      call_old_method(:old_user, args[0], options)
    }
  rescue => e
    logger.warn "#{__method__} #{args.inspect} #{e.class} #{e.message}"
    raise e
  end

  def friend_ids(*args)
    raise 'this method needs at least one param to use cache' if args.empty?
    options = args.extract_options!
    fetch_cache_or_call_api(:friend_ids, args[0], options) {
      options = {count: 5000, cursor: -1}.merge(options)
      collect_with_cursor(:old_friend_ids, *args, options)
    }
  end

  def follower_ids(*args)
    raise 'this method needs at least one param to use cache' if args.empty?
    options = args.extract_options!
    fetch_cache_or_call_api(:follower_ids, args[0], options) {
      options = {count: 5000, cursor: -1}.merge(options)
      collect_with_cursor(:old_follower_ids, *args, options)
    }
  end

  # specify reduce: false to use tweet for inactive_*
  def friends(*args)
    raise 'this method needs at least one param to use cache' if args.empty?
    options = args.extract_options!
    options[:reduce] = false unless options.has_key?(:reduce)
    fetch_cache_or_call_api(:friends, args[0], options) {
      options = {count: 200, include_user_entities: true, cursor: -1}.merge(options)
      collect_with_cursor(:old_friends, *args, options)
    }
  end

  # specify reduce: false to use tweet for inactive_*
  def followers(*args)
    raise 'this method needs at least one param to use cache' if args.empty?
    options = args.extract_options!
    options[:reduce] = false unless options.has_key?(:reduce)
    fetch_cache_or_call_api(:followers, args[0], options) {
      options = {count: 200, include_user_entities: true, cursor: -1}.merge(options)
      collect_with_cursor(:old_followers, *args, options)
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
      _users = fetch_cache_or_call_api(:users, users_per_worker, options) {
        call_old_method(:old_users, users_per_worker, options)
      }

      result = {i: i, users: _users}
      processed_users << result
    end

    processed_users.sort_by{|p| p[:i] }.map{|p| p[:users] }.flatten.compact
  rescue => e
    logger.warn "#{__method__} #{args.inspect} #{e.class} #{e.message}"
    raise e
  end

  def _called_by_authenticated_user?(user)
    authenticated_user = self.old_user; self.call_count += 1
    if user.kind_of?(String)
      authenticated_user.screen_name == user
    elsif user.kind_of?(Integer)
      authenticated_user.id.to_i == user
    else
      raise user.inspect
    end
  rescue => e
    logger.warn "#{__method__} #{user.inspect} #{e.class} #{e.message}"
    raise e
  end

  # can't get tweets if you are not authenticated by specified user
  def home_timeline(*args)
    raise 'this method needs at least one param to use cache' if args.empty?
    raise 'this method must be called by authenticated user' unless _called_by_authenticated_user?(args[0])
    options = args.extract_options!
    fetch_cache_or_call_api(:home_timeline, args[0], options) {
      options = {count: 200, include_rts: true, call_count: 3}.merge(options)
      collect_with_max_id(:old_home_timeline, options)
    }
  end

  # can't get tweets if you are not authenticated by specified user
  def user_timeline(*args)
    raise 'this method needs at least one param to use cache' if args.empty?
    options = args.extract_options!
    fetch_cache_or_call_api(:user_timeline, args[0], options) {
      options = {count: 200, include_rts: true, call_count: 3}.merge(options)
      collect_with_max_id(:old_user_timeline, *args, options)
    }
  end

  # can't get tweets if you are not authenticated by specified user
  def mentions_timeline(*args)
    raise 'this method needs at least one param to use cache' if args.empty?
    raise 'this method must be called by authenticated user' unless _called_by_authenticated_user?(args[0])
    options = args.extract_options!
    fetch_cache_or_call_api(:mentions_timeline, args[0], options) {
      options = {count: 200, include_rts: true, call_count: 1}.merge(options)
      collect_with_max_id(:old_mentions_timeline, options)
    }
  rescue => e
    logger.warn "#{__method__} #{args.inspect} #{e.class} #{e.message}"
    raise e
  end

  def search(*args)
    raise 'this method needs at least one param to use cache' if args.empty?
    options = args.extract_options!
    options[:reduce] = false
    fetch_cache_or_call_api(:search, args[0], options) {
      options = {count: 100, result_type: :recent, call_count: 1}.merge(options)
      collect_with_max_id(:old_search, *args, options) { |response| response.attrs[:statuses] }
    }
  rescue => e
    logger.warn "#{__method__} #{args.inspect} #{e.class} #{e.message}"
    raise e
  end

  def favorites(*args)
    raise 'this method needs at least one param to use cache' if args.empty?
    options = args.extract_options!
    fetch_cache_or_call_api(:favorites, args[0], options) {
      options = {count: 100, call_count: 1}.merge(options)
      collect_with_max_id(:old_favorites, *args, options)
    }
  end
end