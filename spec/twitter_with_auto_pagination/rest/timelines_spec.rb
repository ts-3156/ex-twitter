require 'helper'

describe TwitterWithAutoPagination::REST::Timelines do
  let(:client) do
    TwitterWithAutoPagination::Client.new(
      consumer_key: ENV['CK'],
      consumer_secret: ENV['CS'],
      access_token: ENV['AT'],
      access_token_secret: ENV['ATS']
    )
  end

  let(:client2) do
    TwitterWithAutoPagination::Client.new(
      consumer_key: ENV['CK2'],
      consumer_secret: ENV['CS2'],
      access_token: ENV['AT2'],
      access_token_secret: ENV['ATS2']
    )
  end

  let(:id) { 58135830 }
  let(:id2) { 22356250 }

  before do
    client.cache.clear
    $fetch_called = $request_called = false
    $fetch_count = $request_count = 0
  end

  describe '#home_timeline' do
    let(:name) { :home_timeline }
    let(:params) { [] }

    it_behaves_like 'continuous calls'
    it_behaves_like 'cache: false is specified'
    it_behaves_like 'when options are changed'
    it_behaves_like 'when a client is changed, it does not share a cache'
    it_behaves_like 'when one param is specified, it raises an exception'
    it_behaves_like 'when count is specified', 400
  end

  describe '#user_timeline' do
    let(:name) { :user_timeline }

    context 'with one param' do
      let(:params) { [id] }
      let(:params2) { [id2] }

      it_behaves_like 'continuous calls'
      it_behaves_like 'cache: false is specified'
      it_behaves_like 'when a value is changed'
      it_behaves_like 'when options are changed'
      it_behaves_like 'when a client is changed, it shares a cache'
      it_behaves_like 'when count is specified', 400
    end

    context 'with no params' do
      let(:params) { [] }

      it_behaves_like 'continuous calls'
      it_behaves_like 'cache: false is specified'
      it_behaves_like 'when options are changed'
      it_behaves_like 'when a client is changed, it does not share a cache'
      it_behaves_like 'when count is specified', 400
    end

    it_behaves_like 'when any params is not specified, it returns a same result as a result with one param'
  end

  describe '#mentions_timeline' do
    let(:name) { :mentions_timeline }
    let(:params) { [] }

    it_behaves_like 'continuous calls'
    it_behaves_like 'cache: false is specified'
    it_behaves_like 'when options are changed'
    it_behaves_like 'when a client is changed, it does not share a cache'
    it_behaves_like 'when one param is specified, it raises an exception'
    it_behaves_like 'when count is specified', 400
  end
end
