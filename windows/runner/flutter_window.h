#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/encodable_value.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>

#include <map>
#include <memory>
#include <string>

#include "win32_window.h"

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  // Windows global hotkey bridge.
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      hotkey_channel_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      download_channel_;
  std::map<int, std::string> hotkey_actions_;

  void ConfigureHotkeyChannel();
  void ConfigureDownloadChannel();
  void UnregisterHotkeys();
  bool RegisterHotkeyBinding(const std::string& action,
                             const std::string& key,
                             const flutter::EncodableList* modifiers,
                             int hotkey_id);
  void EmitHotkeyPressed(int hotkey_id);
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
