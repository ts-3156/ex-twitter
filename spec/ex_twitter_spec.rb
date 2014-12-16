require 'helper'

describe ExTwitter do
  let(:config) {
    {
      consumer_key: 'CK',
      consumer_secret: 'CS',
      access_token: 'AT',
      access_token_secret: 'ATS'
    }
  }
  let(:client) { ExTwitter.new(config) }

  describe '#initialize' do
  end

  describe '#read' do
  end

  describe '#write' do
  end

  describe '#collect_with_max_id' do
  end

  describe '#collect_with_cursor' do
  end

  describe '#user_timeline' do
    it 'call collect_with_max_id' do
      expect(client).to receive(:collect_with_max_id)
      client.user_timeline
    end
  end

  describe '#friends' do
    it 'call collect_with_cursor' do
      expect(client).to receive(:collect_with_cursor)
      client.friends
    end
  end

  describe '#followers' do
    it 'call collect_with_cursor' do
      expect(client).to receive(:collect_with_cursor)
      client.followers
    end
  end

  describe '#friend_ids' do
    it 'call collect_with_cursor' do
      expect(client).to receive(:collect_with_cursor)
      client.friend_ids
    end
  end

  describe '#follower_ids' do
    it 'call collect_with_cursor' do
      expect(client).to receive(:collect_with_cursor)
      client.follower_ids
    end
  end

  describe '#users' do
    it 'call old_users' do
      expect(client).to receive(:old_users)
      client.users([1, 2, 3])
    end
  end
end
