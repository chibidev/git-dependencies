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

function DependencySetTest() {
    create_branch dependency
    cd project
    expect git dependencies add "../dependency" dep master
    expect git dependencies update dep
    expect [[ -f .gitdepends ]]
    expect git dependencies set dep almafa
    expect "[[ \"$(cat .gitdepends | grep 'ref = almafa')\" != '' ]]"
}

function DependencySetRemoteRefTest() {
    create_branch_on_remote dependency
    cd project
    expect git dependencies add "../dependency" dep master
    expect git dependencies update dep
    expect [[ -f .gitdepends ]]
    expect git dependencies set dep almafa
    expect "[[ \"$(cat .gitdepends | grep 'ref = almafa')\" != '' ]]"
}

function DependencySetWithoutExplicitUpdateTest() {
    create_branch dependency
    cd project
    expect git dependencies add "../dependency" dep master
    expect [[ -f .gitdepends ]]
    expect git dependencies set dep almafa
    expect "[[ \"$(cat .gitdepends | grep 'ref = almafa')\" != '' ]]"
}

function DependencySetInvalidRefTest() {
    create_branch dependency
    cd project
    expect git dependencies add "../dependency" dep master
    expect git dependencies update dep
    expect [[ -f .gitdepends ]]
    expect git dependencies set dep kortefa
    expect "[[ \"$(cat .gitdepends | grep 'ref = master')\" != '' ]]"
}

