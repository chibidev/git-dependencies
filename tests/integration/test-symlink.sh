
function DependencySymlinkForeachTest() {
	local branch='test'
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
	expect git dependencies -r foreach "\"checkout -b $branch\""
}

function DependencySymlinkTest() {
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
	expect "[[ -L "dep/dep" ]]"
}

function DependencySymlinkFreezeTest() {
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

	expect "[[ -L "dep/dep" ]]"

	git dependencies freeze -r

  expect "[[ \"$(cat .gitdepends | grep 'freezed')\" == '' ]]"
	expect "[[ -L "dep/dep" ]]"
}

function DependencySymlinkFreezeWithoutUpdateTest() {
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

	git dependencies freeze -r

  expect "[[ \"$(cat .gitdepends | grep 'freezed')\" == '' ]]"
	expect "[[ -L "dep/dep" ]]"
}

function DependencySymlinkUnFreezeTest() {
	cd dependency
	expect git dependencies add "../dependency2" dep master
	git add .
	git commit -m 'Adding dependency'
	expect git dependencies freeze
	cd ..

	cd project
	expect git dependencies add "../dependency" dep master
	expect git dependencies add "../dependency2" dep2 master
	git add .
	git commit -m 'Adding dependency'

	expect git dependencies update -r

	expect "[[ -L "dep/dep" ]]"

	git dependencies unfreeze -r

	cd dep
	expect "[[ \"$(cat .gitdepends | grep 'freezed')\" != '' ]]"
	expect "[[ -L "dep" ]]"
}

function DependencySymlinkSetTest() {
	create_branch dependency2
	cd dependency
	expect git dependencies add "../dependency2" dep master
	git add .
	git commit -m 'Adding dependency'
	cd ..

	cd project
	expect git dependencies add "../dependency" dep master
	expect git dependencies add "../dependency2" dep2 master
	git add .
	git commit -m 'Adding dependency'

	expect git dependencies update -r

	expect "[[ -L "dep/dep" ]]"

	cd dep
	git dependencies set dep almafa
	expect "[[ \"$(cat .gitdepends | grep 'ref = almafa')\" == '' ]]"
}
