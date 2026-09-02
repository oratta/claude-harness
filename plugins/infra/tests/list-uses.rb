#!/usr/bin/env ruby
# frozen_string_literal: true
#
# S16a（infra-fixes.bats の check_third_party_pins）の抽出部。
# 引数の YAML ファイルを本当にパースし、任意の深さの mapping にある `uses` キーを
# 全数列挙して 1 件 1 行で stdout に出す:
#
#   <値の開始行（1 始まり）>\t<値の終了行（1 始まり）>\t<値の終了列（0 始まり・終端の次）>\t<値>
#
# 行 grep でキー形を追いかける旧方式は、flow mapping の前置キーの引用値
# （`- { name: "uses: actions/cache@v4", uses: evil/action@v1 }` /
# `- { name: "a#b", uses: evil/action@v1 }`）がコメント境界・公式判定を騙る形を
# 素通りしていた（#198）。パーサに任せればキー・値・コメントの区別は YAML の
# 文法どおりに付き、パターンを追いかける必要がなくなる（#182 の当たり所）。
#
# - キーは引用の有無を問わず Scalar 値が `uses` のもの（`"uses":` / `'uses':` を含む）
# - 値が Scalar でない（mapping / sequence / null 以外の複合値）ときは値を空にして出す
#   （検査側の値形チェックで違反に落ちる＝fail-closed）
# - 値の終了列は、検査側が「値より後ろ」から同一行のバージョンコメントを切り出すために使う
# - パースできないファイルは非 0 で終了する（検査側が違反として扱う）

require 'yaml'

def walk(node, &blk)
  if node.is_a?(Psych::Nodes::Mapping)
    node.children.each_slice(2) do |key, value|
      blk.call(key, value) if key.is_a?(Psych::Nodes::Scalar) && key.value == 'uses'
      walk(key, &blk)
      walk(value, &blk)
    end
  elsif node.respond_to?(:children) && node.children
    node.children.each { |child| walk(child, &blk) }
  end
end

path = ARGV.fetch(0)
doc = Psych.parse_file(path)
exit 0 unless doc

walk(doc) do |_key, value|
  text = value.is_a?(Psych::Nodes::Scalar) ? value.value : ''
  puts [value.start_line + 1, value.end_line + 1, value.end_column, text].join("\t")
end