function DependencySetInvalidPathTest() {
    create_branch dependency
    cd project
    expect git dependencies add "../dependency" dep master
    expect git dependencies update dep
    expect [[ -f .gitdepends ]]
    expect git dependencies set bananfa kortefa
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
    sed -i.orig 's/ref = master/ref = feature/' .gitdepends
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
    sed -i.orig 's/ref = master/ref = feature/' .gitdepends
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

function DependencyDumpAfterFreezeTest() {
    cd project
    expect git dependencies add '../dependency' dep master
    git add .
    git commit -m 'Adding dependency'
    expect git dependencies freeze
    expect git dependencies dump
}

function DependencyForeachGitCommandTest() {
    local branch='test'
    cd project
    expect git dependencies add "../dependency" dep master
    expect git dependencies add "../dependency2" dep2 master
    expect git dependencies update
    git add .
    git commit -m 'Adding dependencies'
    expect git dependencies foreach "\"checkout -b $branch\""
    cd dep
    expect [[ $(git rev-parse --abbrev-ref HEAD) == "$branch" ]]
    cd ../dep2
    expect [[ $(git rev-parse --abbrev-ref HEAD) == "$branch" ]]
}

function DependencyForeachShellCommandTest() {
    cd project
    expect git dependencies add "../dependency" dep master
    expect git dependencies add "../dependency2" dep2 master
    expect git dependencies update
    git add .
    git commit -m 'Adding dependencies'

    expect git dependencies foreach '"!sh touch test"'
    expect [[ -e "dep/test" ]]
    expect [[ -e "dep2/test" ]]
}

function DependencyForeachRecurseTest() {
    local branch='test'
    cd dependency
    expect git dependencies add '../dependency2' dep master
    git add .
    git commit -m 'Adding dependency'
    cd ../project
    expect git dependencies add '../dependency' dep master
    git add .
    git commit -m 'Adding dependency'
    expect git dependencies update -r
    expect git dependencies -r foreach "\"checkout -b $branch\""

    cd dep
    expect [[ $(git rev-parse --abbrev-ref HEAD) == "$branch" ]]
    cd dep
    expect [[ $(git rev-parse --abbrev-ref HEAD) == "$branch" ]]
}

# function DependencyForeachPipeTest() {
#     cd project
#     expect git dependencies add '../dependency' dep master
#     git add .
#     git commit -m 'Adding dependency'
#     expect git dependencies update -r
#     git dependencies foreach '!sh cat README | grep lines'
# }
#
# function DependencyForeachSubCommandTest() {
#     cd project
#     expect git dependencies add '../dependency' dep master
#     git add .
#     git commit -m 'Adding dependency'
#     expect git dependencies update -r
#     expect [[ "$(git dependencies foreach '!sh echo `cat README`')" == "some lines" ]]
# }
#
# function DependencyForeachRedirectOutputTest() {
#     cd project
#     expect git dependencies add '../dependency' dep master
#     git add .
#     git commit -m 'Adding dependency'
#     expect git dependencies update -r
#     git dependencies foreach '!sh cat README > README2'
# }

function DependencyUpdateTestUrlModificationWithNoChange() {
	cd dependency2
	local hash=$(git rev-parse HEAD)
	cd ../project
	expect git dependencies add '../dependency' dep master
	git add .
	git commit -m 'Adding dependency'

	expect git dependencies update -r

	sed -i.bak 's/url = .*/url = ..\/dependency2/' .gitdepends
	expect git dependencies update
	cd dep
	expect [[ "$(git rev-parse HEAD)" == "$hash" ]]
}

function DependencyUpdateTestUrlModificationWithUnpushedChange() {
	cd dependency2
	local hash=$(git rev-parse HEAD)
	cd ../project
	expect git dependencies add '../dependency' dep master
	git add .
	git commit -m 'Adding dependency'

	expect git dependencies update -r

	cd dep
	touch kortefa
	git add kortefa
	git commit -m 'kortefa'

	cd ..

	sed -i.bak 's/url = .*/url = ..\/dependency2/' .gitdepends
	expect git dependencies update
	cd dep
	expect [[ "$(git rev-parse HEAD^)" == "$hash" ]]
	expect [[ -f kortefa ]]
	expect [[ "$(git status -s)" == "" ]]
}

# function DependencyUpdateTestRecursiveUrlModificationWithNoChange() {
# }

function DependencyUpdateTestWithUTF8Character() {
    cd project
    expect git dependencies add '../dependency' dep master
    git add .
    git commit -m 'Adding dependency'

    expect git dependencies update -r

    cd ../dependency
    touch almafa
    git add .
    git commit -m '”'

    cd ../project
    expect git dependencies update -r
}

function DependencyCommandSetterTests() {
  cd project
  expect git dependencies add '../dependency' dep master
  git add .
  git commit -m 'Adding dependency'
  expect git dependencies update -r

  git dependencies command dep "!sh echo \$(pwd)"
  local result=$(cat .gitdepends | grep 'command')
  expect [[ ${#result} -gt 0 ]]
  expect [[ "\"$result\"" == "\"command = !sh echo \$(pwd)\"" ]]

  git dependencies command dep "!sh echo \$(pwd) > sample.txt && ls"
  local result2=$(cat .gitdepends | grep 'command')
  expect [[ ${#result2} -gt 0 ]]
  expect [[ "\"$result2\"" == "\"command = !sh echo \$(pwd) > sample.txt && ls\"" ]]

  git dependencies command dep ""
  local result3=$(cat .gitdepends | grep 'command')
  expect [[ ${#result3} -eq 0 ]]
}

function DependencyCommandRunnerTests_SimpleDep() {

  cd dependency
  echo $'#!/bin/bash\n\necho \"Hello World!\"' > sample.sh
  chmod u+x sample.sh
  git add .
  git commit -m "Add shell script"

  cd ../project
  expect git dependencies add '../dependency' dep master
  git add .
  git commit -m 'Adding dependency'
  expect git dependencies update -r

  git dependencies command dep "!sh sh ./dep/sample.sh > hello.txt"

  git dependencies update

  expect [[ -f hello.txt ]]
  expect [[ "\"$(cat hello.txt)\"" == "\"Hello World!\"" ]]

  git dependencies command dep "!sh ln -s dep/README README_LINK"
  git dependencies update
  expect [[ -L README_LINK ]]
}

function DependencyCommandRunnerTests_MultipleDep_ShellCmd() {

  create_repo subDependency > /dev/null

  cd subDependency
  local subDependencyPath="$(pwd)"

  cd ../dependency
  expect git dependencies add "$subDependencyPath" sub master
  git dependencies command sub "!sh pwd"
  git add .
  git commit -m "Add subDependency"
  local dependencyPath="$(pwd)"

  cd ../project
  local projectPath="$(pwd)"
  expect git dependencies add "$dependencyPath" dep master
  git dependencies command dep "!sh pwd"
  git add .
  git commit -m 'Adding dependency'

  git dependencies update -r > update.log

  expect [[ "\"$(cat update.log | head -3 | tail -1)\"" == *"\"$projectPath/dep\"" ]]
  expect [[ "\"$(cat update.log | head -4 | tail -1)\"" == *"\"$projectPath\"" ]]
}

function DependencyCommandRunnerTests_MultipleDep_GitTask() {

  create_repo subDependency > /dev/null

  cd subDependency
  local subDependencyPath="$(pwd)"

  cd ../dependency
  expect git dependencies add "$subDependencyPath" sub master
  expect git dependencies command sub "\"--no-pager shortlog -sne\""
  git add .
  git commit -m "Add subDependency"

  cd ../project
  expect git dependencies add '../dependency' dep master
  git add .
  git commit -m 'Adding dependency'

  usernameEmail="$(echo "$(git config user.name) <$(git config user.email)>")"

  expect git dependencies update -r > update.log
  expect [[ "\"$(cat update.log | head -3 | tail -1)\"" == *"\"$usernameEmail\"" ]]
}


# TODO
# 1. test submodules
# 2. test selective commands (with dependency path specified)
# 3. test command execution on subpath
# 4. test DependencySet with commit hash

pushd $(dirname $0) > /dev/null
SCRIPTPATH=$(pwd)
popd > /dev/null

export PATH=$SCRIPTPATH:$PATH

run_tests "$1"
