#!/bin/bash

OWNER="hmcc-global"
REPO="hmcchk-web"
API_VERSION="2022-11-28"
ZIP_OUTPUT="${HOME}/release.zip"
DEPLOY_DIR="$HOME/hmcchk-web"

get_artifact_id() {
  local run_id="$1"
  local git_token="$2"
  local artifact_id=0

  # Send a GET request to retrieve the artifacts for the specified run ID
  response=$(curl -L \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer ${git_token}" \
    -H "X-GitHub-Api-Version: ${API_VERSION}" \
    "https://api.github.com/repos/${OWNER}/${REPO}/actions/runs/${run_id}/artifacts")

  # Extract the artifact ID from the response
  artifact_id=$(echo "$response" | jq -r '.artifacts[0].id')

  if [[ -z "$artifact_id" ]]; then
    echo "Error: No artifacts found for run ID: $run_id" >&2
    exit 1
  fi

  echo "$artifact_id"
}

download_artifact() {
  local artifact_id="$1"
  local git_token="$2"

  # Send a GET request to download the specified artifact
  curl -L \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer ${git_token}" \
    -H "X-GitHub-Api-Version: ${API_VERSION}" \
    "https://api.github.com/repos/${OWNER}/${REPO}/actions/artifacts/${artifact_id}/zip" -o $ZIP_OUTPUT

  if [[ $? -ne 0 ]]; then
    echo "Error: Failed to download artifact with ID: $artifact_id" >&2
    exit 1
  fi
}

decompress_artifact() {
  # TODO-aparedan: Change these to variable and sync with Workflow variable
  unzip -q -o $ZIP_OUTPUT -d $HOME & wait $!
  unzip -q -o $HOME/release.zip -d $HOME/deploy & wait $!
}

# Get the run ID from the command-line arguments
run_id="$1"
git_token="$2"
if [[ -z "$run_id" ]]; then
  echo "Error: No run ID specified" >&2
  exit 1
fi

# Retrieve the artifact ID for the specified run ID
artifact_id=$(get_artifact_id "$run_id" "$git_token")

echo $artifact_id
# Download the artifact with the specified ID
download_artifact "$artifact_id" "$git_token"

# Decompress zip
decompress_artifact

# Delete folders from hmcchk-web/ folder as mv command cannot merge folders
rm -rf $DEPLOY_DIR/server $DEPLOY_DIR/ui $DEPLOY_DIR/node_modules

# Move contents from $HOME/deploy to hmcchk-web/ folder
mv -f $HOME/deploy/* $DEPLOY_DIR

# Reload pm2
pm2 reload 0
