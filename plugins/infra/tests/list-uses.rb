#!/usr/bin/env ruby
# frozen_string_literal: true
#
# S16a（infra-fixes.bats の check_third_party_pins）の抽出部。
# 引数の YAML ファイルを本当にパースし、任意の深さの mapping にある `uses` キーを
# 全数列挙して 1 件 1 行で stdout に出す:
#
#   <値の開始行（1 始まり）>\t<値の終了行（1 始まり）>\t<同じ行のコメント部分>\t<値>
#
# 行 grep でキー形を追いかける旧方式は、flow mapping の前置キーの引用値
# （`- { name: "uses: actions/cache@v4", uses: evil/action@v1 }` /
# `- { name: "a#b", uses: evil/action@v1 }`）がコメント境界・公式判定を騙る形を
# 素通りしていた（#198）。パーサに任せればキー・値・コメントの区別は YAML の
# 文法どおりに付き、パターンを追いかける必要がなくなる（#182 の当たり所）。
#
# - ファイルは `---` 区切りの複数 document をすべて走査する（`Psych.parse_file` は
#   最初の document しか返さないので、2 つ目以降に置いた `uses` が素通りしていた）
# - キーは引用の有無を問わず Scalar 値が `uses` のもの（`"uses":` / `'uses':` を含む）
# - 値が Scalar でない（mapping / sequence / null 以外の複合値）ときは値を空にして出す
#   （検査側の値形チェックで違反に落ちる＝fail-closed）
# - コメント部分は、値の開始行のうち「その行で終わる Scalar / Alias / flow collection の
#   終端位置」の最大値より後ろで最初に現れる `#` から行末まで。そこより後ろに残るのは
#   flow の終端記号・空白・コメントだけなので、引用値の中の `#`（`"a\"# v1 "`）や
#   flow context の plain scalar に含まれる `#`（`x#v1`）を境界と取り違えない。
#   コメントが無い行、または値の行で始まって次行に続く Scalar（`"multi #v1\n line"`）が
#   ある行（＝行末までが本文でコメントを置けない）は `-` を出す（検査側の形チェックで
#   違反に落ちる）。列を空にしないのは、検査側の `IFS=$'\t' read` が空の列を潰すため
# - 値とコメントに含まれる改行・タブは空白に置き換える（TSV の行・列を注入させない。
#   改行やタブを含む値は正しい固定形になり得ないので、置換しても判定は変わらない）
# - パースできない・読めないファイルは非 0 で終了する（検査側が違反として扱う）

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

# 行番号（0 始まり）ごとに、その行で終わる本文ノードの終端列の最大値（ends）と、
# その行で始まって次行以降まで続く Scalar があるか（spanning）を集める。
# block style の Mapping / Sequence は終端が次行の先頭に置かれるので数えない。
def collect_line_ends(node, ends, spanning)
  case node
  when Psych::Nodes::Scalar, Psych::Nodes::Alias
    (node.start_line...node.end_line).each { |line| spanning[line] = true }
    ends[node.end_line] = [ends[node.end_line], node.end_column].max
  when Psych::Nodes::Mapping, Psych::Nodes::Sequence
    if node.style == Psych::Nodes::Mapping::FLOW
      ends[node.end_line] = [ends[node.end_line], node.end_column].max
    end
  end
  return unless node.respond_to?(:children) && node.children

  node.children.each { |child| collect_line_ends(child, ends, spanning) }
end

def comment_on(lines, line, ends, spanning)
  return '-' if spanning[line]

  rest = lines[line].to_s.chomp[ends[line]..-1].to_s
  index = rest.index('#')
  index ? rest[index..-1] : '-'
end

path = ARGV.fetch(0)
text = File.read(path, mode: 'r:bom|utf-8')
stream = Psych.parse_stream(text, filename: path)
lines = text.lines
ends = Hash.new(0)
spanning = {}
collect_line_ends(stream, ends, spanning)

walk(stream) do |_key, value|
  comment = comment_on(lines, value.start_line, ends, spanning)
  value_text = value.is_a?(Psych::Nodes::Scalar) ? value.value : ''
  puts [
    value.start_line + 1,
    value.end_line + 1,
    comment.tr("\n\t", '  '),
    value_text.tr("\n\t", '  ')
  ].join("\t")
end
