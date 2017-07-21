
function DependencySymlinkDumpTest() {
  cd project
  expect git dependencies add "../dependency" dep master
	expect git dependencies add "../dependency2" dep2 master
	git add .
	git commit -m 'Adding dependency'
	cd ..
	cd dependency
	expect git dependencies add "../dependency2" dep master
	git add .
	git commit -m 'Adding dependency'
	cd ..
	cd project
	expect git dependencies update -r
	cd dep
	local depSHA1=$(git rev-parse HEAD)
	cd ../dep2
	local dep2SHA1=$(git rev-parse HEAD)
	cd ..

	expect git dependencies dump -r | tee dump.txt
	expect [[ $(cat dump.txt | wc -l) -eq 2 ]]
	expect [[ "\"$(cat dump.txt | head -1)\"" == "\"Dependency dep following master (tracking: origin/master) is now at rev $depSHA1\"" ]]
	expect [[ "\"$(cat dump.txt | tail -1)\"" == "\"Dependency dep2 following master (tracking: origin/master) is now at rev $dep2SHA1\"" ]]
}

function DependencyDumpAfterFreezeTest() {
  cd project
  expect git dependencies add '../dependency' dep master
  git add .
  git commit -m 'Adding dependency'
  expect git dependencies freeze
	cd dep
	local depSHA1=$(git rev-parse HEAD)
	cd ..
  expect git dependencies dump | tee dump.txt
	expect [[ $(cat dump.txt | wc -l) -eq 1 ]]
	expect [[ "\"$(cat dump.txt | head -1)\"" == "\"Dependency dep following master (tracking: origin/master) is now at rev $depSHA1\"" ]]
}

function DependencyDumpInDefaultTest() {
  cd project
  expect git dependencies add "../dependency" dep master
	git add .
	git commit -m 'Adding dependency'
	expect git dependencies update -r

	cd dep
	local depSHA1=$(git rev-parse HEAD)
	local depRemoteBranch=$(git for-each-ref --format='%(upstream:short)' $(git symbolic-ref -q HEAD))
	local depPath="dep"
	cd ..

	expect git dependencies dump | tee dump.txt
	expect [[ $(cat dump.txt | wc -l) -eq 1 ]]
	expect [[ "\"$(cat dump.txt | head -1)\"" == "\"Dependency $depPath following master (tracking: $depRemoteBranch) is now at rev $depSHA1\"" ]]
}

function DependencyDumpInHeaderTest() {
	cd project
	expect git dependencies add '../dependency' dep master
	git add .
	git commit -m 'Adding dependency'
	expect git dependencies update -r
	cd dep
	local depBranch=$(git rev-parse --abbrev-ref HEAD)
	local depRemoteBranch=$(git for-each-ref --format='%(upstream:short)' $(git symbolic-ref -q HEAD))
	local depSha1=$(git rev-parse HEAD)
	cd ..
	expect git dependencies dump --dump-header | tee dump.txt
	expect [[ $(cat dump.txt | wc -l) -eq 4 ]]
	expect [[ "\"$(cat dump.txt | head -1)\"" == "\"#define DEP_BRANCH \"$depBranch\"\"" ]]
	expect [[ "\"$(cat dump.txt | head -2 | tail -1 )\"" == "\"#define DEP_REMOTE \"$depRemoteBranch\"\"" ]]
	expect [[ "\"$(cat dump.txt | head -3 | tail -1 )\"" == "\"#define DEP_HASH \"$depSha1\"\"" ]]
	expect [[ "\"$(cat dump.txt | head -4 | tail -1 )\"" == "\"\"" ]]
}

function DepedencyDumpInCustomFormatTest() {
	cd project
	expect git dependencies add '../dependency' vendor/dep master
	git add .
	git commit -m 'Adding dependency'
	expect git dependencies update -r
	cd vendor/dep
	local depName=$(basename $(pwd))
	local depPath="vendor/dep"
	local depBranch=$(git rev-parse --abbrev-ref HEAD)
	local depRemoteBranch=$(git for-each-ref --format='%(upstream:short)' $(git symbolic-ref -q HEAD))
	local depSha1=$(git rev-parse HEAD)
	local sanitizedName="DEP"
	local sanitizedPath="VENDOR_DEP"
	cd ../..
	local customDump="%dependencyName% - %dependency% - %branch% - %remoteBranch% - %sha1% - %sanitizedName% - %sanitizedPath%"
	expect git dependencies dump --dump-custom \"$customDump\" | tee dump.txt
	expect [[ $(cat dump.txt | wc -l) -eq 1 ]]
	expect [[ "\"$(cat dump.txt | head -1)\"" == "\"$depName - $depPath - $depBranch - $depRemoteBranch - $depSha1 - $sanitizedName - $sanitizedPath\"" ]]
}

function DependencySymlinkDumpOverridesTest() {
  # Dump deps with a symlink.
  # Expecting a map of dependencies in JSON. (Each dependency should appear exactly once.)
  cd project
  expect git dependencies add "../dependency" dep master
  expect git dependencies add "../dependency2" dep2 master
  git add .
  git commit -m 'Adding dependency'
  cd ..
  cd dependency
  expect git dependencies add "../dependency2" dep2 master
  expect git dependencies add "../dependency3" dep3 master
  git add .
  git commit -m 'Adding dependency'
  cd ..
  cd dependency2
  touch dummy.txt
  git add .
  git commit -m 'Dummy'
  cd ..
  cd dependency3
  touch dummy.txt
  git add .
  git commit -m 'Dummy'
  cd ..
  cd project
  expect git dependencies update -r
  cd dep
  local depSHA1=$(git rev-parse HEAD)
  cd ../dep2
  local dep2SHA1=$(git rev-parse HEAD)
  cd ../dep3
  local dep3SHA1=$(git rev-parse HEAD)
  cd ..

  # Non-recursive
  expect git dependencies dump --dump-overrides | tee dump.txt
  expect [[ "\"$(cat dump.txt)\"" == "{\"../dependency\":\ \"$depSHA1\",\ \"../dependency2\":\ \"$dep2SHA1\"}" ]]

  # Recursive
  expect git dependencies dump --dump-overrides -r | tee dump.txt
  expect [[ "\"$(cat dump.txt)\"" == "{\"../dependency\":\ \"$depSHA1\",\ \"../dependency3\":\ \"$dep3SHA1\",\ \"../dependency2\":\ \"$dep2SHA1\"}" ]]
}
