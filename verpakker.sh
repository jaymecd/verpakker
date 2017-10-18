#!/usr/bin/env bash
# shellcheck disable=SC2059
#
# verpakker - version packer tool for GitHub with Jira integration
#
# Copyright (c) 2017 Nikolai Zujev <nikolai.zujev@gmail.com>
# This source code is provided under the terms of the MIT License
# that can be be found at https://jaymecd.mit-license.org/2017/license.txt
#

set -o pipefail

readonly VERSION="2017-10-10"
readonly COMMAND="${1:-next}"

readonly SELF_BINARY="${BASH_SOURCE[0]}"

readonly RED="\033[0;31m"
readonly GREEN="\033[0;32m"
readonly YELLOW="\033[0;33m"
readonly NC="\033[0m"
LAST_COLOR="${NC}"

readonly MARK_CHECK="\xE2\x9C\x94"
readonly MARK_CROSS="\xE2\x9C\x98"

# read all configured variables
current_version="$(git config --get --local verpakker.version 2>/dev/null)"
github_token="$(git config --get --local verpakker.github-token 2>/dev/null)"
travis_token="$(git config --get --local verpakker.travis-token 2>/dev/null)"
jira_token="$(git config --get --local verpakker.jira-token 2>/dev/null)"
jira_domain="$(git config --get --local verpakker.jira-domain 2>/dev/null)"
jira_projects="$(git config --get --local verpakker.jira-projects 2>/dev/null)"
jira_prefix="$(git config --get --local verpakker.jira-prefix 2>/dev/null)"
jira_description="$(git config --get --local verpakker.jira-description 2>/dev/null)"

input_pipe () {
  test ! -t 0
}

fetch_input () {
  input_pipe && cat - || echo -e "$1"
}

highlight () {
  printf "${YELLOW}%s${LAST_COLOR}" "$1"
}

info () {
  local IFS=$'\n'
  local lines=( $(fetch_input "$1") )
  input_pipe || shift

  LAST_COLOR="${NC}"
  printf "${1:-%s}\n" "${lines[@]}" >&2
}

success () {
  local IFS=$'\n'
  local lines=( $(fetch_input "$1") )
  input_pipe || shift

  LAST_COLOR="${GREEN}"
  printf " ${LAST_COLOR}${MARK_CHECK} ${1:-%s}${NC}\n" "${lines[@]}" >&2
}

warn () {
  local IFS=$'\n'
  local lines=($(fetch_input "$1"))
  input_pipe || shift

  LAST_COLOR="${RED}"
  printf " ${LAST_COLOR}${MARK_CROSS} ${1:-%s}${NC}\n" "${lines[@]}" >&2
}

fatal () {
	local status="$1"; shift

  printf " ${RED}${MARK_CROSS} ERROR: %s${NC}\n" "$@" >&2
  exit "${status}"
}

# No by default
confirm () {
  read -r -p "${1:-Are you sure? [y/N]} " response
  case "${response}" in
    [yY][eE][sS]|[yY])
      true
      ;;
    *)
      false
      ;;
  esac
}

run_safety_checks () {
  check_installed

  [[ "${GIT_BARE}" == "false" ]] || fatal 2 'this is bare repository'
  [[ "${GIT_DIRTY}" == "false" ]] || fatal 2 'the repository is dirty; commit or stash your changes first'

  validate_access_tokens
}

check_installed () {
  [ -n "${current_version}" ] || fatal 3 "verpakker is not installed in this repository"

  [ -n "${github_token}" ] || fatal 3 "github token is empty"
	[ -n "${travis_token}" ] || fatal 3 "travis token is empty"
	[ -n "${jira_token}" ] || fatal 3 "jira token is empty"
	[ -n "${jira_domain}" ] || fatal 3 "jira domain is empty"
	[ -n "${jira_projects}" ] || fatal 3 "jira projects are empty"

  if [ "${VERSION//-}" -gt "${current_version//-}" ]; then
    info 
    info " $(highlight "[UPDATES]") New configuration $(highlight "${VERSION}") is available, current is $(highlight "${current_version}")."
    info "           Consider to run '$(highlight "verpakker init")' to apply new configuration."
    info 
  fi
}

