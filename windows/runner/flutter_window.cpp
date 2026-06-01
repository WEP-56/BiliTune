#include "flutter_window.h"

#include <algorithm>
#include <cctype>
#include <optional>
#include <string>

#include "flutter/generated_plugin_registrant.h"
#include <flutter/standard_method_codec.h>

namespace {

using flutter::EncodableList;
using flutter::EncodableMap;
using flutter::EncodableValue;

const EncodableValue* FindMapValue(const EncodableMap& map,
                                   const char* key) {
  auto it = map.find(EncodableValue(std::string(key)));
  return it == map.end() ? nullptr : &it->second;
}

std::string StringFromValue(const EncodableValue* value) {
  if (!value) {
    return std::string();
  }
  const auto* text = std::get_if<std::string>(value);
  return text == nullptr ? std::string() : *text;
}

UINT ModifiersFromList(const EncodableList* values) {
  UINT modifiers = MOD_NOREPEAT;
  if (!values) {
    return modifiers;
  }
  for (const auto& value : *values) {
    const auto modifier = StringFromValue(&value);
    if (modifier == "control") {
      modifiers |= MOD_CONTROL;
    } else if (modifier == "alt") {
      modifiers |= MOD_ALT;
    } else if (modifier == "shift") {
      modifiers |= MOD_SHIFT;
    } else if (modifier == "win") {
      modifiers |= MOD_WIN;
    }
  }
  return modifiers;
}

UINT VirtualKeyFromToken(std::string key) {
  if (key.size() == 1) {
    const unsigned char ch = static_cast<unsigned char>(key[0]);
    if (std::isalpha(ch)) {
      return static_cast<UINT>(std::toupper(ch));
    }
    if (std::isdigit(ch)) {
      return static_cast<UINT>(ch);
    }
  }

  if (key.size() >= 2 && key[0] == 'F' &&
      std::all_of(key.begin() + 1, key.end(), [](unsigned char ch) {
        return std::isdigit(ch) != 0;
      })) {
    const int index = std::stoi(key.substr(1));
    if (index >= 1 && index <= 24) {
      return VK_F1 + index - 1;
    }
  }

  if (key == "Space") return VK_SPACE;
  if (key == "Enter") return VK_RETURN;
  if (key == "Escape") return VK_ESCAPE;
  if (key == "Backspace") return VK_BACK;
  if (key == "Tab") return VK_TAB;
  if (key == "ArrowLeft") return VK_LEFT;
  if (key == "ArrowRight") return VK_RIGHT;
  if (key == "ArrowUp") return VK_UP;
  if (key == "ArrowDown") return VK_DOWN;
  if (key == "Home") return VK_HOME;
  if (key == "End") return VK_END;
  if (key == "PageUp") return VK_PRIOR;
  if (key == "PageDown") return VK_NEXT;
  if (key == "Insert") return VK_INSERT;
  if (key == "Delete") return VK_DELETE;
  if (key == "MediaPlayPause") return VK_MEDIA_PLAY_PAUSE;
  if (key == "MediaNextTrack") return VK_MEDIA_NEXT_TRACK;
  if (key == "MediaPreviousTrack") return VK_MEDIA_PREV_TRACK;
  if (key == "MediaStop") return VK_MEDIA_STOP;
  return 0;
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  ConfigureHotkeyChannel();
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  UnregisterHotkeys();
  hotkey_channel_ = nullptr;
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_HOTKEY:
      EmitHotkeyPressed(static_cast<int>(wparam));
      return 0;

    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}

void FlutterWindow::ConfigureHotkeyChannel() {
  hotkey_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "com.wep56.bilitune/hotkeys",
          &flutter::StandardMethodCodec::GetInstance());

  hotkey_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        if (call.method_name() != "setHotkeys") {
          result->NotImplemented();
          return;
        }

        UnregisterHotkeys();

        const auto* arguments = call.arguments();
        const auto* arguments_map = arguments == nullptr
                                        ? nullptr
                                        : std::get_if<EncodableMap>(arguments);
        const auto* bindings_value = arguments_map == nullptr
                                         ? nullptr
                                         : FindMapValue(*arguments_map,
                                                        "bindings");
        const auto* bindings = bindings_value == nullptr
                                   ? nullptr
                                   : std::get_if<EncodableList>(
                                         bindings_value);

        int registered = 0;
        int hotkey_id = 5600;
        if (bindings != nullptr) {
          for (const auto& binding_value : *bindings) {
            const auto* binding = std::get_if<EncodableMap>(&binding_value);
            if (binding == nullptr) {
              continue;
            }

            const auto action = StringFromValue(FindMapValue(*binding,
                                                             "action"));
            const auto key = StringFromValue(FindMapValue(*binding, "key"));
            const auto* modifiers_value = FindMapValue(*binding, "modifiers");
            const auto* modifiers = modifiers_value == nullptr
                                        ? nullptr
                                        : std::get_if<EncodableList>(
                                              modifiers_value);

            if (RegisterHotkeyBinding(action, key, modifiers, hotkey_id)) {
              registered++;
              hotkey_id++;
            }
          }
        }

        result->Success(EncodableValue(EncodableMap{
            {EncodableValue("registered"), EncodableValue(registered)},
        }));
      });
}

bool FlutterWindow::RegisterHotkeyBinding(const std::string& action,
                                          const std::string& key,
                                          const EncodableList* modifiers,
                                          int hotkey_id) {
  if (action.empty() || key.empty()) {
    return false;
  }
  const UINT virtual_key = VirtualKeyFromToken(key);
  if (virtual_key == 0) {
    return false;
  }
  if (!RegisterHotKey(GetHandle(), hotkey_id, ModifiersFromList(modifiers),
                      virtual_key)) {
    return false;
  }
  hotkey_actions_[hotkey_id] = action;
  return true;
}

void FlutterWindow::UnregisterHotkeys() {
  for (const auto& entry : hotkey_actions_) {
    UnregisterHotKey(GetHandle(), entry.first);
  }
  hotkey_actions_.clear();
}

void FlutterWindow::EmitHotkeyPressed(int hotkey_id) {
  if (!hotkey_channel_) {
    return;
  }
  const auto it = hotkey_actions_.find(hotkey_id);
  if (it == hotkey_actions_.end()) {
    return;
  }
  hotkey_channel_->InvokeMethod(
      "onHotkeyPressed",
      std::make_unique<EncodableValue>(EncodableMap{
          {EncodableValue("action"), EncodableValue(it->second)},
      }));
}
