
function DependencyFreezeUnfreezeTest() {
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

function DependencyFreezeUnclonedTest() {
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

function DependencyUpdateFreezedTest() {
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

function DependencyUnfreezeUnclonedTest() {
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
