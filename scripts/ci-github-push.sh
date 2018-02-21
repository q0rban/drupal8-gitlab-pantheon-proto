#!/usr/bin/env bash

set -ex
# Adapted from:
# https://github.com/IlyaSemenov/gitlab-ci-git-push/blob/master/git-push

url=git@github.com:q0rban/drupal8-gitlab-pantheon-proto.git
branch=${1:-master}

if [ -z "$SSH_PRIVATE_KEY" ]; then
	>&2 echo "Set the SSH_PRIVATE_KEY environment variable. Go to GitLab > Project > Settings > CI/CD Pipelines > Secret Variables, and add a variable called SSH_PRIVATE_KEY."
	exit 1
fi

ssh_host=$(echo $url | sed 's/.*@//' | sed 's/[:/].*//')
if [ -z "$ssh_host" ]; then
	>&2 echo "Usage: $0 <user@git.host:project | ssh://user@git.host:port/project> [<branch>]"
	exit 1
fi

# TODO: skip on multiple runs
mkdir -p ~/.ssh
echo "$SSH_PRIVATE_KEY" | tr -d '\r' > ~/.ssh/id_rsa
chmod 600 ~/.ssh/id_rsa
ssh-keyscan -H "$ssh_host" >> ~/.ssh/known_hosts

echo "Pushing ${CI_COMMIT_SHA:-HEAD}:$branch to GitHub."

git push $url ${CI_COMMIT_SHA:-HEAD}:$branch $([ -z "$DISABLE_FORCE_PUSH" ] && echo --force)
