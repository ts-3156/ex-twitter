require 'parallel'

module TwitterWithAutoPagination
  module Parallel

    def parallel(options = {}, &block)
      batch = Arguments.new
      yield(batch)

      in_threads = options.fetch(:in_threads, batch.size)

      ::Parallel.map_with_index(batch, in_threads: in_threads) do |args, i|
        {i: i, result: send(*args)}
      end.sort_by { |q| q[:i] }.map { |q| q[:result] }
    end

    class Arguments < Array
      %i(
        users
        friend_ids
        follower_ids
        friends
        followers
        home_timeline
        user_timeline
        mentions_timeline
        search
        favorites
      ).each do |name|
        define_method(name) do |*args|
          send(:<< , [name, *args])
        end
      end
    end

    # Deprecated
    # [{method: :friends, args: ['ts_3156', ...], {...}]
    def fetch_parallelly(signatures)
      ::Parallel.map_with_index(signatures, in_threads: signatures.size) do |signature, i|
        {i: i, result: send(signature[:method], *signature[:args])}
      end.sort_by { |q| q[:i] }.map { |q| q[:result] }
    end
  end
end
