#!/bin/sh

test_description='basic tests of rev-list --disk-usage'
. ./test-lib.sh

# we want a mix of reachable and unreachable, as well as
# objects in the bitmapped pack and some outside of it
test_expect_success 'set up repository' '
	test_commit --no-tag one &&
	test_commit --no-tag two &&
	git repack -adb &&
	git reset --hard HEAD^ &&
	test_commit --no-tag three &&
	test_commit --no-tag four &&
	git reset --hard HEAD^
'

# We don't want to hardcode sizes, because they depend on the exact details of
# packing, zlib, etc. We'll assume that the regular rev-list and cat-file
# machinery works and compare the --disk-usage output to that.
disk_usage_slow () {
	git rev-list --no-object-names "$@" |
	git cat-file --batch-check="%(objectsize:disk)" |
	perl -lne '$total += $_; END { print $total}'
}

# check behavior with given rev-list options; note that
# whitespace is not preserved in args
check_du () {
	args=$*

	test_expect_success "generate expected size ($args)" "
		disk_usage_slow $args >expect
	"

	test_expect_success "rev-list --disk-usage without bitmaps ($args)" "
		git rev-list --disk-usage $args >actual &&
		test_cmp expect actual
	"

	test_expect_success "rev-list --disk-usage with bitmaps ($args)" "
		git rev-list --disk-usage --use-bitmap-index $args >actual &&
		test_cmp expect actual
	"
}

check_du HEAD
check_du --objects HEAD
check_du --objects HEAD^..HEAD

test_expect_success 'setup garbage repository' '
	git clone --bare . garbage.git &&
	garbage_oid=$(git -C garbage.git hash-object -t garbage -w --stdin --literally <one.t) &&
	git -C garbage.git rev-list --objects --all --disk-usage &&

	# Manually create a ref because "update-ref", "tag" etc. have
	# no corresponding --literally option.
	echo $garbage_oid >garbage.git/refs/tags/garbage-tag &&
	test_must_fail git -C garbage.git rev-list --objects --all --disk-usage
'

test_done
