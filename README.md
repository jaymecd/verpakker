# GitHub / Jira release tool

`verpakker` is a tool for continuous version (tag) creation.
It could create `next` or `patch` version based on semver-like notation.

`NB!` Still under **hard** development.

## Version notation

Currently supported `vYYWW.N.P` notation, where

- `YYWW` - is a year/week abbreviation
- `N` - is a weekly number increment
- `P` - is a patch increment

## Installation

```
$ git clone git@github.com:jaymecd/verpacker.git ~/verpacker
```

Initialize `verpakker`:

```
$ cd my/project/to/deploy
$ ~/verpacker/verpakker.sh init
```

- `GITHUB_TOKEN` - GitHub personal access token
- `TRAVIS_TOKEN` - TravisCI token (required for pivate repositoeries)
- `JIRA_TOKEN` - JIRA BasicAuth token (`$ echo "user:pass" | base64`)

    It's required to reset password, if you get HTTP 401 back while password is correct.

- `JIRA_DOMAIN` - JIRA domain
- `JIRA_PROJECTS` - JIRA tracked projects
- `JIRA_PREFIX` - JIRA version prefix
- `JIRA_DESCRIPTION` - JIRA version description

Observe configuration:

```
$ ~/verpacker/verpakker.sh show
```

## Usage

```
$ git verpak-next
```

```
$ git verpak-patch
```