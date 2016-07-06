require 'twitter_with_auto_pagination/rest/utils'

module TwitterWithAutoPagination
  module REST
    module Search
      include TwitterWithAutoPagination::REST::Utils

      def search(*args)
        options = {count: 100, result_type: :recent, call_limit: 1}.merge(args.extract_options!)
        options[:reduce] = false
        fetch_cache_or_call_api(__method__, args[0], options) {
          collect_with_max_id(method(__method__).super_method, *args, options) { |response| response.attrs[:statuses] }
        }
      end
    end
  end
end