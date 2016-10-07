
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
