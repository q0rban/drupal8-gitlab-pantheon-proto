#!/usr/bin/env bash

set -e

# Inspired by:
# https://github.com/IlyaSemenov/gitlab-ci-git-push/blob/master/git-push

USAGE=$(cat <<-Usage
To use this script, you'll need to generate a private key that GitLab can use.
The following command will create a new private key in your ~/.ssh directory
called gitlab-ci, and associated public key, gitlab-ci.pub.

$ ssh-keygen -t rsa -b 4096 -f ~/.ssh/gitlab-ci

Use an empty passphrase when prompted. Once generated, go to: GitLab > Project
> Settings > CI/CD Pipelines > Secret Variables, and add a variable called
SSH_PRIVATE_KEY. Paste the contents of the private key in gitlab-ci to this
variable. Do not toggle the Protected switch. Then, go to GitHub and add a new
deploy key called GitLab CI with write permissions, and paste the public key
value from gitlab-ci.pub.

Once complete, you might want to delete the key files, or store the private
key in an encrypted password store (such as LastPass or 1Password). It's
important to keep this key safe, so if you fear it might have been compromised
just generate a new key and update the associated GitLab and GitHub settings.
Usage
)

# This is the URL of the GitHub repo.
GITHUB_URL="git@github.com:q0rban/drupal8-gitlab-pantheon-proto.git"
# This script needs to make a commit to the repo. Here is where you identify the
# author of that commit.
COMMIT_AUTHOR_EMAIL="james+gitlab@lullabot.com"
COMMIT_AUTHOR_NAME="GitLab CI"
# This is the suffix appended to the ref that is being built. For example, if
# this is a tag of 1.2.3, and the suffix is -compiled, the script will create
# a new tag of 1.2.3-compiled. Likewise, a branch of foo, will create a new
# branch called foo-compiled.
REFNAME_SUFFIX="-compiled"

function usage() {
	echo "Usage: $0"
	echo
	echo "$USAGE"
}

function echoerr() {
	echo "$@" 1>&2
	echo
	usage
	exit 23
}

# Cleanup the id_rsa key on completion or error.
function cleanup() {
	# It would be bad if this accidentally ran on someone's local. Let's ensure
	# this is a gitlab-ci environment.
	if [[ -z "$CI_JOB_ID" ]]; then
		echo "Not running on GitLab. No cleanup performed."
	else
		echo "Removing ~/.ssh/id_rsa."
		rm ~/.ssh/id_rsa
	fi
}

# If we encounter any errors during this script, ensure our private key is
# removed for security purposes. See https://docs.gitlab.com/runner/security/
trap cleanup ERR

# Ensure the SSH_PRIVATE_KEY value is set. If it's not, please read the above
# instructions on how to generate one.
if [[ -z "$SSH_PRIVATE_KEY" ]]; then
	echoerr "Missing SSH_PRIVATE_KEY environment variable."
fi

# Add the directories we want to commit.
git add ./vendor ./web --force

# If we don't have a tag, assume this is a branch.
if [[ -z "$CI_COMMIT_TAG" ]]; then
	REFNAME="${CI_COMMIT_REF_NAME}${REFNAME_SUFFIX}"
	git checkout -b "$REFNAME"
	git commit -m "Committing compiled code for $CI_COMMIT_REF_NAME."
# Otherwise, create a new tag.
else
	REFNAME="${CI_COMMIT_TAG}${REFNAME_SUFFIX}"
	git commit -m "Committing compiled code for $CI_COMMIT_TAG."
	git tag -a "${CI_COMMIT_TAG}${REFNAME_SUFFIX}" -m "Compiled code for $CI_COMMIT_TAG."
fi

SSH_HOST=$(echo $GITHUB_URL | sed 's/.*@//' | sed 's/[:/].*//')
if [ -z "$SSH_HOST" ]; then
	echoerr "Invalid GITHUB_URL. Should be in the format <user@git.host:project | ssh://user@git.host:port/project>."
fi

# Install the private key and ensure the git repo URL is added to known_hosts.
if [[ -f ~/.ssh/id_rsa ]]; then
	echoerr "There's already an id_rsa file and we don't want to overwrite it."
fi
echo "Installing GitLab private key."
mkdir -p ~/.ssh
echo "$SSH_PRIVATE_KEY" | tr -d '\r' > ~/.ssh/id_rsa
chmod 600 ~/.ssh/id_rsa
ssh-keyscan -H "$SSH_HOST" >> ~/.ssh/known_hosts

# Now push the new tag or branch to GitHub!
echo "Pushing $REFNAME to GitHub."
git push $GITHUB_URL $REFNAME $([ -z "$DISABLE_FORCE_PUSH" ] && echo --force)

# Cleanup after ourselves.
cleanup
