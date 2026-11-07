#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <string>

#include "flutter_window.h"
#include "utils.h"

namespace {

// ════════════════════════════════════════════════════════════════════
//  🛟 وضع الأمان — رسم برمجي (Software Rendering)
// ════════════════════════════════════════════════════════════════════
//
// **متى يُستخدم؟** إن استمرّ تجميد ويندوز بعد إزالة التلاعب بمضيف الإدخال
// اللمسي، فالشكّ ينتقل إلى **كرت الرسوميات**: Flutter على ويندوز يرسم عبر
// ANGLE ⇒ D3D11، وبعض تعريفات Intel/AMD على أجهزة الكاشير تتعطّل (TDR)
// فتتجمد الشاشة ثوانٍ وتتكرّر حتى يصير النظام غير قابل للاستخدام.
//
// **كيف يُفعَّل؟** ضع ملفًّا فارغًا اسمه `safe_mode.txt` **بجانب**
// `laundry.exe`، ثم أعد تشغيل التطبيق. حذفه يُعيد الوضع الطبيعي.
//
// **الثمن**: رسم على المعالج بدل الكرت — أبطأ في التمرير، لكنه **لا يُجمّد
// الشاشة**. لواجهة نقطة بيع بسيطة هذا مقبول تمامًا، وهو أرخص كثيرًا من
// جهاز معطّل.
//
// المفاتيح مقروءة من متغيّرات البيئة التي يقرأها محرّك Flutter قبل إقلاعه
// (`engine_switches.cc`): `FLUTTER_ENGINE_SWITCHES` = العدد، ثم
// `FLUTTER_ENGINE_SWITCH_1..n`.
void EnableSafeModeIfRequested() {
  wchar_t path[MAX_PATH] = {0};
  const DWORD len = ::GetModuleFileNameW(nullptr, path, MAX_PATH);
  if (len == 0 || len >= MAX_PATH) return;

  std::wstring flag(path);
  const size_t slash = flag.find_last_of(L"\\/");
  if (slash == std::wstring::npos) return;
  flag = flag.substr(0, slash + 1) + L"safe_mode.txt";

  if (::GetFileAttributesW(flag.c_str()) == INVALID_FILE_ATTRIBUTES) return;

  ::SetEnvironmentVariableW(L"FLUTTER_ENGINE_SWITCHES", L"1");
  ::SetEnvironmentVariableW(L"FLUTTER_ENGINE_SWITCH_1",
                            L"enable-software-rendering");
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  // 🛟 يجب أن يسبق إنشاء `DartProject`/المحرّك: المحرّك يقرأ المفاتيح عند
  // الإقلاع فقط، وأي تعيين بعد ذلك لا أثر له.
  EnableSafeModeIfRequested();

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"laundry", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
