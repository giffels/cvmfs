#!/bin/sh

# source the common platform independent functionality and option parsing
script_location=$(cd "$(dirname "$0")"; pwd)
. ${script_location}/common_test.sh

retval=0

# format additional disks with ext4 and many inodes
echo -n "formatting new disk partitions... "
disk_to_partition=/dev/vda
partition_2=$(get_last_partition_number $disk_to_partition)
partition_1=$(( $partition_2 - 1 ))
format_partition_ext4 $disk_to_partition$partition_1 || die "fail (formatting partition 1)"
format_partition_ext4 $disk_to_partition$partition_2 || die "fail (formatting partition 2)"
echo "done"

# mount additional disk partitions on strategic cvmfs location
echo -n "mounting new disk partitions into cvmfs specific locations... "
mount_partition $disk_to_partition$partition_1 /srv             || die "fail (mounting /srv $?)"
mount_partition $disk_to_partition$partition_2 /var/spool/cvmfs || die "fail (mounting /var/spool/cvmfs $?)"
echo "done"

# allow apache access to the mounted server file system
echo -n "setting SELinux labels for apache... "
sudo chcon -Rv --type=httpd_sys_content_t /srv > /dev/null || die "fail"
echo "done"

# start apache
echo -n "starting apache... "
sudo service httpd start > /dev/null 2>&1 || die "fail"
echo "OK"

# create the server's client cache directory in /srv (AUFS kernel deadlock workaround)
echo -n "creating client caches on extra partition... "
sudo mkdir -p /srv/cache/server || die "fail (cache for server test cases)"
sudo mkdir -p /srv/cache/client || die "fail (cache for client test cases)"
echo "done"

echo -n "bind mount client cache to /var/lib/cvmfs... "
if [ ! -d /var/lib/cvmfs ]; then
  sudo rm -fR   /var/lib/cvmfs || true
  sudo mkdir -p /var/lib/cvmfs || die "fail (mkdir /var/lib/cvmfs)"
fi
sudo mount --bind /srv/cache/client /var/lib/cvmfs || die "fail (cannot bind mount /var/lib/cvmfs)"
echo "done"

# reset SELinux context
echo -n "restoring SELinux context for /var/lib/cvmfs... "
sudo restorecon -R /var/lib/cvmfs || die "fail"
echo "done"

# running unit test suite
run_unittests --gtest_shuffle \
              --gtest_death_test_use_fork || retval=1


cd ${SOURCE_DIRECTORY}/test
echo "running CernVM-FS client test cases..."
CVMFS_TEST_CLASS_NAME=ClientIntegrationTests                                  \
./run.sh $CLIENT_TEST_LOGFILE -o ${CLIENT_TEST_LOGFILE}${XUNIT_OUTPUT_SUFFIX} \
                                 src/0*                                       \
                              || retval=1


echo "running CernVM-FS server test cases..."
CVMFS_TEST_SERVER_CACHE='/srv/cache'                                          \
CVMFS_TEST_CLASS_NAME=ServerIntegrationTests                                  \
./run.sh $SERVER_TEST_LOGFILE -o ${SERVER_TEST_LOGFILE}${XUNIT_OUTPUT_SUFFIX} \
                              -x src/518-hardlinkstresstest                   \
                                 src/585-xattrs                               \
                                 src/700-overlayfs_validation                 \
                                 --                                           \
                                 src/5*                                       \
                                 src/6*                                       \
                                 src/7*                                       \
                              || retval=1


# echo -n "starting FakeS3 service... "
# s3_retval=0
# fakes3_pid=$(start_fakes3 $FAKE_S3_LOGFILE) || { s3_retval=1; retval=1; echo "fail"; }
# echo "done ($fakes3_pid)"

# if [ $s3_retval -eq 0 ]; then
#   echo "running CernVM-FS server test cases against FakeS3..."
#   CVMFS_TEST_S3_CONFIG=$FAKE_S3_CONFIG                                      \
#   CVMFS_TEST_HTTP_BASE=$FAKE_S3_URL                                         \
#   CVMFS_TEST_SERVER_CACHE='/srv/cache'                                      \
#   CVMFS_TEST_CLASS_NAME=S3ServerIntegrationTests                            \
#   ./run.sh $TEST_S3_LOGFILE -o ${TEST_S3_LOGFILE}${XUNIT_OUTPUT_SUFFIX}     \
#                             -x src/518-hardlinkstresstest                   \
#                                src/519-importlegacyrepo                     \
#                                src/522-missingchunkfailover                 \
#                                src/523-corruptchunkfailover                 \
#                                src/525-bigrepo                              \
#                                src/528-recreatespoolarea                    \
#                                src/530-recreatespoolarea_defaultkey         \
#                                src/537-symlinkedbackend                     \
#                                src/538-symlinkedstratum1backend             \
#                                src/542-storagescrubbing                     \
#                                src/543-storagescrubbing_scriptable          \
#                                src/550-livemigration                        \
#                                src/563-garbagecollectlegacy                 \
#                                src/568-migratecorruptrepo                   \
#                                src/571-localbackendumask                    \
#                                src/572-proxyfailover                        \
#                                src/583-httpredirects                        \
#                                src/585-xattrs                               \
#                                src/591-importrepo                           \
#                                src/594-backendoverwrite                     \
#                                src/595-geoipdbupdate                        \
#                                src/600-securecvmfs                          \
#                                src/605-resurrectancientcatalog              \
#                                src/607-noapache                             \
#                                src/608-infofile                             \
#                                src/610-altpath                              \
#                                src/614-geoservice                           \
#                                src/622-gracefulrmfs                         \
#                                src/626-cacheexpiry                          \
#                                src/700-overlayfsvalidation                  \
#                                --                                           \
#                                src/5*                                       \
#                                src/6*                                       \
#                                src/7*                                       \
#                                || retval=1

#   echo -n "killing FakeS3... "
#   sudo kill -2 $fakes3_pid && echo "done" || echo "fail"
# fi


echo "running CernVM-FS migration test cases..."
CVMFS_TEST_CLASS_NAME=MigrationTests                                              \
./run.sh $MIGRATIONTEST_LOGFILE -o ${MIGRATIONTEST_LOGFILE}${XUNIT_OUTPUT_SUFFIX} \
                                   migration_tests/*                              \
                                || retval=1

exit $retval
