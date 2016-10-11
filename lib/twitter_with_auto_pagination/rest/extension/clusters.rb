require 'twitter_with_auto_pagination/rest/utils'

module TwitterWithAutoPagination
  module REST
    module Extension
      module Clusters
        include TwitterWithAutoPagination::REST::Utils

        def tweet_clusters(tweets, limit: 10)
          return {} if tweets.blank?
          text = tweets.map(&:text).join(' ')

          if defined?(Rails)
            exclude_words = JSON.parse(File.read(Rails.configuration.x.constants['cluster_bad_words_path']))
            special_words = JSON.parse(File.read(Rails.configuration.x.constants['cluster_good_words_path']))
          else
            exclude_words = JSON.parse(File.read('./cluster_bad_words.json'))
            special_words = JSON.parse(File.read('./cluster_good_words.json'))
          end

          %w(べたら それとも たしかに さそう そんなに ったことある してるの しそうな おやくま ってますか これをやってるよ のせいか).each { |w| exclude_words << w }
          %w(面白い 可愛い 食べ物 宇多田ヒカル ご飯 面倒 体調悪くなる 空腹 頑張ってない 眼鏡 台風 沖縄 らんま1/2 女の子 怪我 足のむくみ 彼女欲しい 彼氏欲しい 吐き気 注射 海鮮チヂミ 出勤 価格ドットコム 幹事 雑談 パズドラ ビオフェルミン 餃子 お金 まんだらけ 結婚 焼肉 タッチペン).each { |w| special_words << w }

          # クラスタ用の単語の出現回数を記録
          frequency =
            special_words.map { |sw| [sw, text.scan(sw)] }
              .delete_if { |_, matched| matched.empty? }
              .each_with_object(Hash.new(0)) { |(word, matched), memo| memo[word] = matched.size }

          # 同一文字種の繰り返しを見付ける。漢字の繰り返し、ひらがなの繰り返し、カタカナの繰り返し、など
          text.scan(/[一-龠〆ヵヶ々]+|[ぁ-んー～]+|[ァ-ヴー～]+|[ａ-ｚA-ZＡ-Ｚ０-９]+|[、。！!？?]+/).

            # 複数回繰り返される文字を除去
            map { |w| w.remove /[？！?!。、ｗ]|(ー{2,})/ }.

            # 文字数の少なすぎる単語、除外単語を除去する
            delete_if { |w| w.length <= 2 || exclude_words.include?(w) }.

            # 出現回数を記録
            each { |w| frequency[w] += 1 }

          # 複数個以上見付かった単語のみを残し、出現頻度順にソート
          frequency.select { |_, v| 2 < v }.sort_by { |k, v| [-v, -k.size] }.slice(0, limit).to_h
        end

        def hashtag_clusters(tweets, limit: 10, debug: false)
          puts "tweets: #{tweets.size}" if debug
          return {} if tweets.blank?

          tweets = tweets.select { |t| t.text && t.text.include?('#') }
          puts "tweets with hashtag: #{tweets.size}" if debug

          hashtags = tweets.map { |t| t.text.scan(/[#＃][Ａ-Ｚａ-ｚA-Za-z_一-鿆0-9０-９ぁ-ヶｦ-ﾟー]+/).map(&:strip) }.flatten
          puts "hashtags: #{hashtags.size}" if debug

          hashtags.each_with_object(Hash.new(0)) { |h, memo| memo[h] += 1 }.sort_by { |k, v| [-v, -k.size] }.slice(0, limit).to_h
        end

        def list_clusters(user, shrink: false, each_member: 300, total_member: 1000, rate: 0.3, limit: 10, debug: false)
          begin
            require 'mecab'
          rescue => e
            puts "Add gem 'mecab' to your Gemfile."
            return nil
          end

          begin
            lists = memberships(user).sort_by { |li| li.member_count }
          rescue => e
            puts "#{e.class}: #{e.message} #{user.inspect}" if debug
            lists = []
          end
          puts "lists: #{lists.size} (#{lists.map { |li| li.member_count }.join(', ')})" if debug
          return {} if lists.empty?

          while lists.size > 200
            percentile25 = ((lists.length * 0.25).ceil) - 1
            percentile75 = ((lists.length * 0.75).ceil) - 1
            lists = lists[percentile25..percentile75]
            puts "lists sliced by 25-75 percentile: #{lists.size} (#{lists.map { |li| li.member_count }.join(', ')})" if debug
          end if shrink

          list_special_words = %w()
          list_exclude_words1 = %r(list[0-9]*|people-ive-faved|twizard-magic-list|my-favstar-fm-list)
          list_exclude_words2 = %w(it list people met)

          words = lists.map { |li| li.full_name.split('/')[1] }.
            select { |n| !n.match(list_exclude_words1) }.
            map { |n| n.split('-') }.flatten.
            delete_if { |w| w.size < 2 || list_exclude_words2.include?(w) }.
            each_with_object(Hash.new(0)) { |w, memo| memo[w] += 1 }.
            sort_by { |k, v| [-v, -k.size] }

          puts "words: #{words.slice(0, 10)}" if debug
          return {} if words.empty?

          _words = []
          lists =
            filter(lists, min: 2) do |li, i|
              _words = words[0..i].map(&:first)
              name = li.full_name.split('/')[1]
              _words.any? { |w| name.include?(w) }
            end
          puts "lists include #{_words.inspect}: #{lists.size} (#{lists.map { |li| li.member_count }.join(', ')})" if debug
          return {} if lists.empty?

          _each_member = 0
          lists =
            filter(lists, min: 2) do |li, i|
              _each_member = each_member * (1.0 + 0.25 * i)
              (10 < lists.size ? 10 : 0) < li.member_count && li.member_count < _each_member
            end
          puts "lists limited by each member #{_each_member}: #{lists.size} (#{lists.map { |li| li.member_count }.join(', ')})" if debug
          return {} if lists.empty?

          _total_member = 0
          lists =
            filter(lists, min: 1) do |_, i|
              _total_member = total_member * (1.0 + 0.25 * i)
              lists[0..i].map { |li| li.member_count }.sum < _total_member
            end
          puts "lists limited by total members #{_total_member}: #{lists.size} (#{lists.map { |li| li.member_count }.join(', ')})" if debug
          return {} if lists.empty?

          members = lists.map do |li|
            begin
              list_members(li.id)
            rescue => e
              puts "#{e.class}: #{e.message} #{li.id} #{li.full_name} #{li.mode}" if debug
              nil
            end
          end.compact.flatten
          puts "candidate members: #{members.size}" if debug
          return {} if members.empty?

          3.times do
            _members = members.each_with_object(Hash.new(0)) { |member, memo| memo[member] += 1 }.
              select { |_, v| lists.size * rate < v }.keys
            if _members.size > 100
              members = _members
              break
            else
              rate += 0.1
            end
          end
          puts "members included multi lists #{rate}: #{members.size}" if debug


          profile_special_words = %w()
          profile_exclude_words = %w(in at of my no er the and for inc Inc com gmail 好き こと 最近 情報 さん ちゃん くん 発言 関係 もの 活動 見解 所属 組織 連絡 大好き サイト ブログ つぶやき こちら アカ アカウント イベント フォロー)

          descriptions = members.map { |m| m.description.remove(URI.regexp) }

          candidates, remains = descriptions.partition { |desc| desc.scan('/').size > 2 }
          slash_freq = count_by_word(candidates, delim: '/')
          puts "words splitted by /: #{slash_freq.to_a.slice(0, 10)}" if debug

          candidates, remains = remains.partition { |desc| desc.scan('|').size > 2 }
          pipe_freq = count_by_word(candidates, delim: '|')
          puts "words splitted by |: #{pipe_freq.to_a.slice(0, 10)}" if debug

          tagger = MeCab::Tagger.new("-d #{`mecab-config --dicdir`.chomp}/mecab-ipadic-neologd/")
          noun_freq = count_by_word(remains, tagger: tagger, exclude_words: profile_exclude_words)
          puts "words tagged as noun: #{noun_freq.to_a.slice(0, 10)}" if debug

          slash_freq.merge(pipe_freq) { |_, old, neww| old + neww }.merge(noun_freq) { |_, old, neww| old + neww }.sort_by { |k, v| [-v, -k.size] }.slice(0, limit)
        end

        private

        def filter(lists, min:)
          min = [min, lists.size].min
          _lists = []
          3.times do |i|
            _lists = lists.select { |li| yield(li, i) }
            break if _lists.size >= min
          end
          _lists
        end

        def count_by_word(texts, delim: nil, tagger: nil, exclude_words: [])
          texts = texts.dup

          if delim
            texts = texts.map { |t| t.split(delim) }.flatten.map(&:strip)
          end

          if tagger
            texts = tagger.parse(texts.join(' ')).split("\n").
              select { |line| line.include?('名詞') }.
              map { |line| line.split("\t")[0] }
          end

          texts.delete_if { |w| w.empty? || w.size < 2 || 5 < w.size || exclude_words.include?(w) }.
            each_with_object(Hash.new(0)) { |word, memo| memo[word] += 1 }.
            sort_by { |k, v| [-v, -k.size] }.to_h
        end
      end
    end
  end
end
