#include "flutter_window.h"

#include <optional>
#include <string>
#include <variant>
#include <windows.h>
#include <wincred.h>
#include <flutter/standard_method_codec.h>

#include "flutter/generated_plugin_registrant.h"

namespace {

std::wstring Utf8ToWide(const std::string& value) {
  if (value.empty()) {
    return std::wstring();
  }
  const int length = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS,
                                         value.data(),
                                         static_cast<int>(value.size()),
                                         nullptr, 0);
  if (length <= 0) {
    return std::wstring();
  }
  std::wstring result(length, L'\0');
  MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, value.data(),
                      static_cast<int>(value.size()), result.data(), length);
  return result;
}

const std::string* ReadStringArgument(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    const char* key) {
  const auto* arguments =
      std::get_if<flutter::EncodableMap>(call.arguments());
  if (arguments == nullptr) {
    return nullptr;
  }
  const auto iterator = arguments->find(flutter::EncodableValue(key));
  if (iterator == arguments->end()) {
    return nullptr;
  }
  return std::get_if<std::string>(&iterator->second);
}

std::wstring CredentialTarget(const std::string& key) {
  return L"Kairos:" + Utf8ToWide(key);
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
  window_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "kairos/window",
          &flutter::StandardMethodCodec::GetInstance());
  window_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        if (call.method_name() != "setAlwaysOnTop") {
          result->NotImplemented();
          return;
        }
        const auto* always_on_top = std::get_if<bool>(call.arguments());
        if (always_on_top == nullptr) {
          result->Error("INVALID_ARGUMENT", "Expected a boolean value.");
          return;
        }
        const HWND insert_after = *always_on_top ? HWND_TOPMOST : HWND_NOTOPMOST;
        const BOOL succeeded =
            SetWindowPos(GetHandle(), insert_after, 0, 0, 0, 0,
                         SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
        if (succeeded) {
          result->Success();
        } else {
          result->Error("WINDOW_API_FAILED", "SetWindowPos failed.");
        }
      });
  secure_storage_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "kairos/secure_storage",
          &flutter::StandardMethodCodec::GetInstance());
  secure_storage_channel_->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
             result) {
        const std::string* key = ReadStringArgument(call, "key");
        if (key == nullptr || key->empty()) {
          result->Error("INVALID_ARGUMENT", "A credential key is required.");
          return;
        }
        const std::wstring target = CredentialTarget(*key);
        if (call.method_name() == "write") {
          const std::string* value = ReadStringArgument(call, "value");
          if (value == nullptr || value->empty()) {
            result->Error("INVALID_ARGUMENT",
                          "A credential value is required.");
            return;
          }
          CREDENTIALW credential{};
          credential.Type = CRED_TYPE_GENERIC;
          credential.TargetName = const_cast<LPWSTR>(target.c_str());
          credential.CredentialBlobSize =
              static_cast<DWORD>(value->size());
          credential.CredentialBlob = reinterpret_cast<LPBYTE>(
              const_cast<char*>(value->data()));
          credential.Persist = CRED_PERSIST_LOCAL_MACHINE;
          credential.UserName = const_cast<LPWSTR>(L"Kairos");
          if (CredWriteW(&credential, 0)) {
            result->Success();
          } else {
            result->Error("CREDENTIAL_WRITE_FAILED",
                          "Windows Credential Manager rejected the write.");
          }
          return;
        }
        if (call.method_name() == "read") {
          PCREDENTIALW credential = nullptr;
          if (!CredReadW(target.c_str(), CRED_TYPE_GENERIC, 0, &credential)) {
            if (GetLastError() == ERROR_NOT_FOUND) {
              result->Success();
            } else {
              result->Error("CREDENTIAL_READ_FAILED",
                            "Windows Credential Manager rejected the read.");
            }
            return;
          }
          const std::string value(
              reinterpret_cast<const char*>(credential->CredentialBlob),
              credential->CredentialBlobSize);
          CredFree(credential);
          result->Success(flutter::EncodableValue(value));
          return;
        }
        if (call.method_name() == "delete") {
          if (CredDeleteW(target.c_str(), CRED_TYPE_GENERIC, 0) ||
              GetLastError() == ERROR_NOT_FOUND) {
            result->Success();
          } else {
            result->Error("CREDENTIAL_DELETE_FAILED",
                          "Windows Credential Manager rejected the delete.");
          }
          return;
        }
        result->NotImplemented();
      });
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
  if (flutter_controller_) {
    secure_storage_channel_.reset();
    window_channel_.reset();
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
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
