module ExTwitter
  module NewApi
    def friends_parallelly(*args)
      options = {super_operation: __method__}.merge(args.extract_options!)
      _friend_ids = friend_ids(*(args + [options]))
      users(_friend_ids.map { |id| id.to_i }, options)
    end

    def followers_parallelly(*args)
      options = {super_operation: __method__}.merge(args.extract_options!)
      _follower_ids = follower_ids(*(args + [options]))
      users(_follower_ids.map { |id| id.to_i }, options)
    end

    def _fetch_parallelly(signatures) # [{method: :friends, args: ['ts_3156', ...], {...}]
      result = Array.new(signatures.size)

      Parallel.each_with_index(signatures, in_threads: result.size) do |signature, i|
        result[i] = send(signature[:method], *signature[:args])
      end

      result
    end

    def friends_and_followers(*args)
      _fetch_parallelly(
        [
          {method: :friends_parallelly, args: args},
          {method: :followers_parallelly, args: args}])
    end

    def friends_followers_and_statuses(*args)
      _fetch_parallelly(
        [
          {method: :friends_parallelly, args: args},
          {method: :followers_parallelly, args: args},
          {method: :user_timeline, args: args}])
    end

    def one_sided_following(me)
      if me.kind_of?(String) || me.kind_of?(Integer)
        # TODO use friends_and_followers
        friends_parallelly(me).to_a - followers_parallelly(me).to_a
      elsif me.respond_to?(:friends) && me.respond_to?(:followers)
        me.friends.to_a - me.followers.to_a
      else
        raise
      end
    end

    def one_sided_followers(me)
      if me.kind_of?(String) || me.kind_of?(Integer)
        # TODO use friends_and_followers
        followers_parallelly(me).to_a - friends_parallelly(me).to_a
      elsif me.respond_to?(:friends) && me.respond_to?(:followers)
        me.followers.to_a - me.friends.to_a
      else
        raise
      end
    end

    def mutual_friends(me)
      if me.kind_of?(String) || me.kind_of?(Integer)
        # TODO use friends_and_followers
        friends_parallelly(me).to_a & followers_parallelly(me).to_a
      elsif me.respond_to?(:friends) && me.respond_to?(:followers)
        me.friends.to_a & me.followers.to_a
      else
        raise
      end
    end

    def common_friends(me, you)
      if (me.kind_of?(String) || me.kind_of?(Integer)) && (you.kind_of?(String) || you.kind_of?(Integer))
        friends_parallelly(me).to_a & friends_parallelly(you).to_a
      elsif me.respond_to?(:friends) && you.respond_to?(:friends)
        me.friends.to_a & you.friends.to_a
      else
        raise
      end
    end

    def common_followers(me, you)
      if (me.kind_of?(String) || me.kind_of?(Integer)) && (you.kind_of?(String) || you.kind_of?(Integer))
        followers_parallelly(me).to_a & followers_parallelly(you).to_a
      elsif me.respond_to?(:followers) && you.respond_to?(:followers)
        me.followers.to_a & you.followers.to_a
      else
        raise
      end
    end

    def removing(pre_me, cur_me)
      if (pre_me.kind_of?(String) || pre_me.kind_of?(Integer)) && (cur_me.kind_of?(String) || cur_me.kind_of?(Integer))
        friends_parallelly(pre_me).to_a - friends_parallelly(cur_me).to_a
      elsif pre_me.respond_to?(:friends) && cur_me.respond_to?(:friends)
        pre_me.friends.to_a - cur_me.friends.to_a
      else
        raise
      end
    end

    def removed(pre_me, cur_me)
      if (pre_me.kind_of?(String) || pre_me.kind_of?(Integer)) && (cur_me.kind_of?(String) || cur_me.kind_of?(Integer))
        followers_parallelly(pre_me).to_a - followers_parallelly(cur_me).to_a
      elsif pre_me.respond_to?(:followers) && cur_me.respond_to?(:followers)
        pre_me.followers.to_a - cur_me.followers.to_a
      else
        raise
      end
    end


  end
end