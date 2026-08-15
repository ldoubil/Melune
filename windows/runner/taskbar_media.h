#ifndef RUNNER_TASKBAR_MEDIA_H_
#define RUNNER_TASKBAR_MEDIA_H_

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>

#include <memory>
#include <optional>
#include <string>
#include <vector>

#include <shobjidl.h>
#include <windows.h>

class TaskbarMedia {
 public:
  TaskbarMedia();
  ~TaskbarMedia();

  void Attach(flutter::BinaryMessenger* messenger, HWND hwnd);
  void Detach();
  std::optional<LRESULT> HandleMessage(HWND hwnd, UINT message, WPARAM wparam,
                                       LPARAM lparam);

 private:
  void EnsureTaskbar();
  void AddOrUpdateButtons();
  void SetIconic(bool enabled);
  void SetArtwork(const std::vector<uint8_t>& bytes);
  HBITMAP DecodeImage(const std::vector<uint8_t>& bytes);
  HBITMAP CreatePreviewBitmap(int width, int height);
  bool SendIconicThumbnail(HWND hwnd, int width, int height);
  bool SendIconicLivePreview(HWND hwnd);
  HICON LoadToolbarIcon(int resource_id);
  void ReplyPressed(const std::string& action);

  HWND hwnd_ = nullptr;
  ITaskbarList3* taskbar_ = nullptr;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;

  HICON icon_prev_ = nullptr;
  HICON icon_play_ = nullptr;
  HICON icon_pause_ = nullptr;
  HICON icon_next_ = nullptr;
  HICON icon_like_ = nullptr;
  HICON icon_liked_ = nullptr;
  HBITMAP artwork_ = nullptr;

  bool buttons_added_ = false;
  bool playing_ = false;
  bool liked_ = false;
  bool enabled_ = false;
  bool iconic_ = false;
  UINT taskbar_created_ = 0;
};

#endif  // RUNNER_TASKBAR_MEDIA_H_
