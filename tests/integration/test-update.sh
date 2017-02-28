
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

function DependencyUpdateTestFolderIsExists() {
  cd dependency
  echo "Hello" > sample.txt
  git add .
  git commit -m "Add sample.txt"
  cd ../project
  mkdir dep
  git add .
  git commit -m 'add dep folder'
  expect git dependencies add "../dependency" dep master
  git add .
  git commit -m 'Adding dependency'

  expect git dependencies update -r

  expect [[ -f dep/sample.txt ]]
}

function DependencyRecursiveUpdateTest() {
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


function DependencyPathUpdateTest() {
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