init_configuration () {
  [ -n "${GIT_REPO}" ] || fatal 2 "outside of git repository"

  [ -n "${GITHUB_TOKEN}" ] || read -p "GITHUB_TOKEN: [${github_token}] " GITHUB_TOKEN
  github_token="${GITHUB_TOKEN:-$github_token}"
  [ -n "${github_token}" ] || fatal 1 "missing GITHUB_TOKEN"

  [ -n "${TRAVIS_TOKEN}" ] || read -p "TRAVIS_TOKEN: [${travis_token}] " TRAVIS_TOKEN
  travis_token="${TRAVIS_TOKEN:-$travis_token}"
  [ -n "${travis_token}" ] || fatal 1 "missing TRAVIS_TOKEN"

  [ -n "${JIRA_TOKEN}" ] || read -p "JIRA_TOKEN: [${jira_token}] " JIRA_TOKEN
  jira_token="${JIRA_TOKEN:-$jira_token}"
  [ -n "${jira_token}" ] || fatal 1 "missing JIRA_TOKEN"

  [ -n "${JIRA_DOMAIN}" ] || read -p "JIRA_DOMAIN: [${jira_domain}] " JIRA_DOMAIN
  jira_domain="${JIRA_DOMAIN:-$jira_domain}"
  [ -n "${jira_domain}" ] || fatal 1 "missing JIRA_DOMAIN"

  [ -n "${JIRA_PROJECTS}" ] || read -p "JIRA_PROJECTS: [${jira_projects}] " JIRA_PROJECTS
  jira_projects="${JIRA_PROJECTS:-$jira_projects}"
  [ -n "${jira_projects}" ] || fatal 1 "missing JIRA_PROJECTS"

  [ -n "${JIRA_PREFIX}" ] || read -p "JIRA_PREFIX: [${jira_prefix}] " JIRA_PREFIX
  jira_prefix="${JIRA_PREFIX:-$jira_prefix}" # optional

  [ -n "${JIRA_DESCRIPTION}" ] || read -p "JIRA_DESCRIPTION: [${jira_description}] " JIRA_DESCRIPTION
  jira_description="${JIRA_DESCRIPTION:-$jira_description}" # optional
}

confirm_configuration () {
	local answer

	printf 'This repository metadata:\n'
	printf '     GIT_WORK_TREE : %s\n' "${GIT_REPO}"
	printf '\nNew configuration will be saved\n'
	printf '      GITHUB_TOKEN : %s\n' "${github_token}"
	printf '      TRAVIS_TOKEN : %s\n' "${travis_token}"
	printf '        JIRA_TOKEN : %s\n' "${jira_token}"
	printf '       JIRA_DOMAIN : %s\n' "${jira_domain}"
	printf '     JIRA_PROJECTS : %s\n' "${jira_projects}"
	printf '       JIRA_PREFIX : %s\n' "${jira_prefix}"
	printf '  JIRA_DESCRIPTION : %s\n' "${jira_description}"
	printf '\n'

  if ! confirm "Does this look correct? [y/N] "; then
		fatal 1 'configuration has been aborted'
	fi
}

display_configuration() {
	printf 'This repository was configured using verpakker (%s)\n' "$(highlight "${current_version}")"
	printf '     GIT_WORK_TREE : %s\n' "${GIT_REPO}"
	printf '\nThe current configuration:\n'
	printf '      GITHUB_TOKEN : %s\n' "${github_token}"
	printf '      TRAVIS_TOKEN : %s\n' "${travis_token}"
	printf '        JIRA_TOKEN : %s\n' "${jira_token}"
	printf '       JIRA_DOMAIN : %s\n' "${jira_domain}"
	printf '     JIRA_PROJECTS : %s\n' "${jira_projects}"
	printf '       JIRA_PREFIX : %s\n' "${jira_prefix}"
	printf '  JIRA_DESCRIPTION : %s\n' "${jira_description}"
  printf '\nConfigured git aliases:\n'
  printf '   - %s\n' $(git config  --name-only --get-regexp '^alias\.verpak-' | sed -e 's/^alias\.//')
}

save_configuration() {
  clean_configuration

	git config --local verpakker.version "${VERSION}"
	git config --local verpakker.github-token "${github_token}"
	git config --local verpakker.travis-token "${travis_token}"
	git config --local verpakker.jira-token "${jira_token}"
	git config --local verpakker.jira-domain "${jira_domain}"
	git config --local verpakker.jira-projects "${jira_projects}"
	git config --local verpakker.jira-prefix "${jira_prefix}"
	git config --local verpakker.jira-description "${jira_description}"

	git config --local alias.verpak-next "!${SELF_BINARY} next"
  git config --local alias.verpak-patch "!${SELF_BINARY} patch"
}

