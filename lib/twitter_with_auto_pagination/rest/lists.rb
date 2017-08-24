require 'twitter_with_auto_pagination/rest/utils'

module TwitterWithAutoPagination
  module REST
    module Lists
      include TwitterWithAutoPagination::REST::Utils

      # Returns the lists the specified user has been added to.
      def memberships(*args)
        options = {count: 1000, cursor: -1}.merge(args.extract_options!)

        collect_with_cursor do |next_cursor|
          options[:next_cursor] = next_cursor unless next_cursor.nil?
          twitter.send(:memberships, *args, options)
        end
      end

      # Returns the members of the specified list.
      def list_members(*args)
        options = {count: 5000, skip_status: 1, cursor: -1}.merge(args.extract_options!)

        collect_with_cursor do |next_cursor|
          options[:next_cursor] = next_cursor unless next_cursor.nil?
          twitter.send(:list_members, *args, options)
        end
      end
    end
  end
end
