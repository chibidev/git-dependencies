
function OverrideTest() {
  # Test override files without recursive dependencies
  cd project
  expect git dependencies add "../dependency" dep master
  cd ../dependency
  local hash=$(git rev-parse HEAD)
  touch dummy.txt
  git add .
  git commit -m 'Dummy'
  local hash1=$(git rev-parse HEAD)

  # Override file that points to the 'hash' version
  cd ../project
  echo "{\"../dependency\": \"$hash\"}" | tee overrides.json

  # Clone with overrides - dependency should be at override version (hash)
  expect git dependencies update --overrides overrides.json
  cd dep
  expect [[ $(git rev-parse HEAD) == "$hash" ]]

  # Revert to no overrides - dependency should be at HEAD (hash1)
  cd ..
  expect git dependencies update
  cd dep
  expect [[ $(git rev-parse HEAD) == "$hash1" ]]

  # Update with overrides - dependency should be at override version (hash)
  cd ..
  expect git dependencies update --overrides overrides.json
  cd dep
  expect [[ $(git rev-parse HEAD) == "$hash" ]]

}

function RecursiveOverrideTest() {
  # Test override files with recursive dependencies
  cd project
  expect git dependencies add "../dependency" dep master
  git add .
  git commit -m 'Dummy'

  cd ../dependency
  expect git dependencies add "../dependency2" dep2 master
  git add .
  git commit -m 'Dummy'
  local depHash=$(git rev-parse HEAD)
  touch dummy.txt
  git add .
  git commit -m 'Dummy'
  local depHash1=$(git rev-parse HEAD)

  cd ../dependency2
  touch dummy.txt
  git add .
  git commit -m 'Dummy'
  local dep2Hash=$(git rev-parse HEAD)
  echo "foo" >> dummy.txt
  git add .
  git commit -m 'Dummy'
  local dep2Hash1=$(git rev-parse HEAD)

  # Override file that points to the 'hash' versions
  cd ../project
  echo "{\"../dependency\": \"$depHash\", \"../dependency2\": \"$dep2Hash\"}" | tee overrides.json

  # Clone with overrides - dependency should be at override version (hash)
  expect git dependencies update -r --overrides overrides.json
  cd dep
  expect [[ $(git rev-parse HEAD) == "$depHash" ]]
  cd dep2
  expect [[ $(git rev-parse HEAD) == "$dep2Hash" ]]

  # Revert to no overrides - dependency should be at HEAD (hash1)
  cd ../..
  expect git dependencies update -r
  cd dep
  expect [[ $(git rev-parse HEAD) == "$depHash1" ]]
  cd dep2
  expect [[ $(git rev-parse HEAD) == "$dep2Hash1" ]]

  # Update with overrides - dependency should be at override version (hash)
  cd ../..
  expect git dependencies update -r --overrides overrides.json
  cd dep
  expect [[ $(git rev-parse HEAD) == "$depHash" ]]
  cd dep2
  expect [[ $(git rev-parse HEAD) == "$dep2Hash" ]]

}

function PartialOverrideTest() {
  # Test partial override. dep is overridden but dep2 is not.
  cd project
  expect git dependencies add "../dependency" dep master
  expect git dependencies add "../dependency2" dep2 master

  cd ../dependency
  touch dummy.txt
  git add .
  git commit -m 'Dummy'
  local depHash=$(git rev-parse HEAD)
  echo "foo" >> dummy.txt
  git add .
  git commit -m 'Dummy'
  local depHash1=$(git rev-parse HEAD)

  cd ../dependency2
  touch dummy.txt
  git add .
  git commit -m 'Dummy'
  local dep2Hash=$(git rev-parse HEAD)
  echo "foo" >> dummy.txt
  git add .
  git commit -m 'Dummy'
  local dep2Hash1=$(git rev-parse HEAD)

  # Override file that points to the 'hash' version
  cd ../project
  echo "{\"../dependency\": \"$depHash\"}" | tee overrides.json

  # Clone with overrides - dependency should be at override version (hash)
  expect git dependencies update --overrides overrides.json
  cd dep
  expect [[ $(git rev-parse HEAD) == "$depHash" ]]
  cd ../dep2
  expect [[ $(git rev-parse HEAD) == "$dep2Hash1" ]]

  # Revert to no overrides - dependency should be at HEAD (hash1)
  cd ..
  expect git dependencies update
  cd dep
  expect [[ $(git rev-parse HEAD) == "$depHash1" ]]
  cd ../dep2
  expect [[ $(git rev-parse HEAD) == "$dep2Hash1" ]]

  # Update with overrides - dependency should be at override version (hash)
  cd ..
  expect git dependencies update --overrides overrides.json
  cd dep
  expect [[ $(git rev-parse HEAD) == "$depHash" ]]
  cd ../dep2
  expect [[ $(git rev-parse HEAD) == "$dep2Hash1" ]]

}

