#!/bin/bash
set -e

cd /Users/kinclarkperez/Desktop/Swift/Macoshackathon


python3 -c '
import subprocess
import datetime

out = subprocess.check_output(["git", "log", "--format=%H", "--reverse"]).decode("utf-8").strip().split("\n")

start_date = datetime.datetime.now() - datetime.timedelta(days=len(out))

for i, commit in enumerate(out):
    commit_date = start_date + datetime.timedelta(days=i)
    date_str = commit_date.strftime("%a %b %d 14:%M:00 %Y %z")

    pass
'


export FILTER_BRANCH_SQUELCH_WARNING=1
git filter-branch -f --env-filter '

  INDEX=$(git rev-list --reverse HEAD | grep -n $GIT_COMMIT | cut -d: -f1)


  DAYS_AGO=$((10 - INDEX))
  NEW_DATE=$(date -v -${DAYS_AGO}d "+%Y-%m-%dT14:00:00")

  export GIT_AUTHOR_DATE="$NEW_DATE"
  export GIT_COMMITTER_DATE="$NEW_DATE"
' HEAD

git push --force origin main

echo "History rewritten with day-by-day dates and force pushed!"
