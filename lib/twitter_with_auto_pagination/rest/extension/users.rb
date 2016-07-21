require 'twitter_with_auto_pagination/rest/utils'

module TwitterWithAutoPagination
  module REST
    module Extension
      module Users
        include TwitterWithAutoPagination::REST::Utils

        def blocking_or_blocked(past_me, cur_me)
          instrument(__method__, nil) do
            removing(past_me, cur_me).to_a & removed(past_me, cur_me).to_a
          end
        end
      end
    end
  end
end
