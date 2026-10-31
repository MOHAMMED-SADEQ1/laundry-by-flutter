#include "flutter_window.h"

#include <optional>

#include "flutter/generated_plugin_registrant.h"

namespace {

// إخفاء **لوحة المفاتيح اللمسية** في ويندوز.
//
// ## المشكلة التي يحلّها
// على جهاز يعمل باللمس تُظهر ويندوز لوحة المفاتيح عند التركيز على حقل إدخال،
// ولا تُخفيها عند الانتقال إلى أي مكان آخر: تبقى طافية فوق الواجهة فتحجب
// نصف الشاشة، ويضطر المستخدم لإغلاقها يدويًّا من شريط المهام.
//
// ## لماذا لا يكفي Flutter؟
// لوحة المفاتيح عملية مستقلة (TabTip في ويندوز ١٠، ومضيف `TextInputHost`
// في ويندوز ١١) وليست نافذةً داخل التطبيق، فلا يملك Flutter نافذتها ولا
// يستطيع إغلاقها عبر `TextInput.hide` — ذاك يبلّغ المحرّك فقط.
//
// ## الحلّ
// إغلاق نافذتها من الجهة الأصلية: TabTip تستجيب لـ`SC_CLOSE`، ومضيف ويندوز
// ١١ يتجاهله فيُخفى بـ`SW_HIDE`. كلاهما **لا يقتل العملية**: النظام يعيد
// إظهارها عند الحاجة، فلا يتعطّل الإدخال اللمسي لاحقًا.
void HideTouchKeyboard() {
  HWND tabtip = ::FindWindowW(L"IPTip_Main_Window", nullptr);
  if (tabtip != nullptr && ::IsWindowVisible(tabtip)) {
    ::PostMessageW(tabtip, WM_SYSCOMMAND, SC_CLOSE, 0);
  }

  HWND host = ::FindWindowW(L"Windows.UI.Core.CoreWindow",
                            L"Microsoft Text Input Application");
  if (host != nullptr && ::IsWindowVisible(host)) {
    ::ShowWindow(host, SW_HIDE);
  }
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

  // قناة إخفاء لوحة المفاتيح اللمسية.
  //
  // تُسجَّل **بعد** `RegisterPlugins` كي لا تُستبدل بـ`BinaryMessenger` آخر،
  // وقبل أول إطار كي تكون جاهزة قبل أن يلمس المستخدم أي حقل إدخال.
  touch_keyboard_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "laundry/touch_keyboard",
          &flutter::StandardMethodCodec::GetInstance());
  touch_keyboard_channel_->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
             result) {
        if (call.method_name() == "hide") {
          HideTouchKeyboard();
          result->Success();
        } else {
          result->NotImplemented();
        }
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
  // القناة تشير إلى محرّك النافذة — تُحرَّر قبله.
  touch_keyboard_channel_.reset();
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
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
    // خروج التطبيق من المقدّمة (نقرة على تطبيق آخر) يُنهي صلاحية لوحة
    // المفاتيح: إبقاؤها ظاهرة فوق تطبيق آخر عيب نظام لا عيب واجهتنا.
    case WM_ACTIVATE:
      if (LOWORD(wparam) == WA_INACTIVE) {
        HideTouchKeyboard();
      }
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
