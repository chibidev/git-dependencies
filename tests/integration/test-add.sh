
function DependencyAddTest() {
  cd project
  expect git dependencies add "../dependency" dep master
  expect [[ -f .gitdepends ]]
  expect "[[ \"$(cat .gitdepends | grep 'ref = master')\" != '' ]]"
}
