require 'twitter_with_auto_pagination/rest/utils'

module TwitterWithAutoPagination
  module REST
    module Extension
      module Favoriting
        include TwitterWithAutoPagination::REST::Utils

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

        def _retrieve_favs(*args)
          options = args.extract_options!
          if args.empty?
            favorites(options)
          elsif uid_or_screen_name?(args[0])
            favorites(args[0], options)
          elsif args[0].kind_of?(Array) && args[0].all? { |t| t.respond_to?(:text) }
            args[0]
          else
            raise ArgumentError
          end
        end

        def users_which_you_faved(*args)
          options = args.extract_options!
          instrument(__method__, nil, options) do
            favs = _retrieve_favs(*args, options)
            result = _extract_favorite_users(favs, options)
            if options.has_key?(:uniq) && !options[:uniq]
              result
            else
              result.uniq { |r| r.id }
            end
          end
        rescue => e
          logger.warn "#{__method__} #{user.inspect} #{e.class} #{e.message}"
          raise e
        end

        alias favoriting users_which_you_faved

        def users_who_faved_you(*args)
          raise NotImplementedError
        end

        alias favorited users_who_faved_you

        def _retrieve_replying_replied_and_favoriting(*args)
          names = %i(replying replied favoriting)
          options = args.extract_options!
          if args.empty?
            _fetch_parallelly(names.map { |n| {method: n, args: [options]} })
          elsif uid_or_screen_name?(args[0])
            _fetch_parallelly(names.map { |n| {method: n, args: [args[0], options]} })
          elsif names.all? { |n| args[0].respond_to?(n) }
            names.map { |n| args[0].send(n) }
          else
            raise ArgumentError
          end
        end

        def close_friends(user, uniq: false, min: 0, max: 1000, limit: 30)
          options = {uniq: uniq, min: min, max: max}
          min_max = {min: min, max: max}

          instrument(__method__, nil, options) do
            replying, replied, favoriting = _retrieve_replying_replied_and_favoriting(user, options)

            users = replying + replied + favoriting
            return [] if users.empty?

            score = _count_users_with_two_sided_threshold(users, min_max)
            replying_score = _count_users_with_two_sided_threshold(replying, min_max)
            replied_score = _count_users_with_two_sided_threshold(replied, min_max)
            favoriting_score = _count_users_with_two_sided_threshold(favoriting, min_max)

            score.keys.map { |uid| users.find { |u| u.id.to_i == uid.to_i } }.map do |u|
              u[:score] = score[u.id]
              u[:replying_score] = replying_score[u.id]
              u[:replied_score] = replied_score[u.id]
              u[:favoriting_score] = favoriting_score[u.id]
              u
            end.slice(0, limit)
          end
        end
      end
    end
  end
end
