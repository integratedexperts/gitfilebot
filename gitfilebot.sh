#!/usr/bin/env bash
##
# GitFileBot
#
# Process multiple repositories at once.
#
# Processing sequence for each repository:
# - Checkout repository
# - Copy source files from `add` subdirectory and remove files from `remove` subdirectory
# - Replace `name` and `machine_name` tokens (see example.process.sh for format)
# - Force-push changes to origin
# - Open PR if it has not been opened yet. HUB (tool used to communicate with
#   GitHub via API) does not support updating descriptions of already opened
#   pull requests.
#
# Requirements:
# 1. Install hub from https://github.com/github/hub
# 2. Create GitHub API token
# 3. Create file `$HOME/.config/hub` with the following content:
#    ```
#    github.com:
#    - user: <your username>
#      oauth_token: <your token>
#      protocol: https
#    ```
#
# Usage:
# cp example.process.sh process.sh
# ... modify process.sh and adjust values ...
# ./process.sh
#

# Source of files as a first argument.
SRC="${1:-}"
# Array of repositories
REPOSITORIES="${REPOSITORIES:-}"
# New branch name.
NEW_BRANCH=${NEW_BRANCH:-updates}
# Commit message.
COMMIT_MESSAGE="${COMMIT_MESSAGE:-"Updated files."}"
# Pull request description file name (should not be a part of the SRC directory).
# If file is does not exist - commit message will be used.
PR_FILE=${PR_FILE:-$(pwd)/pr.md}

main(){
  { [ -z "${REPOSITORIES}" ] || [ "${#REPOSITORIES[@]}" -eq 0 ]; } && echo "ERROR: Please provide an array of repositories" && exit 1

  [ "${SRC}" == "" ] && echo "ERROR: Please provide location to the files repository as a first argument" && exit 1
  [ ! -d "${SRC}" ] && echo "ERROR: Provided location to the files repository does not exist" && exit 1
  ! command -v "hub" > /dev/null && echo "ERROR: Please install Hub from https://github.com/github/hub" && exit 1

  count=0
  PR_URLS=()
  for i in "${REPOSITORIES[@]}";
  do
    if (( count % 3 == 0 )); then
      repo="${i}"
    elif (( count % 3 == 1 )); then
      name="${i}"
    else
      machine_name="${i}"

      line "Processing repository \"${repo}\" with title \"${name}\" and machine name \"${machine_name}"\"

      repo_tmp=$(mktemp -d)
      step "Cloning ${repo} to ${repo_tmp}"
      git clone "${repo}" "${repo_tmp}"
      git --work-tree="${repo_tmp}" --git-dir="${repo_tmp}/.git" checkout -b "${NEW_BRANCH}"

      src_tmp=$(mktemp -d)
      step "Backing up source files to ${src_tmp}"
      rsync -r -u -I --exclude '.git' "${SRC}/." "${src_tmp}/"

      step "Replacing tokens in the source files"
      replace_string_content "_machine_name_" "${machine_name}" "${src_tmp}"
      replace_string_content "_name_" "${name}" "${src_tmp}"

      step "Writing updated files"
      # Remove files in 'remove' directory.
      if [ -d "${src_tmp}/remove" ]; then
        for file in "$(find "${src_tmp}/remove" -type f)";
        do
          file=${file:${#src_tmp}}
          file=${file:7}
          echo "Removing ${repo_tmp}/${file}"
          rm -f "${repo_tmp}/${file}" > /dev/null
        done
      fi
      # Add files in 'add' directory.
      if [ -d "${src_tmp}/add" ]; then
        rsync -r -u -I --exclude '.git' "${src_tmp}/add/." "${repo_tmp}/"
      fi

      step "Commit changes"
      git --work-tree="${repo_tmp}" --git-dir="${repo_tmp}/.git" add .
      git --work-tree="${repo_tmp}" --git-dir="${repo_tmp}/.git" commit -m "${COMMIT_MESSAGE}"
      git --work-tree="${repo_tmp}" --git-dir="${repo_tmp}/.git" push --force origin "${NEW_BRANCH}"

      # @note: HUB has limitations to not update PR message.
      open_pull_request "${repo_tmp}" "${NEW_BRANCH}" "${COMMIT_MESSAGE}" "${PR_FILE}"
    fi

    count=$(( count+1 ))
  done

  if [ "${#PR_URLS[@]}" -ne 0 ]; then
    step "Created PRs"
    printf '%s\n' "${PR_URLS[@]}"
  fi
}

open_pull_request(){
  local dir="${1}"
  local branch="${2}"
  local msg="${3}"
  local file="${4:-}"
  local base_branch="${5:-}"
  local title
  local url

  pushd "${dir}" >/dev/null || exit 1

    if [ -f "${file}" ]; then
      read -r title < "${file}"
    else
      title="${msg}"
    fi

    if hub pr list -h "${branch}" | grep -q "${title}"; then
      step "Skipping - Pull Request already exists"
    else
      step "Opening Pull request"
      if [ -f "${file}" ]; then
        echo "---------------------------------------------------------------"
        cat "${file}"
        echo "---------------------------------------------------------------"

        url=$(hub pull-request \
          -F "${file}" \
          -b "${base_branch}" \
          -h "${branch}"
          )
      else
        echo "---------------------------------------------------------------"
        echo "${title}"
        echo "---------------------------------------------------------------"

        url=$(hub pull-request \
          -m "${title}" \
          -b "${base_branch}" \
          -h "${branch}"
          )
      fi

      if [ "${url}" != "" ]; then
        PR_URLS+=("${url}")
       fi
    fi

  popd > /dev/null || exit 1
}

replace_string_content() {
  local needle="${1}"
  local replacement="${2}"
  local dir="${3}"
  local sed_opts

  sed_opts=(-i) && [ "$(uname)" == "Darwin" ] && sed_opts=(-i '')
  grep -rI \
    --exclude-dir=".git" \
    --exclude-dir=".idea" \
    --exclude-dir="vendor" \
    --exclude-dir="node_modules" \
    -l "${needle}" "${dir}" \
    | xargs sed "${sed_opts[@]}" "s@$needle@$replacement@g"
}

line(){
  printf "$(tput -Txterm setaf 2)==> ${1}$(tput -Txterm sgr0)${2}\n"
}

step(){
  printf "$(tput -Txterm setaf 4)   ${1}$(tput -Txterm sgr0)${2}\n"
}

main "$@"
