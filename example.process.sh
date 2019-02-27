#!/usr/bin/env bash
##
# Example to run GitFileBot.
#

# Array of repositories with name and machine_name tokens.
export REPOSITORIES=(
  "git@github.com:yourorg/repo1.git" "Repo1" "repo1"
  "git@github.com:yourorg/repo2.git" "Repo2" "repo2"
  "git@github.com:yourorg/repo3.git" "Repo3" "repo3"
)

# Commit message to be used for committing files.
export COMMIT_MESSAGE="Added new feature."

# Branch to create on remote.
export NEW_BRANCH=update-docs

# Pull request description file name (should not be a part of the SRC directory).
# If file is does not exist - commit message will be used.
export PR_FILE=example.pr.md

# Do not forget to create `add` and `remove` subdirectories with your files.
source gitfilebot.sh /absolute/path/to/src
