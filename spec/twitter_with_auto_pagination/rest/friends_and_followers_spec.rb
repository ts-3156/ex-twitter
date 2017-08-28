require 'helper'

describe TwitterWithAutoPagination::REST::FriendsAndFollowers do
  let(:config) do
    {
      consumer_key: ENV['CK'],
      consumer_secret: ENV['CS'],
      access_token: ENV['AT'],
      access_token_secret: ENV['ATS']
    }
  end

  let(:config2) do
    {
      consumer_key: ENV['CK2'],
      consumer_secret: ENV['CS2'],
      access_token: ENV['AT2'],
      access_token_secret: ENV['ATS2']
    }
  end

  let(:config3) do
    {
      consumer_key: ENV['CK3'],
      consumer_secret: ENV['CS3'],
      access_token: ENV['AT3'],
      access_token_secret: ENV['ATS3']
    }
  end

  let(:client) { TwitterWithAutoPagination::Client.new(config) }
  let(:client2) { TwitterWithAutoPagination::Client.new(config2) }

  let(:id) { 58135830 }
  let(:id2) { 22356250 }

  before do
    client.cache.clear
    client.twitter.send(:user_id) # Call verify_credentials
    client2.twitter.send(:user_id)
    $fetch_called = $request_called = false
    $fetch_count = $request_count = 0
  end

  describe '#friendship?' do
    let(:name) { :friendship? }
    let(:params) { [id, id2] }
    let(:params2) { [id2, id] }

    it_behaves_like 'continuous calls'
    it_behaves_like 'cache: false is specified'
    it_behaves_like 'when a value is changed'
    it_behaves_like 'when options are changed'
    it_behaves_like 'when a client is changed, it shares a cache'
    it_behaves_like 'when any params is not specified, it raises an exception'

    context '`from` is not changed and `to` is changed' do
      let(:id3) { 165085148 }

      it 'it does not share a cache' do
        expect { client.friendship?(id, id2) }.to fetch & request
        expect { client2.friendship?(id, id3) }.to fetch & request
      end
    end
  end

  describe '#friend_ids' do
    let(:name) { :friend_ids }

    it 'matches original one' do
      expect(client.friend_ids).to match_twitter(client.twitter.friend_ids.attrs[:ids])
    end

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

      # Avoid too many requests
      let(:client) { TwitterWithAutoPagination::Client.new(config2) }
      let(:client2) { TwitterWithAutoPagination::Client.new(config) }

      it_behaves_like 'continuous calls'
      it_behaves_like 'cache: false is specified'
      it_behaves_like 'when options are changed'
      it_behaves_like 'when a client is changed, it does not share a cache'
    end

    it_behaves_like 'when any params is not specified, it returns a same result as a result with one param'
  end

  describe '#follower_ids' do
    let(:name) { :follower_ids }

    it 'matches original one' do
      expect(client.follower_ids).to match_twitter(client.twitter.follower_ids.attrs[:ids])
    end

    context 'a user who has too many followers is specified' do
      let(:client) { TwitterWithAutoPagination::Client.new(config3) }
      let(:id) { 187385226 }
      let!(:followers_count) { client.user(id)[:followers_count] }

      before do
        client.twitter.send(:user_id)
        $fetch_called = $request_called = false
        $fetch_count = $request_count = 0
      end

      it 'automatically fetches all followers' do
        request_count = followers_count / 5000 + (followers_count % 5000 == 0 ? 0 : 1)
        expect { client.follower_ids(id) }.to fetch & request.exactly(request_count).times
      end
    end

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

      # Avoid too many requests
      let(:client) { TwitterWithAutoPagination::Client.new(config2) }
      let(:client2) { TwitterWithAutoPagination::Client.new(config) }

      it_behaves_like 'continuous calls'
      it_behaves_like 'cache: false is specified'
      it_behaves_like 'when options are changed'
      it_behaves_like 'when a client is changed, it does not share a cache'
    end

    it_behaves_like 'when any params is not specified, it returns a same result as a result with one param'
  end

  describe '#friends' do
    before do
      allow(client).to receive(:friend_ids).and_return([id])
    end

    it 'calls #users_internal' do
      expect(client).to receive(:users_internal).with([id], any_args)
      client.friends
    end
  end

  describe '#followers' do
    before do
      allow(client).to receive(:follower_ids).and_return([id])
    end

    it 'calls #users_internal' do
      expect(client).to receive(:users_internal).with([id], any_args)
      client.followers
    end
  end

  describe '#friend_ids_and_follower_ids' do
    it 'calls #friend_ids and #follower_ids' do
      expect(client).to receive(:friend_ids).with(id, any_args)
      expect(client).to receive(:follower_ids).with(id, any_args)
      client.friend_ids_and_follower_ids(id)
    end
  end

  describe '#friends_and_followers' do
    it 'calls #friend_ids_and_follower_ids with unique ids' do
      expect(client).to receive(:friend_ids_and_follower_ids).with(id, any_args).and_return([[id], [id]])
      allow(client).to receive(:users_internal).with([id], any_args).and_return([{id: id}])

      friends, followers = client.friends_and_followers(id)

      expect(friends).to match_twitter([{id: id}])
      expect(followers).to match_twitter([{id: id}])
    end

    it 'calls #users_internal with unique ids' do
      allow(client).to receive(:friend_ids_and_follower_ids).with(id, any_args).and_return([[id], [id]])
      expect(client).to receive(:users_internal).with([id], any_args).and_return([{id: id}])

      friends, followers = client.friends_and_followers(id)

      expect(friends).to match_twitter([{id: id}])
      expect(followers).to match_twitter([{id: id}])
    end
  end
end
