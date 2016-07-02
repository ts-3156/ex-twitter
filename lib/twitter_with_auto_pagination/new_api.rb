module TwitterWithAutoPagination
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

    def one_sided_friends(me = nil)
      if me.nil?
        friends_parallelly.to_a - followers_parallelly.to_a
      elsif uid_or_screen_name?(me)
        # TODO use friends_and_followers
        friends_parallelly(me).to_a - followers_parallelly(me).to_a
      elsif me.respond_to?(:friends) && me.respond_to?(:followers)
        me.friends.to_a - me.followers.to_a
      else
        raise
      end
    end

    def one_sided_followers(me = nil)
      if me.nil?
        followers_parallelly.to_a - friends_parallelly.to_a
      elsif uid_or_screen_name?(me)
        # TODO use friends_and_followers
        followers_parallelly(me).to_a - friends_parallelly(me).to_a
      elsif me.respond_to?(:friends) && me.respond_to?(:followers)
        me.followers.to_a - me.friends.to_a
      else
        raise
      end
    end

    def mutual_friends(me = nil)
      if me.nil?
        friends_parallelly.to_a & followers_parallelly.to_a
      elsif uid_or_screen_name?(me)
        # TODO use friends_and_followers
        friends_parallelly(me).to_a & followers_parallelly(me).to_a
      elsif me.respond_to?(:friends) && me.respond_to?(:followers)
        me.friends.to_a & me.followers.to_a
      else
        raise
      end
    end

    def common_friends(me, you)
      if uid_or_screen_name?(me) && uid_or_screen_name?(you)
        friends_parallelly(me).to_a & friends_parallelly(you).to_a
      elsif me.respond_to?(:friends) && you.respond_to?(:friends)
        me.friends.to_a & you.friends.to_a
      else
        raise
      end
    end

    def common_followers(me, you)
      if uid_or_screen_name?(me) && uid_or_screen_name?(you)
        followers_parallelly(me).to_a & followers_parallelly(you).to_a
      elsif me.respond_to?(:followers) && you.respond_to?(:followers)
        me.followers.to_a & you.followers.to_a
      else
        raise
      end
    end

    def removed(pre_me, cur_me)
      if uid_or_screen_name?(pre_me) && uid_or_screen_name?(cur_me)
        friends_parallelly(pre_me).to_a - friends_parallelly(cur_me).to_a
      elsif pre_me.respond_to?(:friends) && cur_me.respond_to?(:friends)
        pre_me.friends.to_a - cur_me.friends.to_a
      else
        raise
      end
    end

    def removed_by(pre_me, cur_me)
      if uid_or_screen_name?(pre_me) && uid_or_screen_name?(cur_me)
        followers_parallelly(pre_me).to_a - followers_parallelly(cur_me).to_a
      elsif pre_me.respond_to?(:followers) && cur_me.respond_to?(:followers)
        pre_me.followers.to_a - cur_me.followers.to_a
      else
        raise
      end
    end

    def _extract_screen_names(tweets)
      tweets.map do |t|
        $1 if t.text =~ /^(?:\.)?@(\w+)( |\W)/ # include statuses starts with .
      end.compact
    end

    # users which specified user is replying
    # in_reply_to_user_id and in_reply_to_status_id is not used because of distinguishing mentions from replies
    def replied(*args)
      options = args.extract_options!
      tweets =
        if args.empty?
          user_timeline(options)
        elsif uid_or_screen_name?(args[0])
          user_timeline(args[0], options)
        elsif args[0].kind_of?(Array) && args[0].all? { |t| t.respond_to?(:text) }
          args[0]
        else
          raise
        end

      screen_names = _extract_screen_names(tweets)
      result = users(screen_names, {super_operation: __method__}.merge(options))
      if options.has_key?(:uniq) && !options[:uniq]
        screen_names.map { |sn| result.find { |r| r.screen_name == sn } }.compact
      else
        result.uniq { |r| r.id }
      end
    rescue Twitter::Error::NotFound => e
      e.message == 'No user matches for specified terms.' ? [] : (raise e)
    rescue => e
      logger.warn "#{__method__} #{args.inspect} #{e.class} #{e.message}"
      raise e
    end

    def _extract_uids(tweets)
      tweets.map do |t|
        t.user.id.to_i if t.text =~ /^(?:\.)?@(\w+)( |\W)/ # include statuses starts with .
      end.compact
    end

    def _extract_users(tweets, uids)
      uids.map { |uid| tweets.find { |t| t.user.id.to_i == uid.to_i } }.map { |t| t.user }.compact
    end

    # users which specified user is replied
    # when user is login you had better to call mentions_timeline
    def replied_by(*args)
      options = args.extract_options!

      result =
        if args.empty? || (uid_or_screen_name?(args[0]) && authenticating_user?(args[0]))
          mentions_timeline.map { |m| m.user }
        else
          searched_result = search('@' + user(args[0]).screen_name, options)
          uids = _extract_uids(searched_result)
          _extract_users(searched_result, uids)
        end

      if options.has_key?(:uniq) && !options[:uniq]
        result
      else
        result.uniq { |r| r.id }
      end
    end

    def _count_users_with_two_sided_threshold(users, options)
      min = options.has_key?(:min) ? options[:min] : 0
      max = options.has_key?(:max) ? options[:max] : 1000
      users.each_with_object(Hash.new(0)) { |u, memo| memo[u.id] += 1 }.
        select { |_k, v| min <= v && v <= max }.
        sort_by { |_, v| -v }.to_h
    end

    def _extract_favorite_users(favs, options = {})
      counted_value = _count_users_with_two_sided_threshold(favs.map { |t| t.user }, options)
      counted_value.map do |uid, cnt|
        fav = favs.find { |f| f.user.id.to_i == uid.to_i }
        Array.new(cnt, fav.user)
      end.flatten
    end

    def users_you_faved(*args)
      options = args.extract_options!

      favs =
        if args.empty?
          favorites(options)
        elsif uid_or_screen_name?(args[0])
          favorites(args[0], options)
        elsif args[0].kind_of?(Array) && args[0].all? { |t| t.respond_to?(:text) }
          args[0]
        else
          raise
        end

      result = _extract_favorite_users(favs, options)
      if options.has_key?(:uniq) && !options[:uniq]
        result
      else
        result.uniq { |r| r.id }
      end
    rescue => e
      logger.warn "#{__method__} #{user.inspect} #{e.class} #{e.message}"
      raise e
    end

    def _extract_inactive_users(users, options = {})
      authorized = options.delete(:authorized)
      two_weeks_ago = 2.weeks.ago.to_i
      users.select do |u|
        if authorized
          (Time.parse(u.status.created_at).to_i < two_weeks_ago) rescue false
        else
          false
        end
      end
    end

    def users_fav_you(*args)
    end

    def close_friends(*args)
      options = {uniq: false}.merge(args.extract_options!)
      min_max = {
        min: options.has_key?(:min) ? options.delete(:min) : 0,
        max: options.has_key?(:max) ? options.delete(:max) : 1000
      }

      _replying, _replied, _favoriting =
        if args.empty?
          [replying(options), replied(options), favoriting(options)]
        elsif uid_or_screen_name?(args[0])
          [replying(args[0], options), replied(args[0], options), favoriting(args[0], options)]
        elsif (m_names = %i(replying replied favoriting)).all? { |m_name| args[0].respond_to?(m_name) }
          m_names.map { |mn| args[0].send(mn) }
        else
          raise
        end

      _users = _replying + _replied + _favoriting
      return [] if _users.empty?

      scores = _count_users_with_two_sided_threshold(_users, min_max)
      replying_scores = _count_users_with_two_sided_threshold(_replying, min_max)
      replied_scores = _count_users_with_two_sided_threshold(_replied, min_max)
      favoriting_scores = _count_users_with_two_sided_threshold(_favoriting, min_max)

      scores.keys.map { |uid| _users.find { |u| u.id.to_i == uid.to_i } }.
        map do |u|
        u[:score] = scores[u.id]
        u[:replying_score] = replying_scores[u.id]
        u[:replied_score] = replied_scores[u.id]
        u[:favoriting_score] = favoriting_scores[u.id]
        u
      end
    end

    def inactive_friends(user = nil)
      if user.blank?
        _extract_inactive_users(friends_parallelly, authorized: true)
      elsif uid_or_screen_name?(user)
        authorized = authenticating_user?(user) || authorized_user?(user)
        _extract_inactive_users(friends_parallelly(user), authorized: authorized)
      elsif user.respond_to?(:friends)
        authorized = authenticating_user?(user.uid.to_i) || authorized_user?(user.uid.to_i)
        _extract_inactive_users(user.friends, authorized: authorized)
      else
        raise
      end
    end

    def inactive_followers(user = nil)
      if user.blank?
        _extract_inactive_users(followers_parallelly, authorized: true)
      elsif uid_or_screen_name?(user)
        authorized = authenticating_user?(user) || authorized_user?(user)
        _extract_inactive_users(followers_parallelly(user), authorized: authorized)
      elsif user.respond_to?(:followers)
        authorized = authenticating_user?(user.uid.to_i) || authorized_user?(user.uid.to_i)
        _extract_inactive_users(user.followers, authorized: authorized)
      else
        raise
      end
    end

    def clusters_belong_to(text)
      return [] if text.blank?

      exclude_words = JSON.parse(File.read(Rails.configuration.x.constants['cluster_bad_words_path']))
      special_words = JSON.parse(File.read(Rails.configuration.x.constants['cluster_good_words_path']))

      # クラスタ用の単語の出現回数を記録
      cluster_word_counter =
        special_words.map { |sw| [sw, text.scan(sw)] }
          .delete_if { |item| item[1].empty? }
          .each_with_object(Hash.new(1)) { |item, memo| memo[item[0]] = item[1].size }

      # 同一文字種の繰り返しを見付ける。漢字の繰り返し、ひらがなの繰り返し、カタカナの繰り返し、など
      text.scan(/[一-龠〆ヵヶ々]+|[ぁ-んー～]+|[ァ-ヴー～]+|[ａ-ｚＡ-Ｚ０-９]+|[、。！!？?]+/).

        # 複数回繰り返される文字を除去
        map { |w| w.remove /[？！?!。、ｗ]|(ー{2,})/ }.

        # 文字数の少なすぎる単語、ひらがなだけの単語、除外単語を除去する
        delete_if { |w| w.length <= 1 || (w.length <= 2 && w =~ /^[ぁ-んー～]+$/) || exclude_words.include?(w) }.

        # 出現回数を記録
        each { |w| cluster_word_counter[w] += 1 }

      # 複数個以上見付かった単語のみを残し、出現頻度順にソート
      cluster_word_counter.select { |_, v| v > 3 }.sort_by { |_, v| -v }.to_h
    end

    def clusters_assigned_to
      raise NotImplementedError.new
    end
  end
end