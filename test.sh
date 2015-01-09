#!/bin/bash

source shtest/test.sh

function create_repo() {
    mkdir $1
    cd $1
    git init .
    echo "some lines" > README
    git add .
    git commit --all -m 'Initial commit'
    cd ..
}

function setup() {
    create_repo dependency2 > /dev/null
    create_repo dependency > /dev/null
    create_repo project > /dev/null
}

function DependencyAddTest() {
    cd project
    expect git dependencies add "../dependency" dep master
    expect [[ -f .gitdepends ]]
    expect "[[ \"$(cat .gitdepends | grep 'ref = master')\" != '' ]]"
}

function DependencyCloneTest() {
    cd dependency
    local hash=$(git rev-parse HEAD)
    cd ..
    cd project
    expect git dependencies add "../dependency" dep master
    expect git dependencies update
    expect [[ -d dep ]]
    expect [[ -x dep ]]
    expect [[ -r dep ]]
    cd dep
    expect [[ $(git rev-parse HEAD) == "$hash" ]]
}

function DependencyUpdateTest() {
    cd project
    expect git dependencies add "../dependency" dep master
    expect git dependencies update
    cd ../dependency
    echo "some other lines" >> README
    git commit --all -m 'Another commit'
    local hash=$(git rev-parse HEAD)
    cd ../project
    expect git dependencies update
    cd dep
    expect [[ $(git rev-parse HEAD) == "$hash" ]]
    expect [[ $(git rev-parse --abbrev-ref HEAD) == "master" ]]
}

function DependencyBranchSwitchTest() {
    cd dependency
    git checkout -b feature
    echo "Some additional info" >> README_FEATURE
    git add .
    git commit -m 'Some additional change'
    local hash=$(git rev-parse HEAD)
    cd ../project
    expect git dependencies add "../dependency" dep master
    expect git dependencies update
    cd dep
    expect [[ ! -e README_FEATURE ]]
    expect [[ $(git rev-parse --abbrev-ref HEAD) == "master" ]]
    cd ..
    sed -i .orig 's/ref = master/ref = feature/' .gitdepends
    git dependencies update
    cd dep
    expect [[ -e README_FEATURE ]]
    expect [[ $(git rev-parse HEAD) == "$hash" ]]
    expect [[ $(git rev-parse --abbrev-ref HEAD) == "feature" ]]
}

function DependencyBranchSwitchToNewBranchOnRemoteTest() {
    cd project
    expect git dependencies add "../dependency" dep master
    expect git dependencies update
    cd ../dependency
    git checkout -b feature
    echo "Some additional info" >> README_FEATURE
    git add .
    git commit -m 'Some additional change'
    hash=$(git rev-parse HEAD)
    cd ../project
    sed -i .orig 's/ref = master/ref = feature/' .gitdepends
    expect git dependencies update
    cd dep
    expect [[ -e README_FEATURE ]]
    expect [[ $(git rev-parse HEAD) == "$hash" ]]
    expect [[ $(git rev-parse --abbrev-ref HEAD) == "feature" ]]
}

function Issue1_DependencyFreezeUnfreezeTest() {
    cd project
    expect git dependencies add "../dependency" dep master
    expect git dependencies update
    git add .
    git commit -m 'Adding dependency'
    expect git dependencies freeze
    cd dep
    local hash=$(git rev-parse HEAD)
    cd ../../dependency
    echo "Some other lines" >> README
    git commit --all -m 'Another commit'
    local depHash=$(git rev-parse HEAD)
    cd ../project
    expect git dependencies update
    cd dep
    expect [[ $(git rev-parse HEAD) == "$hash" ]]
    expect [[ $(git rev-parse --abbrev-ref HEAD) == "HEAD" ]]
    cd ..
    expect git dependencies unfreeze
    cd dep
    expect [[ $(git rev-parse HEAD) == "$depHash" ]]
    expect [[ $(git rev-parse --abbrev-ref HEAD) == "master" ]]
}

function Issue2_DependencyFreezeUnclonedTest() {
    cd dependency
    local hash=$(git rev-parse HEAD)
    cd ../project
    expect git dependencies add '../dependency' dep master
    git add .
    git commit -m 'Adding dependency'
    expect git dependencies freeze
    cd dep
    expect [[ $(git rev-parse HEAD) == "$hash" ]]
    expect [[ $(git rev-parse --abbrev-ref HEAD) == "HEAD" ]]
}

function Issue3_DependencyPathUpdateTest() {
    cd project
    expect git dependencies add "../dependency" dep master
    expect git dependencies update
    cd ../dependency
    echo "some other lines" >> README
    git commit --all -m 'Another commit'
    local hash=$(git rev-parse HEAD)
    cd ../project
    expect git dependencies update dep
    cd dep
    expect [[ $(git rev-parse HEAD) == "$hash" ]]
    expect [[ $(git rev-parse --abbrev-ref HEAD) == "master" ]]
}

