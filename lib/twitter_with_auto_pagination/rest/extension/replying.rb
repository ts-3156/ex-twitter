require 'twitter_with_auto_pagination/rest/utils'

module TwitterWithAutoPagination
  module REST
    module Extension
      module Replying
        include TwitterWithAutoPagination::REST::Utils

        def _extract_screen_names(tweets)
          tweets.map do |t|
            $1 if t.text =~ /^(?:\.)?@(\w+)( |\W)/ # include statuses starts with .
          end.compact
        end

        def _retrieve_user_timeline(*args)
          options = args.extract_options!
          if args.empty?
            user_timeline(options)
          elsif uid_or_screen_name?(args[0])
            user_timeline(args[0], options)
          elsif args[0].kind_of?(Array) && args[0].all? { |t| t.respond_to?(:text) }
            args[0]
          else
            raise ArgumentError
          end
        end

        # users which specified user is replying
        # in_reply_to_user_id and in_reply_to_status_id is not used because of distinguishing mentions from replies
        def users_which_you_replied_to(*args)
          options = args.extract_options!
          instrument(__method__, nil, options) do
            tweets = _retrieve_user_timeline(*args, options)
            screen_names = _extract_screen_names(tweets)
            result = users(screen_names, {super_operation: __method__}.merge(options))
            if options.has_key?(:uniq) && !options[:uniq]
              screen_names.map { |sn| result.find { |u| u.screen_name == sn } }.compact
            else
              result.uniq { |u| u.id }
            end
          end
        rescue Twitter::Error::NotFound => e
          e.message == 'No user matches for specified terms.' ? [] : (raise e)
        rescue => e
          logger.warn "#{__method__}: #{e.class} #{e.message} #{args.inspect}"
          raise e
        end

        alias replying users_which_you_replied_to

        def _extract_uids(tweets)
          tweets.map do |t|
            t.user.id.to_i if t.text =~ /^(?:\.)?@(\w+)( |\W)/ # include statuses starts with .
          end.compact
        end

        def _extract_users(tweets, uids)
          uids.map { |uid| tweets.find { |t| t.user.id.to_i == uid.to_i } }.map { |t| t.user }.compact
        end

        def _retrieve_users_from_mentions_timeline(*args)
          options = args.extract_options!
          if args.empty? || (uid_or_screen_name?(args[0]) && authenticating_user?(args[0]))
            mentions_timeline.map { |m| m.user }
          else
            searched_result = search('@' + user(args[0]).screen_name, options)
            uids = _extract_uids(searched_result)
            _extract_users(searched_result, uids)
          end
        end

        # users which specified user is replied
        # when user is login you had better to call mentions_timeline
        def users_who_replied_to_you(*args)
          options = args.extract_options!
          instrument(__method__, nil, options) do
            result = _retrieve_users_from_mentions_timeline(*args, options)
            if options.has_key?(:uniq) && !options[:uniq]
              result
            else
              result.uniq { |r| r.id }
            end
          end
        end

        alias replied users_who_replied_to_you
      end
    end
  end
end