clean_configuration () {
	git config --local --remove-section verpakker 2>/dev/null
	git config --local --unset alias.verpak-next 2>/dev/null
  git config --local --unset alias.verpak-patch 2>/dev/null

  if ! git config --local --get-regexp '^alias\.' >/dev/null 2>&1; then
    git config --local --remove-section "alias" 2>/dev/null;
  fi
}

generate_tag () {
  local prevTag="$1"
  local do_patch=$(( $2 ))

  local major=$(( $(echo "${prevTag}" | awk -F. '{print $1}' | sed -e 's/v//') ))
  local minor=$(( $(echo "${prevTag}" | awk -F. '{print $2}') ))
  local patch=$(( $(echo "${prevTag}" | awk -F. '{print $3}') ))

  local yearWeek=$(( $(date +"%g%V") ))

  if (( do_patch )); then {
    patch=$(( patch+1 ))
  }
  elif [ ${yearWeek} -ne ${major} ]; then
    major=${yearWeek}
    minor=0
    patch=0
  else  
    minor=$(( minor+1 ))
    patch=0
  fi

  echo "v${major}.${minor}.${patch}"
}

pack_next_version () {
  run_safety_checks

  local tag="$(generate_tag "${GIT_LAST_TAG}")"

  info "Preparing NEXT $(highlight "${tag}") version for $(highlight "${GIT_REPO_OWNER}") project:"

  pack_version "${tag}"

  success "Congrats! verpakker has created NEXT $(highlight "${tag}") version"
}

pack_patch_version () {
  run_safety_checks

  local tag="$(generate_tag "${GIT_LAST_TAG}" 1)"

  info "Preparing PATCH $(highlight "${tag}") version for $(highlight "${GIT_REPO_OWNER}") project:"

  pack_version "${tag}"

  success "Congrats! verpakker has created PATCH $(highlight "${tag}") version"
}

