#!/bin/bash
# scripts/extract-reviews.sh
# Extracts # REVIEW: annotations from a file and formats them for agent input.
#
# Supports two formats:
#   Single line:
#     # REVIEW: your feedback
#     affected_code_line
#
#   Multi-line block:
#     # REVIEW: START your feedback
#     affected line one
#     affected line two
#     # REVIEW: END
#
# Usage: ./extract-reviews.sh <file>

FILE="${1:?Usage: extract-reviews.sh <file>}"

echo -e "FILE: ${FILE}\n---"
awk '
/^[[:space:]]*# REVIEW: START/ {
  # Extract the feedback from the START line
  feedback = $0
  gsub(/^[[:space:]]*# REVIEW: START[[:space:]]*/, "", feedback)
  start_line = NR + 1
  body = ""

  # Collect lines until END tag
  while ((getline line) > 0) {
    NR++
    if (line ~ /^[[:space:]]*# REVIEW: END/) {
      end_line = NR - 1
      print "Lines " start_line "-" end_line ":"
      print body
      print "Feedback: " feedback
      print "---"
      break
    }
    body = body line "\n"
  }
  next
}

/^[[:space:]]*# REVIEW:/ {
  # Single-line review — grab the next line as target
  feedback = $0
  gsub(/^[[:space:]]*# REVIEW:[[:space:]]*/, "", feedback)
  if ((getline target) > 0) {
    NR++
    print "Line " NR ":"
    print target
    print "Feedback: " feedback
    print "---"
  }
  next
}
' "$FILE"
