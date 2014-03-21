# coding: utf-8
require 'helper'

describe ExTwitter do
  before(:each) do
    config = {
      consumer_key: 'CK',
      consumer_secret: 'CS',
      access_token: 'AT',
      access_token_secret: 'ATS'
    }
    @client = ExTwitter.new(config)
  end

  describe '#initialize' do
    context 'with all values passed' do
      pending 'set max_attempts' do
      end

      pending 'set wait' do
      end

      pending 'set cache' do
      end

      pending 'set cache_expires_in' do
      end
    end
  end

  describe '#read, #write' do
    pending 'read cache' do
    end

    pending 'write cache' do
    end
  end

  describe '#collect_with_max_id, #collect_with_cursor' do
    pending 'collects with max id' do
    end

    pending 'collects with cursor' do
    end
  end

  describe '#get_latest_200_tweets' do
    pending 'gets latest 200 tweets' do
    end
  end

  describe '#get_all_tweets' do
    context 'with a screen name passed' do
      before(:each) do
      end

      pending 'requests the correct resources' do
      end

      pending 'returns the all tweets posted by the user specified by screen name or user id' do
      end
    end

    context 'without a screen name passed' do
      before(:each) do
      end

      pending 'requests the correct resources' do
      end

      pending 'returns Array of Twitter::Tweet' do
      end

      pending 'returns the all tweets posted by the auth user' do
      end
    end
  end

  describe '#get_all_friends' do
    context 'with a screen name passed' do
      before(:each) do
      end

      pending 'requests the correct resources' do
      end

      pending 'returns the all tweets posted by the user specified by screen name or user id' do
      end
    end
    
    context 'without a screen name passed' do
      before(:each) do
      end

      pending 'requests the correct resources' do
      end

      pending 'returns Array of Twitter::User' do
      end

      pending 'returns the all tweets posted by the auth user' do
      end
    end
  end
end
