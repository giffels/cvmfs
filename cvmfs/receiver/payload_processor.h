/**
 * This file is part of the CernVM File System.
 */

#ifndef CVMFS_RECEIVER_PAYLOAD_PROCESSOR_H_
#define CVMFS_RECEIVER_PAYLOAD_PROCESSOR_H_

#include <stdint.h>
#include <map>
#include <string>

#include "pack.h"

namespace receiver {

struct FileInfo {
  std::string temp_path;
  size_t total_size;
  size_t current_size;
};

/**
 * This class is used in the `cvmfs_receiver` tool, on repository gateway
 * machines. The receiver::Reactor class, implementing the event loop of the
 * `cvmfs_receiver` tool, dispatches the handling of the kSubmitPayload events
 * to this class.
 *
 * Its responsibility is reading the payload - containing a serialized
 * ObjectPack - from a file descriptor, and unpacking it into the repository.
 */
class PayloadProcessor {
 public:
  enum Result { kSuccess, kPathViolation, kOtherError };

  PayloadProcessor();
  virtual ~PayloadProcessor();

  Result Process(int fdin, const std::string& digest_base64,
                 const std::string& path, uint64_t header_size);

  virtual void ConsumerEventCallback(const ObjectPackBuild::Event& event);

  int GetNumErrors() const { return num_errors_; }

 protected:
  // NOTE: These methods are made virtual such that they can be mocked for
  //       the purpose of unit testing
  virtual bool WriteFile(int fd, const void* const buf, size_t buf_size);
  virtual int RenameFile(const std::string& old_name,
                         const std::string& new_name);

 private:
  typedef std::map<shash::Any, FileInfo>::iterator FileIterator;
  std::map<shash::Any, FileInfo> pending_files_;
  std::string current_repo_;
  int num_errors_;
};

}  // namespace receiver

#endif  // CVMFS_RECEIVER_PAYLOAD_PROCESSOR_H_
