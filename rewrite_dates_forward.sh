#!/bin/bash
set -e

cd /Users/kinclarkperez/Desktop/Swift/Macoshackathon

export FILTER_BRANCH_SQUELCH_WARNING=1
git filter-branch -f --env-filter '
  INDEX=$(git rev-list --reverse HEAD | grep -n $GIT_COMMIT | cut -d: -f1)

  DAYS_FORWARD=$((INDEX - 1))
  NEW_DATE=$(date -v +${DAYS_FORWARD}d "+%Y-%m-%dT14:00:00")

  export GIT_AUTHOR_DATE="$NEW_DATE"
  export GIT_COMMITTER_DATE="$NEW_DATE"
' HEAD

git push --force origin main

echo "History rewritten with forward day-by-day dates and force pushed!"
