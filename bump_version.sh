#!/bin/sh
set -e

NEW_MINOR=$1
NEW_PATCH=$2
[[ -z "$NEW_MINOR" ]] && exit 1
[[ -z "$NEW_PATCH" ]] && exit 1

VERSION=$(grep "^## CVMFS_VERSION" CMakeLists.txt | cut -d" " -f3)
echo "Current version: $VERSION"

VERSION="$(echo $VERSION | cut -d. -f1).${NEW_MINOR}.${NEW_PATCH}"
echo "New version: $VERSION"

echo "Patching CMakeLists.txt"
sed -i -e "s/^## CVMFS_VERSION \(.*\)/## CVMFS_VERSION $VERSION/" CMakeLists.txt
sed -i -e "s/^set (CernVM-FS_VERSION_MINOR \(.*\)/set (CernVM-FS_VERSION_MINOR $NEW_MINOR)/" CMakeLists.txt
sed -i -e "s/^set (CernVM-FS_VERSION_PATCH \(.*\)/set (CernVM-FS_VERSION_PATCH $NEW_PATCH)/" CMakeLists.txt
grep VERSION CMakeLists.txt

echo "Patching RPM"
sed -i -e "s/^Version: \(.*\)/Version: $VERSION/" packaging/rpm/cvmfs-universal.spec
grep Version packaging/rpm/cvmfs-universal.spec

echo "Patching Mac Package"
sed -i -e "s/\(\s*\)<f n=\"cvmfs-[0-9\.]*\(.*\)/\1<f n=\"cvmfs-$VERSION\2/" packaging/mac/cvmfs.pmdoc.template/01cvmfs-contents.xml
sed -i -e "s/\(\s*\)<f n=\"libcvmfs_fuse\.[0-9\.]\+\(.*\)/\1<f n=\"libcvmfs_fuse.$VERSION.\2/" packaging/mac/cvmfs.pmdoc.template/01cvmfs-contents.xml
sed -i -e "s/\(\s*\)<f n=\"libcvmfs_fuse_debug\.[0-9\.]\+\(.*\)/\1<f n=\"libcvmfs_fuse_debug.$VERSION.\2/" packaging/mac/cvmfs.pmdoc.template/01cvmfs-contents.xml
grep $VERSION packaging/mac/cvmfs.pmdoc.template/01cvmfs-contents.xml

