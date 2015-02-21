require 'helper'

describe ExTwitter do
  let(:config) {
    {
      consumer_key: 'CK',
      consumer_secret: 'CS',
      access_token: 'AT',
      access_token_secret: 'ATS',
    }
  }
  let(:client) { ExTwitter.new(config) }

  describe '#initialize' do
    let(:default_max_paginates) { 3 }
    let(:max_paginates) { 100 }

    context 'without params' do
      it 'uses default max_paginates' do
        expect(ExTwitter.new.max_paginates).to eq(default_max_paginates)
      end
    end

    context 'with params' do
      it 'uses passed max_paginates' do
        expect(ExTwitter.new(max_paginates: max_paginates).max_paginates).to eq(max_paginates)
      end
    end

    context 'with block' do
      it 'uses given max_paginates in block' do
        expect(ExTwitter.new {|config| config.max_paginates = max_paginates }.max_paginates).to eq(max_paginates)
      end
    end
  end

  describe '#collect_with_max_id' do
  end

  describe '#collect_with_cursor' do
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
