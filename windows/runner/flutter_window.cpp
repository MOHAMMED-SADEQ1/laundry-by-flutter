#include "flutter_window.h"

#include <windows.h>

#include <atomic>
#include <chrono>
#include <cstdio>
#include <optional>
#include <string>
#include <thread>

#include "flutter/generated_plugin_registrant.h"

namespace {

// ════════════════════════════════════════════════════════════════════
//  ⌨️  لوحة المفاتيح اللمسية — **نلمس TabTip فقط، ولا نلمس مضيف ويندوز ١١**
// ════════════════════════════════════════════════════════════════════
//
// ## العيب الثاني والأخطر (مُثبَت 2026-11-07 — البلاغ الثاني)
//
// كان الكود السابق يُخفي نافذة `Windows.UI.Core.CoreWindow` المسمّاة
// «Microsoft Text Input Application» — أي **نافذة مضيف الإدخال اللمسي في
// ويندوز ١١** (`TextInputHost.exe`)، وهو **عملية نظام مشتركة** لا تخصّنا.
//
// وهذا خطأ فادح لسببين:
//   1. **إطار UWP لا يعلم** أن نافذته أُخفيت بـ`ShowWindow`. فيبقى يظنّها
//      ظاهرة، فلا يُظهرها مرة أخرى أبدًا ⇒ **لوحة المفاتيح لا تعود إلا
//      بإعادة تشغيل ويندوز** — وهو ما بلّغ عنه المستخدم حرفيًا.
//   2. إخفاء مضيف الإدخال أثناء عمله **يُربك خطّ الإدخال اللمسي في النظام
//      كلّه** (`InputHost.dll` محمَّل في كل عملية). فيتوقف اللمس عن العمل في
//      **كل التطبيقات**، ويبدو ويندوز معلّقًا — ويبقى كذلك **بعد إغلاق
//      تطبيقنا**، لأن الضرر وقع على مكوّن نظام لا على عمليتنا.
//
// وهذا يفسّر البلاغ بدقّة: «يعمل دقيقة أو دقيقتين ثم تتعطّل اللمسة، والنظام
// يعلق، ويبقى معلّقًا بعد الإغلاق».
//
// ## القاعدة الآن (لا تُخالَف)
//   1. **لا `FindWindowW` على `Windows.UI.Core.CoreWindow` إطلاقًا** —
//      ولا `ShowWindow` عليه. مضيف الإدخال اللمسي ليس ملكنا.
//   2. نتعامل مع **`IPTip_Main_Window` وحده** (TabTip.exe) — نافذة Win32
//      عادية، إخفاؤها وإظهارها آمنان ولا يُربكان إطار UWP.
//   3. **لا `ShellExecuteW`** — كل نداء قد يُنشئ عملية TabTip جديدة فتتراكم
//      العمليات وتُستنزف الذاكرة. نُظهر النافذة القائمة فقط، وإن لم توجد
//      تركناه لويندوز.
//   4. **لا استدعاء حاجب**: `ShowWindowAsync` لا تنتظر، والإخفاء من
//      `WM_ACTIVATE` مؤجَّل بـ`PostMessage`.

/// رسالة خاصة (مسجَّلة نظاميًّا) تطلب إخفاء اللوحة **بعد** عودة حلقة الرسائل.
UINT GetHideTouchKeyboardMessage() {
  static const UINT message =
      ::RegisterWindowMessageW(L"Laundry.HideTouchKeyboard");
  return message;
}

/// مقبض TabTip وحده — لا شيء آخر.
HWND g_tabtip = nullptr;

/// فاصل منع التكرار لكل اتّجاه على حِدة.
std::atomic<int64_t> g_last_show_ms{0};
std::atomic<int64_t> g_last_hide_ms{0};

constexpr int64_t kDebounceMs = 300;

int64_t NowMs() {
  return std::chrono::duration_cast<std::chrono::milliseconds>(
             std::chrono::steady_clock::now().time_since_epoch())
      .count();
}

bool Debounced(std::atomic<int64_t>& stamp) {
  const int64_t now = NowMs();
  if (now - stamp.load() < kDebounceMs) return true;
  stamp.store(now);
  return false;
}

/// يُحدّث مقبض TabTip عند فقدانه فقط.
void RefreshTabTipHandle() {
  if (g_tabtip == nullptr || !::IsWindow(g_tabtip)) {
    g_tabtip = ::FindWindowW(L"IPTip_Main_Window", nullptr);
  }
}

/// يكتب سطرًا في `%LOCALAPPDATA%\laundry\hang.log`.
void LogHangLine(const char* text) {
  wchar_t buffer[MAX_PATH] = {0};
  const DWORD len =
      ::GetEnvironmentVariableW(L"LOCALAPPDATA", buffer, MAX_PATH);
  if (len == 0 || len >= MAX_PATH) return;

  std::wstring dir(buffer);
  dir += L"\\laundry";
  ::CreateDirectoryW(dir.c_str(), nullptr);

  std::wstring file = dir + L"\\hang.log";
  FILE* fp = nullptr;
  if (::_wfopen_s(&fp, file.c_str(), L"a, ccs=UTF-8") != 0 || fp == nullptr) {
    return;
  }
  std::fprintf(fp, "[%lld] %s\n", static_cast<long long>(NowMs()), text);
  std::fclose(fp);
}

/// إخفاء TabTip — غير حاجب، ولا يمسّ أي عملية أخرى.
void HideTouchKeyboardAsync() {
  if (Debounced(g_last_hide_ms)) return;
  RefreshTabTipHandle();
  if (g_tabtip != nullptr && ::IsWindowVisible(g_tabtip)) {
    ::ShowWindowAsync(g_tabtip, SW_HIDE);
  }
}

/// إظهار TabTip — غير حاجب، وبلا إطلاق عملية جديدة.
void ShowTouchKeyboardAsync() {
  if (Debounced(g_last_show_ms)) return;
  RefreshTabTipHandle();
  if (g_tabtip != nullptr) {
    ::ShowWindowAsync(g_tabtip, SW_SHOWNORMAL);
  }
  // إن لم تكن النافذة موجودة فلا نفعل شيئًا: ويندوز يُظهر لوحته بنفسه عند
  // تركيز حقل إدخال. **ولا نُطلق TabTip.exe صراحةً** — التراكم أخطر من غياب
  // الإظهار.
}

/// مراقب التعليق: يكشف حجب خيط الواجهة ويسجّله في `hang.log`.
void StartHangWatchdog(HWND hwnd) {
  std::thread([hwnd]() {
    bool was_hung = false;
    for (;;) {
      ::Sleep(1000);
      if (!::IsWindow(hwnd)) return;

      DWORD_PTR result = 0;
      const LRESULT ok = ::SendMessageTimeoutW(
          hwnd, WM_NULL, 0, 0, SMTO_ABORTIFHUNG | SMTO_BLOCK, 1000, &result);
      const bool hung = (ok == 0);

      if (hung && !was_hung) {
        LogHangLine("PLATFORM THREAD BLOCKED > 1s (window not responding)");
      } else if (!hung && was_hung) {
        LogHangLine("platform thread recovered");
      }
      was_hung = hung;
    }
  }).detach();
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

  // قناة التحكّم في لوحة المفاتيح اللمسية (إظهار + إخفاء).
  touch_keyboard_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "laundry/touch_keyboard",
          &flutter::StandardMethodCodec::GetInstance());
  touch_keyboard_channel_->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
             result) {
        // ⚠️ كل مسار هنا **غير حاجب**: معالج القناة يعمل على خيط الواجهة.
        if (call.method_name() == "hide") {
          HideTouchKeyboardAsync();
          result->Success();
        } else if (call.method_name() == "show") {
          ShowTouchKeyboardAsync();
          result->Success();
        } else {
          result->NotImplemented();
        }
      });

  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  flutter_controller_->ForceRedraw();

  StartHangWatchdog(GetHandle());

  return true;
}

void FlutterWindow::OnDestroy() {
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

  // الإخفاء المؤجَّل: يُعالَج بعد أن تعود حلقة الرسائل، لا داخل `WM_ACTIVATE`.
  if (message == GetHideTouchKeyboardMessage()) {
    HideTouchKeyboardAsync();
    return 0;
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
    // ⚠️ `PostMessage` لا استدعاء مباشر: هذا داخل معالج الرسائل، وأي عمل
    // حاجب هنا يُجمّد النافذة.
    case WM_ACTIVATE:
      if (LOWORD(wparam) == WA_INACTIVE) {
        ::PostMessageW(hwnd, GetHideTouchKeyboardMessage(), 0, 0);
      }
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
