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
    let(:default_value) { 3 }
    let(:value) { 100 }

    context 'without params' do
      it "doesn't set max_paginates" do
        expect(ExTwitter.new.max_paginates).to eq(default_value)
      end
    end

    context 'with params' do
      it 'set max_paginates' do
        expect(ExTwitter.new(max_paginates: value).max_paginates).to eq(value)
      end
    end

    context 'with block' do
      it 'set max_paginates' do
        expect(ExTwitter.new {|config| config.max_paginates = value }.max_paginates).to eq(value)
      end
    end
  end

  describe '#read' do
  end

  describe '#write' do
  end

  describe '#collect_with_max_id' do
  end

  describe '#collect_with_cursor' do
  end

  # describe '#user_timeline' do
  #   it 'call collect_with_max_id' do
  #     expect(client).to receive(:collect_with_max_id)
  #     client.user_timeline
  #   end
  # end
  #
  # describe '#friends' do
  #   it 'call collect_with_cursor' do
  #     expect(client).to receive(:collect_with_cursor)
  #     client.friends
  #   end
  # end
  #
  # describe '#followers' do
  #   it 'call collect_with_cursor' do
  #     expect(client).to receive(:collect_with_cursor)
  #     client.followers
  #   end
  # end
  #
  # describe '#friend_ids' do
  #   it 'call collect_with_cursor' do
  #     expect(client).to receive(:collect_with_cursor)
  #     client.friend_ids
  #   end
  # end
  #
  # describe '#follower_ids' do
  #   it 'call collect_with_cursor' do
  #     expect(client).to receive(:collect_with_cursor)
  #     client.follower_ids
  #   end
  # end
  #
  # describe '#users' do
  #   it 'call old_users' do
  #     expect(client).to receive(:old_users)
  #     client.users([1, 2, 3])
  #   end
  # end
end
