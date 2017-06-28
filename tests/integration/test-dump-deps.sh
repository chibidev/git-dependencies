
function DependencySymlinkDumpDepsTest() {
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
  expect git dependencies dump-deps | tee dump.txt
  expect [[ "\"$(cat dump.txt)\"" == "{\"../dependency\":\ \"$depSHA1\",\ \"../dependency2\":\ \"$dep2SHA1\"}" ]]

  # Recursive
  expect git dependencies dump-deps -r | tee dump.txt
  expect [[ "\"$(cat dump.txt)\"" == "{\"../dependency\":\ \"$depSHA1\",\ \"../dependency3\":\ \"$dep3SHA1\",\ \"../dependency2\":\ \"$dep2SHA1\"}" ]]
}

