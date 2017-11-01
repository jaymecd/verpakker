# GitHub / Jira release tool

`verpakker` is a tool for continuous version (tag) creation.
It could create `next` or `patch` version based on semver-like notation.

`NB!` Still under **hard** development.

## Version notation

Currently supported `vYYWW.N.P` notation, where

- `YYWW` - is a year/week abbreviation
- `N` - is a weekly number increment
- `P` - is a patch increment

## Dependencies

- standard system tools: `bash`, `awk`, `git`, `curl`
- [jo](https://github.com/jpmens/jo) - to create `JSON` string
- [jq](https://stedolan.github.io/jq/) - to parse `JSON` string

On MacOS (OSX) could be installed with [Homebrew](https://brew.sh/):

```
$ brew install bash awk git curl
$ brew install jo jq
```

## Installation

```
$ git clone git@github.com:jaymecd/verpakker.git ~/verpakker
```

Initialize `verpakker`:

```
$ cd my/project/to/deploy
$ ~/verpakker/verpakker.sh init
```

- `GITHUB_TOKEN` - GitHub personal access token
- `TRAVIS_TOKEN` - TravisCI token (required for pivate repositoeries)
- `JIRA_TOKEN` - JIRA BasicAuth token (`$ echo "user:pass" | base64`)

    > if you get HTTP 401 error with correct password, it's required to reset password via JIRA 'forgot password' form.
    > More info on this weird behaviour - [JRACLOUD-66793](https://jira.atlassian.com/browse/JRACLOUD-66793)

- `JIRA_DOMAIN` - JIRA domain
- `JIRA_PROJECTS` - JIRA tracked projects, space separated list
- `JIRA_PREFIX` - JIRA version prefix *(optional)*

    If next tag is `v1741.2.3`, JIRA version would created as `${JIRA_PREFIX}1741.2`.

- `JIRA_DESCRIPTION` - JIRA version description *(optional)*

Observe configuration:

```
$ ~/verpakker/verpakker.sh show
```

## Usage

```
$ git verpak-next
```

```
$ git verpak-patch
```
