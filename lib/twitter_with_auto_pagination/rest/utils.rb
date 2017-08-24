require 'hashie'
require 'digest/md5'

require 'twitter_with_auto_pagination/collector'

module TwitterWithAutoPagination
  module REST
    module Utils
     include TwitterWithAutoPagination::Collector

     DEFAULT_CALL_LIMIT = 1

     private

     def calc_call_limit(count, max_count)
       return DEFAULT_CALL_LIMIT unless count
       limit = count / max_count
       limit += 1 if (count % max_count).nonzero?
       limit
     end

     def uid_or_screen_name?(object)
       object.kind_of?(String) || object.kind_of?(Integer)
     end

     def authenticating_user?(target)
       user.id.to_i == user(target).id.to_i
     end

     def authorized_user?(target)
       target_user = user(target)
       !target_user.protected? || friendship?(user.id.to_i, target_user.id.to_i)
     end

     def credentials_hash
       Digest::MD5.hexdigest(access_token + access_token_secret + consumer_key + consumer_secret)
     end

     def instrument(operation, name, options = nil)
       payload = {operation: operation}
       payload.merge!(options) if options.is_a?(Hash) && !options.empty?
       ActiveSupport::Notifications.instrument("#{name.nil? ? operation : name}.twitter", payload) {yield(payload)}
     end
    end
  end
end
