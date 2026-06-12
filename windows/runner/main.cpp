#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <iostream>

#include "flutter_window.h"
#include "utils.h"

namespace {

// Single-instance identifiers.
//
// Must stay in sync with the Dart side (SingleInstanceService._key):
// - The mutex name lets us detect an already-running instance BEFORE the
//   Flutter engine boots.
// - The pipe name matches the named pipe created by the windows_single_instance
//   plugin inside the first instance. A second instance writes to it so the
//   first instance wakes its main window, then exits immediately.
//
// Note: this mutex name differs from the plugin's internal mutex name
// ("BakaBox_CS2_Launcher.win.mutex") on purpose, so the first instance's own
// Dart single-instance check does not mistake itself for a second instance.
constexpr const wchar_t kSingleInstanceMutexName[] =
    L"BakaBox_CS2_Launcher_singleton";
constexpr const wchar_t kSingleInstancePipeName[] =
    L"\\\\.\\pipe\\BakaBox_CS2_Launcher";

// Process-wide mutex handle. Held until the process exits (released by the OS).
HANDLE g_single_instance_mutex = nullptr;

// Notify the already-running first instance to wake its main window.
//
// Reuses the named pipe the windows_single_instance plugin creates in the first
// instance: writing an empty JSON array triggers the plugin's onSecondWindow
// callback, which runs SingleInstanceService._wakeExistingInstance on the Dart
// side.
//
// The first instance may still be starting and may not have created the pipe
// yet, so we retry briefly. Even if delivery ultimately fails, the first
// instance will show its own window once started, so usability is unaffected.
void NotifyExistingInstance() {
  const char* payload = "[]";
  const DWORD payload_size = 2;

  for (int attempt = 0; attempt < 20; ++attempt) {
    HANDLE pipe = ::CreateFileW(kSingleInstancePipeName, GENERIC_WRITE, 0,
                                nullptr, OPEN_EXISTING, 0, nullptr);
    if (pipe != INVALID_HANDLE_VALUE) {
      DWORD written = 0;
      ::WriteFile(pipe, payload, payload_size, &written, nullptr);
      ::CloseHandle(pipe);
      return;
    }

    // Pipe not ready yet (first instance still starting): wait and retry.
    if (::GetLastError() == ERROR_PIPE_BUSY) {
      ::WaitNamedPipeW(kSingleInstancePipeName, 200);
    } else {
      ::Sleep(100);
    }
  }
}

// Returns true if this process is the first instance and may continue starting.
// Returns false if another instance is already running and the caller should
// exit immediately.
bool AcquireSingleInstance() {
  g_single_instance_mutex =
      ::CreateMutexW(nullptr, TRUE, kSingleInstanceMutexName);

  // Mutex already exists => another instance is running.
  if (g_single_instance_mutex == nullptr ||
      ::GetLastError() == ERROR_ALREADY_EXISTS) {
    NotifyExistingInstance();
    return false;
  }

  return true;
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Single-instance guard: must run before creating the window and booting the
  // Flutter engine. Otherwise a second process would spin up an entire engine
  // before realizing it is a duplicate, leaving multiple processes in Task
  // Manager.
  if (!AcquireSingleInstance()) {
    return EXIT_SUCCESS;
  }

  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments = GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"BakaBox", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(false);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
