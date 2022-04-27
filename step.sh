#!/bin/bash
set -ex

echo "Trigger Paths: $TRIGGER_PATHS"

brew install grep

git fetch origin "$BITRISE_GIT_BRANCH"

# Get previous merge commit
DIFF_COMMIT="$(git rev-list --merges --max-count=1 origin/${BITRISE_GIT_BRANCH})"

if [ -z "$DIFF_COMMIT" ]
then
  echo "No previous merge commit detected. Skipping selective builds."
  exit 0
fi

DIFF_FILES="$(git diff --name-only ${DIFF_COMMIT})"

set +x
PATH_PATTERN=$(ruby -e 'puts ENV["TRIGGER_PATHS"].strip.split("\n").map { |e| e.gsub("/", "\\") }.join("|") ')

echo "PATH_PATTERN: $PATH_PATTERN"
set -x

check_app_diff ()
{
    set +e
    echo $DIFF_FILES | ggrep -E $1
    exit_status=$?
    if [[ $exit_status = 1 ]]; then
      echo "No changes detected. Aborting build."
      curl -X POST \
        https://api.bitrise.io/v0.1/apps/$BITRISE_APP_SLUG/builds/$BITRISE_BUILD_SLUG/abort \
        -H "authorization: token $BITRISE_TOKEN" \
        -H 'content-type: application/json; charset=UTF-8' \
        -d '{
        "abort_reason": "Build skipped. No changes detected.",
          "skip_notifications": true,
          "abort_with_success": true
      }'
    else
      echo "Changes detected. Running build."
    fi
    set -e
}

check_app_diff "$PATH_PATTERN"

exit 0
