#!/bin/bash

# $1: dev branch name
# $2: master branch name

dev_branch=${1:-dev}
master_branch=${2:-master}

curr_branch=$(git rev-parse --abbrev-ref HEAD | tail -1)

if test "${curr_branch}" != "master"; then
    echo "Please run this script on masater branch"
    exit 1
fi

git cherry-pick \
    "$(git merge-base "${master_branch}" "${dev_branch}")".."${dev_branch}"