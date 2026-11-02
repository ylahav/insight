#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter_windows.h>
#include <windows.h>

#include <stdio.h>

#include "flutter_window.h"
#include "utils.h"
#include "../../../windows/placement.h"

namespace {

double MonitorScale() {
  RECT work{};
  ::SystemParametersInfoW(SPI_GETWORKAREA, 0, &work, 0);
  const POINT point{work.left, work.top};
  const HMONITOR monitor =
      ::MonitorFromPoint(point, MONITOR_DEFAULTTONEAREST);
  const UINT dpi = FlutterDesktopGetDpiForMonitor(monitor);
  const double scale = dpi / 96.0;
  return scale < 1 ? 1 : scale;
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

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  int line = EnvInt(L"LINE", 1);
  int lines = EnvInt(L"LINES", 9);
  const Placement place = PlacePhone(MonitorScale(), line, lines);
  wchar_t title[32];
  swprintf_s(title, L"Phone %d", line);
  Win32Window::Point origin(place.x, place.y);
  Win32Window::Size size(place.width, place.height);
  if (!window.Create(title, origin, size)) {
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
