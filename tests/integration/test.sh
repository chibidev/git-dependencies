#!/bin/bash

source $(dirname $0)/shtest/test.sh

function create_repo() {
  mkdir $1
  cd $1
  git init .
  echo "some lines" > README
  git add .
  git commit --all -m 'Initial commit'
  cd ..
}

function create_branch_on_remote() {
  cd $1
  pwd
  git branch almafa
  cd ..
}

function create_branch() {
  cd $1
  pwd
  git checkout -b almafa
  cd ..
}

function setup() {
  create_repo dependency3 > /dev/null
  create_repo dependency2 > /dev/null
  create_repo dependency > /dev/null
  create_repo project > /dev/null
}

# parse and source test files
for test_file in $(ls $(dirname $0) | grep "test-.*.sh$"); do
  source "$(dirname $0)/$test_file"
done

# TODO
# 1. test submodules
# 2. test selective commands (with dependency path specified)
# 3. test command execution on subpath
# 4. test DependencySet with commit hash

pushd $(dirname $0) > /dev/null
SCRIPTPATH=$(dirname $0)/../..
popd > /dev/null

export PATH=$SCRIPTPATH:$PATH

# list_tests "$1"
run_tests "$1"