function Issue4_DependencyUpdateFreezedTest() {
    cd dependency
    local hash=$(git rev-parse HEAD)
    cd ../project
    expect git dependencies add '../dependency' dep master
    expect git dependencies update
    git add .
    git commit -m 'Adding dependency'
    expect git dependencies freeze
    rm -rf dep
    expect git dependencies update
    cd dep
    expect [[ $(git rev-parse HEAD) == "$hash" ]]
    expect [[ $(git rev-parse --abbrev-ref HEAD) == "HEAD" ]]
}

function Issue5_DependencyUnfreezeUnclonedTest() {
    cd project
    expect git dependencies add '../dependency' dep master
    git add .
    git commit -m 'Adding dependency'
    expect git dependencies freeze
    cd ../dependency
    echo 'some other lines' >> README
    git commit --all -m 'Another commit'
    local hash=$(git rev-parse HEAD)
    cd ../project
    expect git dependencies unfreeze
    cd dep
    expect [[ $(git rev-parse HEAD) == "$hash" ]]
    expect [[ $(git rev-parse --abbrev-ref HEAD) == 'master' ]]
}

function Issue6_DependencyRecursiveUpdateTest() {
    cd project
    expect git dependencies add '../dependency' dep master
    git add .
    git commit -m 'Adding dependency'
    expect git dependencies update
    cd ../dependency
    expect git dependencies add '../dependency2' dep master
    git add .
    git commit -m 'Adding dependency'
    expect git dependencies update
    # cd ../dependency
    echo 'some other lines ' >> README
    git commit --all -m 'Another commit'
    local depHash=$(git rev-parse HEAD)
    cd ../dependency2
    echo 'some other lines' >> README
    git commit --all -m 'Another commit2'
    local depHash2=$(git rev-parse HEAD)
    cd ../project
    expect git dependencies update --recursive
    cd dep
    expect [[ $(git rev-parse HEAD) == "$depHash" ]]
    cd dep
    expect [[ $(git rev-parse HEAD) == "$depHash2" ]]
}

function DependencyRecursiveFreezeTest() {
    cd dependency
    expect git dependencies add '../dependency2' dep master
    git add .
    git commit -m 'Adding dependency'
    local depHash=$(git rev-parse HEAD)
    cd ../dependency2
    local depHash2=$(git rev-parse HEAD)
    cd ../project
    expect git dependencies add '../dependency' dep master
    git add .
    git commit -m 'Adding dependency'
    expect git dependencies freeze --recursive
    cd dep
    local depHash=$(git rev-parse HEAD)
    expect [[ $(git rev-parse --abbrev-ref HEAD) == 'HEAD' ]]
    cd dep
    expect [[ $(git rev-parse HEAD) == "$depHash2" ]]
    expect [[ $(git rev-parse --abbrev-ref HEAD) == 'HEAD' ]]
    cd ../../../dependency
    echo 'some other lines' >> README
    git commit --all -m 'Another commit'
    cd ../dependency2
    echo 'some other lines' >> README
    git commit --all -m 'Another commit2'
    cd ../project
    expect git dependencies update --recursive
    cd dep
    expect [[ $(git rev-parse HEAD) == "$depHash" ]]
    expect [[ $(git rev-parse --abbrev-ref HEAD) == 'HEAD' ]]
    cd dep
    expect [[ $(git rev-parse HEAD) == "$depHash2" ]]
    expect [[ $(git rev-parse --abbrev-ref HEAD) == 'HEAD' ]]
}

function DependencyRecursiveUnfreezeTest() {
    cd dependency
    expect git dependencies add '../dependency2' dep master
    git add .
    git commit -m 'Adding dependency'
    cd ../project
    expect git dependencies add '../dependency' dep master
    git add .
    git commit -m 'Adding dependency'
    expect git dependencies freeze --recursive
    cd dep
    local depHash=$(git rev-parse HEAD)
    cd ../../dependency2
    echo 'some other lines' >> README
    git commit --all -m 'Another commit2'
    local depHash2=$(git rev-parse HEAD)
    cd ../project
    expect git dependencies unfreeze -r
    cd dep
    expect [[ $(git rev-parse HEAD) != "$depHash" ]]
    expect [[ $(git rev-parse --abbrev-ref HEAD) == 'master' ]]
    cd dep
    expect [[ $(git rev-parse HEAD) == "$depHash2" ]]
    expect [[ $(git rev-parse --abbrev-ref HEAD) == 'master' ]]
}

# TODO
# 1. test submodules
# 2. test selective commands (with dependency path specified)

pushd $(dirname $0) > /dev/null
SCRIPTPATH=$(pwd)
popd > /dev/null

export PATH=$SCRIPTPATH:$PATH

run_tests