pack_version () {
  local tag="${1}"
  local jira_version="${jira_prefix}$(echo "${tag%.*}" | sed -e 's/^v//')"

  local diff="$(git log "${GIT_LAST_TAG}...${GIT_COMMIT}" --no-merges --format="- %h : %s [%cd]" --date=short --reverse)"

  [ -n "${diff}" ] || fatal 2 "git: no difference - already merged or not yet committed"

  local descr="$(echo "${diff}" |
          sed 's_\s*\[skip\s\+ci\]\s*_ _g' |
          sed "s_\([A-Z]\{2,\}-[0-9]\+\)_[\1](https://${jira_domain}/browse/\1)_g" |
          sed 's_\s\+_ _g')"

  local tickets=( $(echo "${descr}" | grep -vi ' : revert ' | grep -o '[A-Z]\{2,\}-[0-9]\+' | sort -n | uniq) )

  local ticket_count=$(echo "${tickets[@]}" | wc -w | awk '{print $1}')
  local revert_count=$(echo "${descr}" | grep -i ' : revert ' | wc -l | awk '{print $1}')
  local commit_count=$(echo "${descr}" | wc -l | awk '{print $1}')

  local travis_icon="[![Build Status](https://travis-ci.com/${GIT_REPO_OWNER}.svg?token=${travis_token}&branch=${tag})](https://travis-ci.com/${GIT_REPO_OWNER}/branches)"
  local changelog_url="[changed files](https://github.com/${GIT_REPO_OWNER}/compare/${GIT_LAST_TAG}...${tag}#files_bucket)"
  local jira_search_url=""

  if [ ${#tickets[@]} -gt 0 ]; then
    jira_search_url="[jira filter](https://${jira_domain}/issues/?jql=id+IN+($(IFS=','; echo "${tickets[*]}"))) | "
  fi

  local headline="**${ticket_count}** tickets + **${revert_count}** reverts by **${commit_count}** commits | ${jira_search_url}${changelog_url}"

  descr="$(echo -e "${headline}\n\n${travis_icon}\n\n${descr}")"

  echo
  echo "  github: pre-release"
  if [ ${#tickets[@]} -gt 0 ]; then
  echo "    jira: $(highlight "$(IFS=', '; echo "${tickets[*]}")") => $(highlight "${jira_version}")"
  else 
  echo "    jira: -"
  fi
  echo
  echo "  branch: $(highlight "${GIT_BRANCH}")"
  echo "  commit: ${GIT_COMMIT}"
  echo "  origin: $(highlight "${GIT_ORIGIN_URL}")"
  echo "    diff: ${GIT_LAST_TAG}...${tag}"
  echo
  echo "${descr}" | sed 's/^/          /g'
  echo

  if ! confirm "Ready to make $(highlight "${tag}") release for $(highlight "${GIT_REPO_OWNER}")? [y/N]"; then
    echo "Aborted..." 2>&1
    exit 1
  fi

  create_git_tag "${tag}"

  if [ ${#tickets[@]} -gt 0 ]; then
    create_jira_fixversion "${jira_version}" "${tickets[@]}"
  fi

  create_github_release "${GIT_REPO_OWNER}" "${GIT_COMMIT}" "${tag}" "${descr}"
}

fetch_git_tag () {
  git fetch -t -q && success "git: local tags are updated from origin" || fatal 5 "git: failed to fetch origin tags"
}

create_git_tag () {
  local tag="${1:-}"

  [ -n "${tag}" ] || fatal 4 "provide git tag"

  git tag "${tag}" "${GIT_SIGN_TAG:+-s}" -m "${tag}" && success "git: new tag created" || fatal 5 "git: failed to tag the commit"
  git push origin "${tag}" -q && success "git: new tag pushed to origin" || fatal 5 "git: failed to push tag to origin"
}

validate_access_tokens () {
  validate_github_token
  validate_jira_token
}

validate_github_token () {
  local response
  local httpCode
  local auth_user

  response="$(curl -sS -w ' @@@@@ %{http_code}' -m 5 \
      -H "Accept: application/json" \
      -H "Authorization: token ${github_token}" \
      "https://api.github.com/user")"

  [ $? -eq 0 ] || fatal 5 "github: connection failure"

  httpCode=$(( ${response##* @@@@@ } ))
  response="${response% @@@@@ *}"

  [ ${httpCode} -ne 401 ] || fatal 5 "github: authentication failed"

  auth_user="$(echo "${response}" | jq -r '.login')"

  success "github: authenticated as $(highlight "${auth_user}")"
}

validate_jira_token () {
  local response
  local httpCode
  local auth_user

  response="$(curl -sS -w ' @@@@@ %{http_code}' -m 5 \
      -H "Accept: application/json" \
      -H "Authorization: Basic ${jira_token}" \
      "https://${jira_domain}/rest/api/2/myself")"

  [ $? -eq 0 ] || fatal 5 "jira: connection failure"

  httpCode=$(( ${response##* @@@@@ } ))
  response="${response% @@@@@ *}"

  [ ${httpCode} -ne 401 ] || fatal 5 "jira: authentication failed"

  auth_user="$(echo "${response}" | jq -r '.key')"

  success "jira: authenticated as $(highlight "${auth_user}")"
}

create_github_release () {
  local owner_repo="${1:-}"
  local commit="${2:-}"
  local tag="${3:-}"
  local body="${4:-}"
  local response
  local httpCode

  [ -n "${owner_repo}" ] || fatal 4 "provide GitHub owner/repo"
  [ -n "${commit}" ] || fatal 4 "provide GitHub commit"
  [ -n "${tag}" ] || fatal 4 "provide GitHub tag"
  [ -n "${body}" ] || fatal 4 "provide GitHub body"

  response="$(curl -sS -w ' @@@@@ %{http_code}' -m 5 \
      -H "Content-Type: application/json" -H "Accept: application/json" \
      -H "Authorization: token ${github_token}" \
      -X POST -d "$(jo tag_name="${tag}" target_commitish="${commit}" name="${tag}" body="${body}" prerelease=true)" \
      "https://api.github.com/repos/${owner_repo}/releases")"

  [ $? -eq 0 ] || fatal 5 "github: connection failure"

  httpCode=$(( ${response##* @@@@@ } ))
  response="${response% @@@@@ *}"

  [ ${httpCode} -ne 401 ] || fatal 5 "github: authentication failed"

  if [ ${httpCode} -ge 400 ]; then
    echo "${response}"
    fatal 5 "github: (${httpCode}) failed to create release page for $(highlight "${tag}") tag"
  fi

  local url="$(echo "${response}" | jq -r '.html_url')"

  success "github: release page created $(highlight "${url}")"
}

create_jira_fixversion () {
  local version="${1:-}"; shift
  local tickets=($@)
  local projects=( ${jira_projects} )

  [ -n "${version}" ] || fatal 4 "provide JIRA version"
  [ -n "${tickets}" ] || fatal 4 "provide JIRA tickets"

  local ticket
  local project
  local payload
  local response
  local httpCode

  for ticket in "${tickets[@]-}"; do
    project="${ticket/-[0-9]*/}"

    if [[ " ${projects[@]-} " =~ " ${project} " ]]; then
      payload="$(jo -- -s name="${version}" project="${project}" description="${jira_description}")"

      response="$(curl -sS -w ' @@@@@ %{http_code}' -m 5 \
          -H "Content-Type: application/json" -H "Accept: application/json" \
          -H "Authorization: Basic ${jira_token}" \
          -X POST -d "${payload}" \
          "https://${jira_domain}/rest/api/2/version")"

      [ $? -eq 0 ] || fatal 5 "jira: connection failure"

      httpCode=$(( ${response##* @@@@@ } ))
      response="${response% @@@@@ *}"

      [ ${httpCode} -ne 401 ] || fatal 5 "jira: authentication failed"

      if echo "${response}" | jq -r '.errors.name' | grep -q 'version with this name already exists'; then
        success "jira: version $(highlight "${version}") for $(highlight "${project}") project is already created"
        continue
      fi

      if [ ${httpCode} -ge 400 ]; then
        fatal 5 "jira: (${httpCode}) error: $(echo "${response}" | jq -r '.errors.name')"
      fi

      success "jira: version $(highlight "${version}") for $(highlight "${project}") project is created"
    fi
   done

   for ticket in "${tickets[@]-}"; do
     project="${ticket/-[0-9]*/}"

     if [[ " ${projects[@]-} " =~ " ${project} " ]]; then
        payload="$(jo update=$(jo fixVersions=$(jo -a $(jo add=$(jo -- -s name="${version}")))))"

        response="$(curl -sS -w ' @@@@@ %{http_code}' -m 5 \
          -H "Content-Type: application/json" -H "Accept: application/json" \
          -H "Authorization: Basic ${jira_token}" \
          -X PUT -d "${payload}" \
          "https://${jira_domain}/rest/api/2/issue/${ticket}")"

        [ $? -eq 0 ] || fatal 5 "jira: connection failure"

        httpCode=$(( ${response##* @@@@@ } ))
        response="${response% @@@@@ *}"

        [ ${httpCode} -ne 401 ] || fatal 5 "jira: authentication failed"

        if [ ${httpCode} -ge 400 ]; then
          fatal 5 "jira: (${httpCode}) error: $(echo "${response}" | jq -r '.errors.name')"
        fi

        success "jira: ticket $(highlight "${ticket}") is updated with $(highlight "${version}") version"
      fi
  done
}

#################################################

if input_pipe; then
  fatal 1 "verpakker must run from tty"
fi

for cmd in {awk,git,curl,jo,jq}; do
  command -v $cmd > /dev/null || fatal 1 'required command "%s" was not found' "$cmd"
done

case "${COMMAND}" in
  next|patch)
    info "verpakker is warming up ..."
    fetch_git_tag
    ;;
esac

readonly GIT_REPO="$(git rev-parse --show-toplevel 2>/dev/null)"
readonly GIT_ORIGIN_URL="$(git config --get remote.origin.url 2>/dev/null)"
readonly GIT_REPO_OWNER="$(echo "${GIT_ORIGIN_URL}" | sed -En 's_^(git@|https://)?github.com(:|/)(.*)_\3_p' | sed 's_\.git$__')"
readonly GIT_BARE="$(git rev-parse --is-bare-repository 2>/dev/null)"
readonly GIT_DIRTY="$(git diff-index --quiet HEAD -- 2>/dev/null && echo "false" || echo "true")"
readonly GIT_LAST_TAG="$(git describe --abbrev=0 --tags --match="v[0-9]*.[0-9]*.[0-9]*" HEAD 2>/dev/null)"
readonly GIT_BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
readonly GIT_COMMIT="$(git rev-parse --verify HEAD 2>/dev/null)"
readonly GIT_SIGN_TAG="$(git config --get user.signingkey >/dev/null 2>&1 && echo 1 || true)"

case "${COMMAND}" in
  init)
    init_configuration
    confirm_configuration
    save_configuration
    success "verpakker was installed to this reporitory"
    ;;
  show)
    check_installed
    display_configuration
    ;;
  uninstall)
    check_installed
    clean_configuration
    success "verpakker was uninstalled from this reporitory"
    ;;
  next)
    pack_next_version
    ;;
  patch)
    pack_patch_version
    ;;
  *)
    fatal 1 "Undefined command: ${COMMAND}"
esac
