require 'helper'

describe TwitterWithAutoPagination::REST::Users do
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

  describe '#verify_credential' do
    let(:name) { :verify_credentials }
    let(:params) { [] }

    it_behaves_like 'continuous calls'
    it_behaves_like 'cache: false is specified'
    it_behaves_like 'when options are changed'
    it_behaves_like 'when a client is changed, it does not share a cache'

    context 'when one param is specified, it raises an exception' do
      it 'raises an exception' do
        expect { client.verify_credentials(id) }.to raise_error(TypeError)
      end
    end
  end

  describe '#user?' do
    let(:name) { :user? }
    let(:params) { [id] }
    let(:params2) { [id2] }

    it_behaves_like 'continuous calls'
    it_behaves_like 'cache: false is specified'
    it_behaves_like 'when a value is changed'
    it_behaves_like 'when options are changed'
    it_behaves_like 'when a client is changed, it shares a cache'
    it_behaves_like 'when any params is not specified, it raises an exception'
  end

  describe '#user' do
    let(:name) { :user }

    context 'with one param' do
      let(:params) { [id] }
      let(:params2) { [id2] }

      it_behaves_like 'continuous calls'
      it_behaves_like 'cache: false is specified'
      it_behaves_like 'when a value is changed'
      it_behaves_like 'when options are changed'
      it_behaves_like 'when a client is changed, it shares a cache'
    end

    context 'with no params' do
      let(:params) { [] }

      it_behaves_like 'continuous calls'
      it_behaves_like 'cache: false is specified'
      it_behaves_like 'when options are changed'
      it_behaves_like 'when a client is changed, it does not share a cache'
    end

    it_behaves_like 'when any params is not specified, it returns a same result as a result with one param'
  end

  describe '#users' do
    let(:name) { :users }
    let(:params) { [[id]] }
    let(:params2) { [[id2]] }

    it_behaves_like 'continuous calls'
    it_behaves_like 'cache: false is specified'
    it_behaves_like 'when a value is changed'
    it_behaves_like 'when options are changed'
    it_behaves_like 'when a client is changed, it shares a cache'
    it_behaves_like 'when any params is not specified, it raises an exception'

    context 'with many values' do
      it 'fetches 3 times' do
        many_values = Array.new(150, id)
        expect { client.users(many_values) }.to fetch.exactly(3).times & request.twice
        expect { client.users(many_values) }.to fetch & not_request
      end
    end

  end

  describe '#blocked_ids' do
    let(:name) { :blocked_ids }
    let(:params) { [] }

    it_behaves_like 'continuous calls'
    it_behaves_like 'cache: false is specified'
    it_behaves_like 'when options are changed'
    it_behaves_like 'when a client is changed, it does not share a cache'
    it_behaves_like 'when one param is specified, it raises an exception'

    context 'when strange params are specified' do
      let(:params) { [1, 2, 3] }

      it 'does not raise an exception' do
        expect { client.blocked_ids(*params) }.to_not raise_error
      end

      it 'does not share a cache' do
        result1 = result2 = nil
        expect { result1 = client.blocked_ids }.to fetch & request
        expect { result2 = client.blocked_ids(*params) }.to fetch & request
        expect(result1).to match_array(result2)
      end
    end
  end

  describe '#users_internal' do
    context 'with many values' do
      it 'fetches twice' do
        many_values = Array.new(150, id)
        expect { client.send(:users_internal, many_values) }.to fetch.twice & request.twice
        expect { client.send(:users_internal, many_values) }.to fetch.twice & not_request
      end
    end
  end
end
