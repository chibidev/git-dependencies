
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
