
function DependencyCommandSetterTests() {
  cd project
  expect git dependencies add '../dependency' dep master
  git add .
  git commit -m 'Adding dependency'
  expect git dependencies update -r

  expect git dependencies set-command dep "\"!sh echo \$(pwd)\""
  local result=$(cat .gitdepends | grep 'command')
  expect [[ ${#result} -gt 0 ]]
  expect [[ "\"$result\"" == "\"command = !sh echo \$(pwd)\"" ]]

  expect git dependencies set-command dep "\"!sh echo \$(pwd) > sample.txt && ls\""
  local result2=$(cat .gitdepends | grep 'command')
  expect [[ ${#result2} -gt 0 ]]
  expect [[ "\"$result2\"" == "\"command = !sh echo \$(pwd) > sample.txt && ls\"" ]]

  expect git dependencies set-command dep ""
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

  expect git dependencies set-command dep "\"!sh sh ./dep/sample.sh > hello.txt\""

  expect git dependencies update

  expect [[ -f hello.txt ]]
  expect [[ "\"$(cat hello.txt)\"" == "\"Hello World!\"" ]]

  expect git dependencies set-command dep "\"!sh ln -s dep/README README_LINK\""
  expect git dependencies update
  expect [ -e README_LINK ]
}

function DependencyCommandRunnerTests_MultipleDep_ShellCmd() {

  create_repo subDependency > /dev/null

  cd subDependency
  local subDependencyPath="$(pwd)"

  cd ../dependency
  expect git dependencies add "$subDependencyPath" sub master
  expect git dependencies set-command sub "\"!sh echo \"sub\" > sub.txt\""
  git add .
  git commit -m "Add subDependency"
  local dependencyPath="$(pwd)"

  cd ../project
  local projectPath="$(pwd)"
  expect git dependencies add "$dependencyPath" dep master
  expect git dependencies set-command dep "\"!sh echo \"dep\" > dep.txt\""
  git add .
  git commit -m 'Adding dependency'

  expect git dependencies update -r

  expect [[ -f dep.txt ]]
  expect [[ -f ./dep/sub.txt ]]
}

function DependencyCommandRunnerTests_MultipleDep_ShellCmdExitWithNonZero() {

  create_repo subDependency > /dev/null

  cd subDependency
  local subDependencyPath="$(pwd)"

  echo "#!/bin/bash" > sample.sh
  echo "" >> sample.sh
  echo "echo \"sub\" > sub.txt" >> sample.sh
  echo "function a() { " >> sample.sh
  echo "return 42" >> sample.sh
  echo "} " >> sample.sh
  echo "a" >> sample.sh

  cp sample.sh ~/Desktop/sample.sh

  git add .
  git commit -m "Add sample.sh"

  cd ../dependency
  expect git dependencies add "$subDependencyPath" sub master
  expect git dependencies set-command sub "\"!sh sh $subDependencyPath/sample.sh\""
  git add .
  git commit -m "Add subDependency"
  local dependencyPath="$(pwd)"

  cd ../project
  local projectPath="$(pwd)"
  expect git dependencies add "$dependencyPath" dep master
  expect git dependencies set-command dep "\"!sh echo \"dep\" > dep.txt\""
  git add .
  git commit -m 'Adding dependency'

  expect [[ $(git dependencies update -r >> /dev/null; echo $?) -eq 42 ]]
  expect [[ -f ./dep/sub.txt ]]
  expect [[ ! -f dep.txt ]]
}

function DependencyCommandRunnerTests_ShellCmdExitWithNonZero() {

  cd dependency

  echo "#!/bin/bash" > sample.sh
  echo "" >> sample.sh
  echo "echo \"dep\" > dep.txt" >> sample.sh
  echo "function a() { " >> sample.sh
  echo "return 42" >> sample.sh
  echo "} " >> sample.sh
  echo "a" >> sample.sh

  cp sample.sh ~/Desktop/sample.sh

  git add .
  git commit -m "Add sample.sh"
  local dependencyPath="$(pwd)"

  cd ../project
  local projectPath="$(pwd)"
  expect git dependencies add "$dependencyPath" dep master
  expect git dependencies set-command dep "\"!sh sh $dependencyPath/sample.sh\""
  git add .
  git commit -m 'Adding dependency'

  expect [[ $(git dependencies update -r >> /dev/null; echo $?) -eq 42 ]]
  expect [[ -f dep.txt ]]
}


function DependencyCommandRunnerTests_MultipleDep_GitTask() {

  create_repo subDependency > /dev/null

  cd subDependency
  local subDependencyPath="$(pwd)"

  cd ../dependency
  expect git dependencies add "$subDependencyPath" sub master
  expect git dependencies set-command sub "\"rev-parse --abbrev-ref HEAD\""
  git add .
  git commit -m "Add subDependency"

  cd ../project
  expect git dependencies add '../dependency' dep master
  git add .
  git commit -m 'Adding dependency'

  expect git dependencies update -r > update.log
  expect [[ "\"$(cat update.log | head -4 | tail -1)\"" == *"\"master\"" ]]
}
