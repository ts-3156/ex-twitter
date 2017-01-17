require 'twitter_with_auto_pagination/rest/utils'

module TwitterWithAutoPagination
  module REST
    module Extension
      module Clusters
        include TwitterWithAutoPagination::REST::Utils

        PROFILE_SPECIAL_WORDS = %w(20↑ 成人済 腐女子)
        PROFILE_SPECIAL_REGEXP = nil
        PROFILE_EXCLUDE_WORDS = %w(in at of my to no er by is RT DM the and for you inc Inc com from info next gmail 好き こと 最近 紹介 連載 発売 依頼 情報 さん ちゃん くん 発言 関係 もの 活動 見解 所属 組織 代表 連絡 大好き サイト ブログ つぶやき 株式会社 最新 こちら 届け お仕事 ツイ 返信 プロ 今年 リプ ヘッダー アイコン アカ アカウント ツイート たま ブロック 無言 時間 お願い お願いします お願いいたします イベント フォロー フォロワー フォロバ スタッフ 自動 手動 迷言 名言 非公式 リリース 問い合わせ ツイッター DVD 発売中 出身)
        PROFILE_EXCLUDE_REGEXP = Regexp.union(/\w+@\w+\.(com|co\.jp)/, %r[\d{2,4}(年|/)\d{1,2}(月|/)\d{1,2}日], %r[\d{1,2}/\d{1,2}], /\d{2}th/, URI.regexp)

        def tweet_clusters(tweets, limit: 10, debug: false)
          return {} if tweets.blank?
          text = tweets.map(&:text).join(' ')

          if defined?(Rails)
            exclude_words = JSON.parse(File.read(Rails.configuration.x.constants['cluster_bad_words_path']))
            special_words = JSON.parse(File.read(Rails.configuration.x.constants['cluster_good_words_path']))
          else
            exclude_words = JSON.parse(File.read('./cluster_bad_words.json'))
            special_words = JSON.parse(File.read('./cluster_good_words.json'))
          end

          %w(べたら むっちゃ それとも たしかに さそう そんなに ったことある してるの しそうな おやくま ってますか これをやってるよ のせいか 面白い 可愛い).each { |w| exclude_words << w }
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
          frequency.select { |_, v| 2 < v }.sort_by { |k, v| [-v, -k.size] }.take(limit).to_h
        end

        def count_freq_hashtags(tweets, with_prefix: true, use_regexp: false, debug: false)
          puts "tweets: #{tweets.size}" if debug
          return {} if tweets.blank?

          prefix = %w(# ＃)
          regexp = /[#＃]([Ａ-Ｚａ-ｚA-Za-z_一-鿆0-9０-９ぁ-ヶｦ-ﾟー]+)/

          tweets =
            if use_regexp
              tweets.select { |t| t.text && prefix.any? { |char| t.text.include?(char)} }
            else
              tweets.select { |t| include_hashtags?(t) }
            end
          puts "tweets with hashtag: #{tweets.size}" if debug

          hashtags =
            if use_regexp
              tweets.map { |t| t.text.scan(regexp).flatten.map(&:strip) }
            else
              tweets.map { |t| extract_hashtags(t) }
            end.flatten
          hashtags = hashtags.map { |h| "#{prefix[0]}#{h}" } if with_prefix

          hashtags.each_with_object(Hash.new(0)) { |h, memo| memo[h] += 1 }.sort_by { |k, v| [-v, -k.size] }.to_h
        end

        def hashtag_clusters(hashtags, limit: 10, debug: false)
          puts "hashtags: #{hashtags.take(10)}" if debug

          hashtag, count = hashtags.take(3).each_with_object(Hash.new(0)) do |tag, memo|
            tweets = search(tag)
            puts "tweets #{tag}: #{tweets.size}" if debug
            memo[tag] = count_freq_hashtags(tweets).reject { |t, c| t == tag }.values.sum
          end.max_by { |_, c| c }

          hashtags = count_freq_hashtags(search(hashtag)).reject { |t, c| t == hashtag }.keys
          queries = hashtags.take(3).combination(2).map { |ary| ary.join(' AND ') }
          puts "selected #{hashtag}: #{queries.inspect}" if debug

          tweets = queries.map { |q| search(q) }.flatten
          puts "tweets #{queries.inspect}: #{tweets.size}" if debug

          if tweets.empty?
            tweets = search(hashtag)
            puts "tweets #{hashtag}: #{tweets.size}" if debug
          end

          members = tweets.map { |t| t.user }
          puts "members count: #{members.size}" if debug

          count_freq_words(members.map { |m| m.description  }, special_words: PROFILE_SPECIAL_WORDS, exclude_words: PROFILE_EXCLUDE_WORDS, special_regexp: PROFILE_SPECIAL_REGEXP, exclude_regexp: PROFILE_EXCLUDE_REGEXP, debug: debug).take(limit)
        end

        def list_name_debug(screen_names)
          lists = screen_names.map do |sn|
            puts "fetch #{sn}"
            memberships(sn, count: 500, call_limit: 2)
          end.flatten
          list_exclude_regexp = %r(list[0-9]*|people-ive-faved|twizard-magic-list|my-favstar-fm-list|timeline-list|conversationlist|who-i-met)
          name_exclude_regexp = %r(it|fav|famous|etc|list|people|who|met|abc|and|\d+)

          words = lists.map { |li| li.full_name.split('/')[1] }
              .select { |n| !n.match(list_exclude_regexp) }
              .map { |n| n.split('-') }.flatten
              .delete_if { |w| w.size < 2 || w.match(name_exclude_regexp) }
              .map { |w| normalize_synonym(w) }
              .each_with_object(Hash.new(0)) { |w, memo| memo[w] += 1 }
              .sort_by { |k, v| [-v, -k.size] }
          words.delete_if { |_, v| v == 1 } if words.select { |_, v| v >= 2 }.any?

          File.write('words.txt', words.map(&:first).uniq.sort.select { |w| SYNONYM_WORDS.none? { |sy| sy.include? w } }.join("\n"))
        end

        def list_clusters(user, lists: nil, shrink_limit: 100, list_member: 300, total_member: 3000, total_list: 30, rate: 0.3, limit: 10, debug: false)
          lists = memberships(user, count: 500, call_limit: 2) unless lists
          lists = lists.sort_by { |li| li.member_count }

          puts "#{lists.size} lists" if debug
          return {} if lists.empty?

          File.write('lists.txt', lists.map(&:full_name).join("\n")) if debug

          list_exclude_regexp = %r(list[0-9]*|people-ive-faved|twizard-magic-list|my-favstar-fm-list|timeline-list|conversationlist|who-i-met)
          name_exclude_regexp = %r(it|fav|famous|etc|list|people|who|met|abc|and|\d+)

          # リスト名を - で分割 -> 1文字の単語を除去 -> 出現頻度の降順でソート
          words = lists.map { |li| li.full_name.split('/')[1] }
            .select { |n| !n.match(list_exclude_regexp) }
            .map { |n| n.split('-') }.flatten
            .delete_if { |w| w.size < 2 || w.match(name_exclude_regexp) }
            .map { |w| normalize_synonym(w) }
            .each_with_object(Hash.new(0)) { |w, memo| memo[w] += 1 }
            .sort_by { |k, v| [-v, -k.size] }
          words.delete_if { |_, v| v == 1 } if words.select { |_, v| v >= 2 }.any?

          puts "#{words.size} words: #{words.map { |k, v| "#{k} #{v}" }.join(', ')}" if debug
          return {} if words.empty?

          # 出現頻度の高い単語を名前に含むリストを抽出
          words.size.times.each do |index|
            ws = words.take(index + 1).map(&:first)
            ls = lists.select { |li| ws.any? { |w| li.full_name.split('/')[1].split('-').map { |w| normalize_synonym(w) }.include?(w) } }
            if ls.size >= 2
              words = ws
              lists = ls
              break
            end
          end

          puts "#{lists.size} lists include #{words.inspect}: #{lists.map { |li| li.member_count }.inspect}" if debug
          return {} if lists.empty?

          # 中間の 25-75% のリストを抽出
          while lists.size > shrink_limit
            percentile25 = ((lists.length * 0.25).ceil) - 1
            percentile75 = ((lists.length * 0.75).ceil) - 1
            lists = lists[percentile25..percentile75]
            puts "#{lists.size} lists sliced by 25-75 percentile: #{lists.size} #{lists.map { |li| li.member_count }.inspect}" if debug
          end if lists.size > shrink_limit

          # メンバー数がしきい値内に収まるリストを抽出
          if (ls = lists.select { |li| li.member_count.between?(10, list_member) }).many?
            lists = ls
            puts "#{lists.size} lists limited by 10..#{list_member} members: #{lists.map { |li| li.member_count }.inspect}" if debug
          end

          # トータルメンバー数がしきい値より少なくなるようにリストを抽出
          while lists.sum { |li| li.member_count } >= total_member
            index = lists.map(&:member_count).each.with_index.max[1]
            lists.delete_at(index)
          end if lists.sum { |li| li.member_count } >= total_member

          puts "#{lists.size} lists limited by total #{total_member} members: #{lists.map { |li| li.member_count }.inspect}" if debug
          return {} if lists.empty?

          # リスト数がしきい値より少なくなるようにリストを抽出
          if lists.size >= total_list
            lists = lists[0..(total_list - 1)]
          end

          puts "#{lists.size} lists limited by total #{total_list} lists: #{lists.map { |li| li.member_count }.inspect}" if debug

          members = lists.map do |li|
            begin
              list_members(li.id)
            rescue Twitter::Error::NotFound => e
              puts "#{__method__}: #{li.full_name} is not found. #{li.id} #{li.mode}" if debug
              nil
            end
          end.compact.flatten

          puts "#{members.size} candidate members" if debug
          return {} if members.empty?

          File.write('members.txt', members.map{ |m| m.description.gsub(/\R/, ' ') }.join("\n")) if debug

          # 複数のリストに入っているユーザーのみを抽出
          uids = members.each_with_object(Hash.new(0)) { |member, memo| memo[member.id.to_i] += 1 }.select { |_, v| v >= 2 }.keys
          if uids.size >= 100
            members = uids.map { |uid| members.find { |m| m.id.to_i == uid } }
            puts "#{members.size} members included by 2 and over lists" if debug
          end

          texts = members.map { |m| normalize_moji(m.description) }
          count_freq_words(texts, special_words: PROFILE_SPECIAL_WORDS, exclude_words: PROFILE_EXCLUDE_WORDS, special_regexp: PROFILE_SPECIAL_REGEXP, exclude_regexp: PROFILE_EXCLUDE_REGEXP, debug: debug).take(limit)
        end

        private

        def count_by_word(texts, delim: nil, tagger: nil, min_length: 2, max_length: 5, special_words: [], exclude_words: [], special_regexp: nil, exclude_regexp: nil)
          texts = texts.dup

          frequency = Hash.new(0)
          if special_words.any?
            texts.each do |text|
              special_words.map { |sw| [sw, text.scan(sw)] }
                .delete_if { |_, matched| matched.empty? }
                .each_with_object(frequency) { |(word, matched), memo| memo[word] += matched.size }

            end
          end

          if exclude_regexp
            texts = texts.map { |t| t.remove(exclude_regexp) }
          end

          if delim
            texts = texts.map { |t| t.split(delim) }.flatten.map(&:strip)
          end

          if tagger
            texts = texts.map { |t| tagger.parse(t).split("\n") }.flatten.
              select { |line| line.include?('名詞') }.
              map { |line| line.split("\t")[0] }
          end

          texts.delete_if { |w| w.empty? || w.size < min_length || max_length < w.size || exclude_words.include?(w) || w.match(/\d{2}/) }
            .map { |w| normalize_synonym(w) }
            .each_with_object(frequency) { |word, memo| memo[word] += 1 }
            .sort_by { |k, v| [-v, -k.size] }.to_h
        end

        def count_freq_words(texts, special_words: [], exclude_words: [], special_regexp: nil, exclude_regexp: nil, debug: false)
          candidates, remains = texts.partition { |desc| desc.scan('/').size > 2 }
          slash_freq = count_by_word(candidates, delim: '/', exclude_regexp: exclude_regexp)
          puts "words splitted by /: #{slash_freq.take(10)}" if debug

          candidates, remains = remains.partition { |desc| desc.scan('|').size > 2 }
          pipe_freq = count_by_word(candidates, delim: '|', exclude_regexp: exclude_regexp)
          puts "words splitted by |: #{pipe_freq.take(10)}" if debug

          noun_freq = count_by_word(remains, tagger: build_tagger, special_words: special_words, exclude_words: exclude_words, special_regexp: special_regexp, exclude_regexp: exclude_regexp)
          puts "words tagged as noun: #{noun_freq.take(10)}" if debug

          slash_freq.merge(pipe_freq) { |_, old, neww| old + neww }.
            merge(noun_freq) { |_, old, neww| old + neww }.sort_by { |k, v| [-v, -k.size] }
        end

        def build_tagger
          require 'mecab'
          MeCab::Tagger.new("-d #{`mecab-config --dicdir`.chomp}/mecab-ipadic-neologd/")
        rescue => e
          puts "Add gem 'mecab' to your Gemfile."
          raise e
        end

        def include_hashtags?(tweet)
          tweet.entities&.hashtags&.any?
        end

        def extract_hashtags(tweet)
          tweet.entities.hashtags.map { |h| h.text }
        end

        SYNONYM_WORDS = [
          %w(役者 actress 劇団 舞台),
          %w(アート art artist artists arts 芸術 アーティスト クリエイター),
          %w(av女優 av),
          %w(セレブ celebrity celeb celebs),
          %w(コスプレ cos coser cosplay cosplayer cosplayers コス レイヤー レイヤーさん),
          %w(カルチャー culture),
          %w(ファッション fashion),
          %w(グラビア gravure model models モデル),
          %w(アイドル idol あいどる),
          %w(かわいい kawaii cute),
          %w(音楽 music msc musician musicians ongaku おんがく 音楽家),
          %w(作曲 楽曲),
          %w(サッカー soccer),
          %w(浦和 浦和レッズ),
          %w(写真 photos photo camera カメラ),
          %w(写真集 撮影会),
          %w(タレント talent talents),
          %w(サブカル subcul subculture),
          %w(アニメ anison anime),
          %w(クリエイター creater creator creators creaters creative),
          %w(DJ club dj djs trackmaker),
          %w(デザイン design designer designers),
          %w(レーベル label netlabel),
          %w(企業 company companies 企業),
          %w(ビジネス business economy economics bijinesu biz buisiness businesses keizai 経済),
          %w(投資 金融 相場 ETF 資産 投信 長期投資 投資信託 トレーダー トレード),
          %w(ニュース news journal media メディア 記事 新聞),
          %w(芸能人 famous 有名人 著名人),
          %w(政治 gov government gyousei 政治家),
          %w(行政 gyousei 自治体 地方自治体),
          %w(公式 official officials オフィシャル),
          %w(芸能 entertainment geinou),
          %w(エンジニア engineer engineering programmer developer developers hacker coder programming programer programmer geek rubyist ruby scala java lisp),
          %w(高専 kosen kousen kosenconf),
          %w(趣味 hobby),
          %w(ゲーム game),
          %w(つくば tkb tsukuba),
          %w(アカデミック academic academics academia),
          %w(ブロガー blog bloger blogger bloggers),
          %w(書籍 book books),
          %w(大学 education edu gakusei student students circle colleges daigaku 短大),
          %w(学園祭 gakuensai gakusai 学祭),
          %w(慶應 keio 慶應sfc 慶應義塾 慶應義塾大学),
          %w(早稲田 waseda 早稲田大学),
          %w(東大 todai toudai 東京大学),
          %w(美大 bidai geidai musabi tamabi タマビ ムサビ 多摩美),
          %w(大学公式 大学関係 大学関連 大学関連アカウント 大学広報 大学広報（公式・非公式）),
          %w(学校関係 school schools 学校),
          %w(研究 research researcher study 研究者),
          %w(起業家 entrepreneur entrepreneurs venture startup startups ceo executive スタートアップ 社長 経営 経営者),
          %w(ファイナンス finance founders),
          %w(茨城 ibaragi ibaraki ibrk),
          %w(インフルエンサー influence influencer influencers influential),
          %w(インフォメーション info infomation information informations),
          %w(アイデア idea innovation inspiring),
          %w(アップル apple ios ipad iphone),
          %w(地震 earthquake jishin),
          %w(リーダー leader leaders),
          %w(ライフライン life lifeline saigai shinsai sinsai 防災 震災),
          %w(ローカルニュース local localnews),
          %w(マネジメント management manager),
          %w(メイカー make maker),
          %w(医療 medical),
          %w(映画 movie),
          %w(美術館 museum),
          %w(ショッピング shop shopping shops store),
          %w(WEB web web系),
          %w(インターネット internet),
          %w(観光 travel),
          %w(絵師 illustrator illustrater イラスト),
        ]

        def normalize_synonym(word)
          synonym = word
          SYNONYM_WORDS.each do |dic|
            if dic.include? word
              synonym = dic[0]
              break
            end
          end
          synonym
        end

        require 'moji'

        def normalize_moji(norm)
          norm.tr!("０-９Ａ-Ｚａ-ｚ", "0-9A-Za-z")
          norm = Moji.han_to_zen(norm, Moji::HAN_KATA)
          hypon_reg = /(?:˗|֊|‐|‑|‒|–|⁃|⁻|₋|−)/
          norm.gsub!(hypon_reg, "-")
          choon_reg = /(?:﹣|－|ｰ|—|―|─|━)/
          norm.gsub!(choon_reg, "ー")
          chil_reg = /(?:~|∼|∾|〜|〰|～)/
          norm.gsub!(chil_reg, '')
          norm.gsub!(/[ー]+/, "ー")
          norm.tr!(%q{!"#$%&'()*+,-.\/:;<=>?@[¥]^_`{|}~｡､･｢｣"}, %q{！”＃＄％＆’（）＊＋，－．／：；＜＝＞？＠［￥］＾＿｀｛｜｝〜。、・「」})
          norm.gsub!(/　/, " ")
          norm.gsub!(/ {1,}/, " ")
          norm.gsub!(/^[ ]+(.+?)$/, "\\1")
          norm.gsub!(/^(.+?)[ ]+$/, "\\1")
          while norm =~ %r{([\p{InCjkUnifiedIdeographs}\p{InHiragana}\p{InKatakana}\p{InHalfwidthAndFullwidthForms}\p{InCJKSymbolsAndPunctuation}]+?)[ ]{1}([\p{InCjkUnifiedIdeographs}\p{InHiragana}\p{InKatakana}\p{InHalfwidthAndFullwidthForms}\p{InCJKSymbolsAndPunctuation}]+?)}
            norm.gsub!( %r{([\p{InCJKUnifiedIdeographs}\p{InHiragana}\p{InKatakana}\p{InHalfwidthAndFullwidthForms}\p{InCJKSymbolsAndPunctuation}]+?)[ ]{1}([\p{InCJKUnifiedIdeographs}\p{InHiragana}\p{InKatakana}\p{InHalfwidthAndFullwidthForms}\p{InCJKSymbolsAndPunctuation}]+?)}, "\\1\\2")
          end
          while norm =~ %r{([\p{InBasicLatin}]+)[ ]{1}([\p{InCJKUnifiedIdeographs}\p{InHiragana}\p{InKatakana}\p{InHalfwidthAndFullwidthForms}\p{InCJKSymbolsAndPunctuation}]+)}
            norm.gsub!(%r{([\p{InBasicLatin}]+)[ ]{1}([\p{InCJKUnifiedIdeographs}\p{InHiragana}\p{InKatakana}\p{InHalfwidthAndFullwidthForms}\p{InCJKSymbolsAndPunctuation}]+)}, "\\1\\2")
          end
          while norm =~ %r{([\p{InCJKUnifiedIdeographs}\p{InHiragana}\p{InKatakana}\p{InHalfwidthAndFullwidthForms}\p{InCJKSymbolsAndPunctuation}]+)[ ]{1}([\p{InBasicLatin}]+)}
            norm.gsub!(%r{([\p{InCJKUnifiedIdeographs}\p{InHiragana}\p{InKatakana}\p{InHalfwidthAndFullwidthForms}\p{InCJKSymbolsAndPunctuation}]+)[ ]{1}([\p{InBasicLatin}]+)}, "\\1\\2")
          end
          norm.tr!(
              %q{！”＃＄％＆’（）＊＋，－．／：；＜＞？＠［￥］＾＿｀｛｜｝〜},
              %q{!"#$%&'()*+,-.\/:;<>?@[¥]^_`{|}~}
          )
          norm
        end
      end
    end
  end
end
