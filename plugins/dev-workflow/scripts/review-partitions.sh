#!/bin/sh
# PR files API のパス順を標準入力に渡す:
# gh api repos/$R/pulls/$N/files --paginate --jq '.[] | "\(.additions + .deletions)\t\(.filename)"' | review-partitions.sh
set -eu

awk '
  BEGIN { total = 0 }
  {
    tab = index($0, "\t")
    count = substr($0, 1, tab - 1)
    if (!tab || count !~ /^[0-9]+$/) {
      print $0 > "/dev/stderr"
      bad = 1
      exit 2
    }
    files[++file_count] = substr($0, tab + 1)
    lines[file_count] = count + 0
    total += lines[file_count]
  }
  END {
    if (bad) exit 2
    print "合計: " total " 行"
    if (total <= 600) {
      print "区画: なし"
      exit
    }
    for (i = 1; i <= file_count; i++) {
      if (lines[i] == 0) {
        if (!sections) {
          sections = 1
          open = 1
        }
      } else if (lines[i] > 400) {
        sections++
        open = 0
      } else if (!open || section_lines[sections] + lines[i] > 400) {
        sections++
        open = 1
      }
      assigned[i] = sections
      section_lines[sections] += lines[i]
    }
    print "区画: " sections
    for (section = 1; section <= sections; section++) {
      print "区画 " section "/" sections "（" section_lines[section] " 行）"
      for (i = 1; i <= file_count; i++)
        if (assigned[i] == section)
          print "- " files[i] "（" lines[i] " 行）"
    }
  }
'
