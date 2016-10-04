require 'twitter_with_auto_pagination/rest/utils'

module TwitterWithAutoPagination
  module REST
    module Extension
      module Clusters
        include TwitterWithAutoPagination::REST::Utils

        # @param text [String] user_timeline.map(&:text).join(' ')
        def clusters_belong_to(text, limit: 10)
          return {} if text.blank?

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
          frequency.select { |_, v| 2 < v }.sort_by { |_, v| -v }.slice(0, limit).to_h
        end

        alias tweet_clusters clusters_belong_to

        def list_clusters(user, each_member: 300, total_member: 1000, rate: 0.3, limit: 10, debug: false)
          lists = memberships(user).sort_by { |li| li.member_count }
          puts "lists: #{lists.size} (#{lists.map { |li| li.member_count }.join(', ')})" if debug
          return {} if lists.empty?

          while lists.size > 200
            percentile25 = ((lists.length * 0.25).ceil) - 1
            percentile75 = ((lists.length * 0.75).ceil) - 1
            lists = lists[percentile25..percentile75]
            puts "lists sliced by 25-75 percentile: #{lists.size} (#{lists.map { |li| li.member_count }.join(', ')})" if debug
          end

          list_special_words = %w()
          list_exclude_words = %w(list people met)

          words = lists.map { |li| li.full_name.split('/')[1].split('-') }.flatten.delete_if { |w| w.size < 2 || list_exclude_words.include?(w) }.
            each_with_object(Hash.new(0)) { |w, memo| memo[w] += 1 }.select { |_, v| (10 < lists.size ? 1 : 0) < v }.sort_by { |k, v| [-v, -k.size] }

          puts "words: #{words.slice(0, 10)}" if debug
          return {} if words.empty?

          word = words[0][0]
          puts "word: #{word}" if debug

          # TODO: listsの数が小さすぎる場合はwordを増やす
          lists = lists.select { |li| li.full_name.split('/')[1].include?(word) }
          puts "lists include specified word: #{lists.size} (#{lists.map { |li| li.member_count }.join(', ')})" if debug
          return {} if lists.empty?

          3.times do
            _lists = lists.select { |li| (10 < lists.size ? 10 : 0) < li.member_count && li.member_count < each_member }
            if _lists.size > 2 || _lists.size == lists.size
              lists = _lists
              break
            else
              each_member *= 1.25
            end
          end
          puts "lists limited by each member #{each_member}: #{lists.size} (#{lists.map { |li| li.member_count }.join(', ')})" if debug
          return {} if lists.empty?

          3.times do
            _lists = lists.select.with_index { |_, i| lists[0..i].map { |li| li.member_count }.sum < total_member }
            if _lists.any?
              lists = _lists
              break
            else
              total_member *= 1.25
            end
          end
          puts "lists limited by total members #{total_member}: #{lists.size} (#{lists.map { |li| li.member_count }.join(', ')})" if debug
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
            _members = members.each_with_object(Hash.new(0)) { |member, memo| memo[member] += 1 }.select { |_, v| lists.size * rate < v }.keys
            if _members.size > 100
              members = _members
              break
            else
              rate += 0.1
            end
          end
          puts "members included multi lists #{rate}: #{members.size}" if debug

          require 'mecab'

          profile_special_words = %w()
          profile_exclude_words = %w(in at of my no er the and for inc Inc com gmail 好き こと 最近 情報 さん ちゃん くん 発言 関係 もの 活動 見解 所属 組織 連絡 大好き サイト ブログ つぶやき こちら アカ アカウント イベント フォロー)

          descriptions = members.map { |m| m.description.remove(URI.regexp) }

          candidates, remains = descriptions.partition { |desc| desc.scan('/').size > 2 }
          slash_freq = count_by_word_with_delim(candidates, delim: '/')
          puts "words splitted by /: #{slash_freq.to_a.slice(0, 10)}" if debug

          candidates, remains = remains.partition { |desc| desc.scan('|').size > 2 }
          pipe_freq = count_by_word_with_delim(candidates, delim: '|')
          puts "words splitted by |: #{pipe_freq.to_a.slice(0, 10)}" if debug

          noun_freq = count_by_word_with_tagger(remains, exclude_words: profile_exclude_words)
          puts "words with nouns added: #{noun_freq.to_a.slice(0, 10)}" if debug

          slash_freq.merge(pipe_freq) { |_, old, neww| old + neww }.merge(noun_freq) { |_, old, neww| old + neww }.sort_by { |k, v| [-v, -k.size] }.slice(0, limit)
        end

        private

        def count_by_word_with_delim(texts, delim:)
          texts.map { |t| t.split(delim) }.flatten.
            map(&:strip).
            delete_if { |w| w.empty? || w.size < 2 || 5 < w.size }.
            each_with_object(Hash.new(0)) { |w, memo| memo[w] += 1 }.
            sort_by { |k, v| [-v, -k.size] }.to_h
        end

        def count_by_word_with_tagger(texts, tagger: nil, exclude_words: [])
          tagger = MeCab::Tagger.new("-d #{`mecab-config --dicdir`.chomp}/mecab-ipadic-neologd/") if tagger.nil?
          nouns = tagger.parse(texts.join(' ')).split("\n").
            select { |line| line.include?('名詞') }.
            map { |line| line.split("\t")[0] }.
            delete_if { |w| w.empty? || w.size < 2 || 5 < w.size || exclude_words.include?(w) }

          nouns.each_with_object(Hash.new(0)) { |noun, memo| memo[noun] += 1 }.
            sort_by { |k, v| [-v, -k.size] }.to_h
        end
      end
    end
  end
end
