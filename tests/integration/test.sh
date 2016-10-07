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

source $(dirname $0)/test-add.sh
source $(dirname $0)/test-command.sh
source $(dirname $0)/test-dump.sh
source $(dirname $0)/test-foreach.sh
source $(dirname $0)/test-freeze.sh
source $(dirname $0)/test-os-filter.sh
source $(dirname $0)/test-set.sh
source $(dirname $0)/test-symlink.sh
source $(dirname $0)/test-update.sh

# TODO
# 1. test submodules
# 2. test selective commands (with dependency path specified)
# 3. test command execution on subpath
# 4. test DependencySet with commit hash

pushd $(dirname $0) > /dev/null
SCRIPTPATH=$(pwd)/../..
popd > /dev/null

export PATH=$SCRIPTPATH:$PATH

# list_tests "$1"
run_tests "$1"
