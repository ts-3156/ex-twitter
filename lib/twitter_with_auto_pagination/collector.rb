module TwitterWithAutoPagination
  module Collector

    def collect_with_max_id(collection = [], max_id = nil, &block)
      tweets = yield(max_id)
      return collection if tweets.nil?
      collection += tweets
      tweets.empty? ? collection.flatten : collect_with_max_id(collection, tweets.last.id - 1, &block)
    end

    def collect_with_cursor(collection = [], cursor = nil, &block)
      response = yield(cursor)
      return collection if response.nil?
      collection += (response.attrs[:ids] || response.attrs[:users] || response.attrs[:lists]) # TODO to_a
      response.attrs[:next_cursor].zero? ? collection.flatten : collect_with_cursor(collection, response.attrs[:next_cursor], &block)
    end
  end
end