function RecursivePartialOverrideTest() {
  # Test partial override files with recursive dependencies
  cd project
  expect git dependencies add "../dependency" dep master
  git add .
  git commit -m 'Dummy'

  cd ../dependency
  expect git dependencies add "../dependency2" dep2 master
  git add .
  git commit -m 'Dummy'
  local depHash=$(git rev-parse HEAD)
  touch dummy.txt
  git add .
  git commit -m 'Dummy'
  local depHash1=$(git rev-parse HEAD)

  cd ../dependency2
  touch dummy.txt
  git add .
  git commit -m 'Dummy'
  local dep2Hash=$(git rev-parse HEAD)
  echo "foo" >> dummy.txt
  git add .
  git commit -m 'Dummy'
  local dep2Hash1=$(git rev-parse HEAD)

  # Override file that points to the 'hash' versions
  cd ../project
  echo "{\"../dependency\": \"$depHash\"}" | tee overrides.json

  # Clone with overrides - dependency should be at override version (hash)
  expect git dependencies update -r --overrides overrides.json
  cd dep
  expect [[ $(git rev-parse HEAD) == "$depHash" ]]
  cd dep2
  expect [[ $(git rev-parse HEAD) == "$dep2Hash1" ]]

  # Revert to no overrides - dependency should be at HEAD (hash1)
  cd ../..
  expect git dependencies update -r
  cd dep
  expect [[ $(git rev-parse HEAD) == "$depHash1" ]]
  cd dep2
  expect [[ $(git rev-parse HEAD) == "$dep2Hash1" ]]

  # Update with overrides - dependency should be at override version (hash)
  cd ../..
  expect git dependencies update -r --overrides overrides.json
  cd dep
  expect [[ $(git rev-parse HEAD) == "$depHash" ]]
  cd dep2
  expect [[ $(git rev-parse HEAD) == "$dep2Hash1" ]]

}

function OverrideAllFailTest() {
  # Test override-all failure. dep is overridden but dep2 is not.
  # Partial override should fail.
  cd project
  expect git dependencies add "../dependency" dep master
  expect git dependencies add "../dependency2" dep2 master

  cd ../dependency
  touch dummy.txt
  git add .
  git commit -m 'Dummy'
  local depHash=$(git rev-parse HEAD)
  echo "foo" >> dummy.txt
  git add .
  git commit -m 'Dummy'
  local depHash1=$(git rev-parse HEAD)

  cd ../dependency2
  touch dummy.txt
  git add .
  git commit -m 'Dummy'
  local dep2Hash=$(git rev-parse HEAD)
  echo "foo" >> dummy.txt
  git add .
  git commit -m 'Dummy'
  local dep2Hash1=$(git rev-parse HEAD)

  # Override file that points to the 'hash' version
  cd ../project
  echo "{\"../dependency\": \"$depHash\"}" | tee overrides.json

  # Clone with overrides - incomplete overrides should fail
  expect ! git dependencies update --overrides overrides.json --override-all

  # Revert to no overrides - dependency should be at HEAD (hash1)
  expect git dependencies update
  cd dep
  expect [[ $(git rev-parse HEAD) == "$depHash1" ]]
  cd ../dep2
  expect [[ $(git rev-parse HEAD) == "$dep2Hash1" ]]

  # Update with overrides - incomplete overrides should fail
  cd ..
  expect ! git dependencies update --overrides overrides.json --override-all

}

function RecursiveOverrideAllFailTest() {
  # Test override-all failure. dep is overridden but dep2 is not.
  # Partial override should fail.
  cd project
  expect git dependencies add "../dependency" dep master
  git add .
  git commit -m 'Dummy'

  cd ../dependency
  expect git dependencies add "../dependency2" dep2 master
  git add .
  git commit -m 'Dummy'
  local depHash=$(git rev-parse HEAD)
  touch dummy.txt
  git add .
  git commit -m 'Dummy'
  local depHash1=$(git rev-parse HEAD)

  cd ../dependency2
  touch dummy.txt
  git add .
  git commit -m 'Dummy'
  local dep2Hash=$(git rev-parse HEAD)
  echo "foo" >> dummy.txt
  git add .
  git commit -m 'Dummy'
  local dep2Hash1=$(git rev-parse HEAD)

  # Override file that points to the 'hash' versions
  cd ../project
  echo "{\"../dependency\": \"$depHash\"}" | tee overrides.json

  # Clone with overrides - incomplete overrides should fail
  expect ! git dependencies update -r --overrides overrides.json --override-all

  # Revert to no overrides - dependency should be at HEAD (hash1)
  expect git dependencies update -r
  cd dep
  expect [[ $(git rev-parse HEAD) == "$depHash1" ]]
  cd dep2
  expect [[ $(git rev-parse HEAD) == "$dep2Hash1" ]]

  # Update with overrides - incomplete overrides should fail
  cd ../..
  expect ! git dependencies update -r --overrides overrides.json --override-all

}
