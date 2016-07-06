require 'twitter_with_auto_pagination/rest/utils'

module TwitterWithAutoPagination
  module REST
    module Extension
      module Clusters
        include TwitterWithAutoPagination::REST::Utils

        def clusters_belong_to(text)
          return [] if text.blank?

          exclude_words = JSON.parse(File.read(Rails.configuration.x.constants['cluster_bad_words_path']))
          special_words = JSON.parse(File.read(Rails.configuration.x.constants['cluster_good_words_path']))

          # クラスタ用の単語の出現回数を記録
          cluster_word_counter =
            special_words.map { |sw| [sw, text.scan(sw)] }
              .delete_if { |item| item[1].empty? }
              .each_with_object(Hash.new(1)) { |item, memo| memo[item[0]] = item[1].size }

          # 同一文字種の繰り返しを見付ける。漢字の繰り返し、ひらがなの繰り返し、カタカナの繰り返し、など
          text.scan(/[一-龠〆ヵヶ々]+|[ぁ-んー～]+|[ァ-ヴー～]+|[ａ-ｚＡ-Ｚ０-９]+|[、。！!？?]+/).

            # 複数回繰り返される文字を除去
            map { |w| w.remove /[？！?!。、ｗ]|(ー{2,})/ }.

            # 文字数の少なすぎる単語、ひらがなだけの単語、除外単語を除去する
            delete_if { |w| w.length <= 1 || (w.length <= 2 && w =~ /^[ぁ-んー～]+$/) || exclude_words.include?(w) }.

            # 出現回数を記録
            each { |w| cluster_word_counter[w] += 1 }

          # 複数個以上見付かった単語のみを残し、出現頻度順にソート
          cluster_word_counter.select { |_, v| v > 3 }.sort_by { |_, v| -v }.to_h
        end

        def clusters_assigned_to
          raise NotImplementedError
        end
      end
    end
  end
end
