require 'helper'

describe TwitterWithAutoPagination do
  let(:config) {
    {
      consumer_key: 'CK',
      consumer_secret: 'CS',
      access_token: 'AT',
      access_token_secret: 'ATS',
    }
  }
  let(:client) { TwitterWithAutoPagination::Client.new(config) }

  describe '#initialize' do
    let(:default_call_count) { 0 }

    it 'sets call_count to 0' do
      expect(client.call_count).to eq(default_call_count)
    end

    context 'without params' do
    end

    context 'with params' do
    end
  end

  describe '#logger' do
    it 'has logger' do
      expect(client.logger).to be_truthy
    end
  end

  describe '#call_old_method' do
  end

  describe '#collect_with_max_id' do
  end

  describe '#collect_with_cursor' do
  end

  describe '#file_cache_key' do
  end

  describe '#namespaced_key' do
  end

  describe '#encode_json' do
  end

  describe '#decode_json' do
  end

  describe '#fetch_cache_or_call_api' do
  end

  describe '#user_timeline' do
    it 'calls old_user_timeline' do
      expect(client).to receive(:old_user_timeline)
      client.user_timeline
    end

    it 'calls collect_with_max_id' do
      expect(client).to receive(:collect_with_max_id)
      client.user_timeline
    end
  end

  describe '#user_photos' do
    it 'calls user_timeline' do
      expect(client).to receive(:user_timeline)
      client.user_photos
    end
  end

  describe '#friends' do
    it 'calls old_friends' do
      expect(client).to receive(:old_friends)
      client.friends
    end

    it 'calls collect_with_cursor' do
      expect(client).to receive(:collect_with_cursor)
      client.friends
    end
  end

  describe '#followers' do
    it 'calls old_followers' do
      expect(client).to receive(:old_followers)
      client.followers
    end

    it 'calls collect_with_cursor' do
      expect(client).to receive(:collect_with_cursor)
      client.followers
    end
  end

  describe '#friend_ids' do
    it 'calls old_friend_ids' do
      expect(client).to receive(:old_friend_ids)
      client.friend_ids
    end

    it 'calls collect_with_cursor' do
      expect(client).to receive(:collect_with_cursor)
      client.friend_ids
    end
  end

  describe '#follower_ids' do
    it 'calls old_follower_ids' do
      expect(client).to receive(:old_follower_ids)
      client.follower_ids
    end

    it 'calls collect_with_cursor' do
      expect(client).to receive(:collect_with_cursor)
      client.follower_ids
    end
  end

  describe '#users' do
    it 'calls old_users' do
      expect(client).to receive(:old_users)
      client.users([1, 2, 3])
    end
  end
end
