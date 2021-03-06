/**
 * This file is part of the CernVM File System.
 */

#include <gtest/gtest.h>

#include <map>

#include "logging.h"
#include "platform.h"
#include "util/pointer.h"
#include "util/posix.h"
#include "util_concurrency.h"

typedef std::map<file_watcher::Event, int> Counters;

class TestEventHandler : public file_watcher::EventHandler {
 public:
  explicit TestEventHandler(Counters* ctrs,
                            FifoChannel<bool>* chan)
      : counters_(ctrs)
      , chan_(chan)
      , clear_(true) {}

  virtual ~TestEventHandler() {}

  virtual bool Handle(const std::string& /*file_path*/,
                      file_watcher::Event event,
                      bool* clear_handler) {
    (*counters_)[event]++;
    *clear_handler = clear_;
    chan_->Enqueue(true);
    return true;
  }

  Counters* counters_;
  FifoChannel<bool>* chan_;
  bool clear_;
};

class T_FileWatcher : public ::testing::Test {
 protected:
  void SetUp() {
    counters_.clear();
    channel_ = new FifoChannel<bool>(10, 1);
  }

  Counters counters_;
  UniquePtr<FifoChannel<bool> > channel_;
};

TEST_F(T_FileWatcher, kModifiedEvent) {
  const std::string watched_file_name =
      GetCurrentWorkingDirectory() + "/file_watcher_test.txt";
  SafeWriteToFile("test", watched_file_name, 0600);

  UniquePtr<file_watcher::FileWatcher> watcher(platform_file_watcher());

  // TODO(radu): Remove this check when the Linux inotify version is added
  if (watcher.IsValid()) {
    TestEventHandler* hd(new TestEventHandler(&counters_, channel_.weak_ref()));
    watcher->RegisterHandler(watched_file_name, hd);

    EXPECT_TRUE(watcher->Start());

    SafeWriteToFile("test", watched_file_name, 0600);

    channel_->Dequeue();

    Counters::const_iterator it_mod = counters_.find(file_watcher::kModified);
    const int num_modifications = it_mod->second;
    EXPECT_EQ(1, num_modifications);

    watcher->Stop();
  }
}

TEST_F(T_FileWatcher, kDeletedEvent) {
  const std::string watched_file_name =
      GetCurrentWorkingDirectory() + "/file_watcher_test2.txt";
  SafeWriteToFile("test", watched_file_name, 0600);

  UniquePtr<file_watcher::FileWatcher> watcher(platform_file_watcher());

  // TODO(radu): Remove this check when the Linux inotify version is added
  if (watcher.IsValid()) {
    TestEventHandler* hd(new TestEventHandler(&counters_, channel_.weak_ref()));
    watcher->RegisterHandler(watched_file_name, hd);

    EXPECT_TRUE(watcher->Start());

    unlink(watched_file_name.c_str());

    channel_->Dequeue();

    Counters::const_iterator it_del = counters_.find(file_watcher::kDeleted);
    const int num_deletions = it_del->second;
    EXPECT_EQ(1, num_deletions);

    watcher->Stop();
  }
}

TEST_F(T_FileWatcher, kModifiedThenDeletedEvent) {
  const std::string watched_file_name =
      GetCurrentWorkingDirectory() + "/file_watcher_test.txt";
  SafeWriteToFile("test", watched_file_name, 0600);

  UniquePtr<file_watcher::FileWatcher> watcher(platform_file_watcher());

  // TODO(radu): Remove this check when the Linux inotify version is added
  if (watcher.IsValid()) {
    TestEventHandler* hd(new TestEventHandler(&counters_, channel_.weak_ref()));
    hd->clear_ = false;
    watcher->RegisterHandler(watched_file_name, hd);

    EXPECT_TRUE(watcher->Start());

    SafeWriteToFile("test", watched_file_name, 0600);

    channel_->Dequeue();

    hd->clear_ = true;

    Counters::const_iterator it_mod = counters_.find(file_watcher::kModified);
    const int num_modifications = it_mod->second;
    EXPECT_EQ(1, num_modifications);

    unlink(watched_file_name.c_str());

    channel_->Dequeue();

    Counters::const_iterator it_del = counters_.find(file_watcher::kDeleted);
    const int num_deletions = it_del->second;
    EXPECT_EQ(1, num_deletions);

    watcher->Stop();
  }
}
