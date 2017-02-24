function DependencyTestSetOSFilter() {
  cd project
  expect git dependencies add "../dependency" dep master
  expect git dependencies set-os-filter dep "win,mac"
  expect [[ -f .gitdepends ]]
  expect "[[ \"$(cat .gitdepends | grep 'os = win,mac')\" != '' ]]"
}

function DependencyTestUpdateWithOSFiltering1() {
  cd project
  expect git dependencies add "../dependency" dep master
  expect git dependencies set-os-filter dep "win"
  git add .
  git commit -m 'Adding dependency'
  expect git dependencies add '../dependency2' dep2 master
  git add .
  git commit -m 'Adding dependency2'
  expect git dependencies update -r --os-filter=win
  expect [[ -d dep ]]
  expect [[ -d dep2 ]]
}

function DependencyTestUpdateWithOSFiltering2() {
  cd project
  expect git dependencies add "../dependency" dep master
  expect git dependencies set-os-filter dep "win"
  git add .
  git commit -m 'Adding dependency'
  expect git dependencies add '../dependency2' dep2 master
  expect git dependencies set-os-filter dep2 "mac"
  git add .
  git commit -m 'Adding dependency2'
  expect git dependencies update -r --os-filter=win
  expect [[ -d dep ]]
  expect [[ ! -d dep2 ]]
}

function DependencyUpdateWithOSFiltering3() {
  cd project
  expect git dependencies add "../dependency" dep master
  expect git dependencies set-os-filter dep "win"
  git add .
  git commit -m 'Adding dependency'
  expect git dependencies add '../dependency2' dep2 master
  expect git dependencies set-os-filter dep2 "mac"
  git add .
  git commit -m 'Adding dependency2'
  expect git dependencies update -r --os-filter=win,mac
  expect [[ -d dep ]]
  expect [[ -d dep2 ]]
}

function DependencyTestUpdateWithOSFiltering4() {
  cd project
  expect git dependencies add "../dependency" dep master
  expect git dependencies set-os-filter dep "win"
  git add .
  git commit -m 'Adding dependency'
  expect git dependencies add '../dependency2' dep2 master
  expect git dependencies set-os-filter dep2 "mac"
  git add .
  git commit -m 'Adding dependency2'
  expect git dependencies add '../dependency3' dep3 master
  git add .
  git commit -m 'Adding dependency3'
  expect git dependencies update -r

  local system_name=$(uname | tr '[:upper:]' '[:lower:]')

  if [[ "$system_name" == "darwin" ]]; then
    expect [[ ! -d dep ]]
    expect [[ -d dep2 ]]
    expect [[ -d dep3 ]]
  elif [[ "$system_name" == "mingw"* ]]; then
    expect [[ -d dep ]]
    expect [[ ! -d dep2 ]]
    expect [[ -d dep3 ]]
  fi
}
