/* wmwrap: stands in for one of MathWorks' embedded-browser executables
 * (MATLABWindow.exe, MathWorksServiceHostWindow.exe). The real one is
 * renamed to <name>-real.exe by start.sh; this starts it with the same
 * arguments. For the two sign-in browsers it adds a Chromium DevTools port
 * bound to 127.0.0.1 (9222 for the product-activation dialog, 9223 for the
 * ServiceHost sign-in window) because Wine cannot deliver typed characters
 * to those pages (see wm-login). Every other browser is started unchanged.
 */
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <wchar.h>
#include <stdlib.h>

int main(void)
{
    WCHAR self[MAX_PATH], real[MAX_PATH], *slash, *dot;
    const WCHAR *cmd = GetCommandLineW();
    const WCHAR *flag = NULL;
    WCHAR *line;
    size_t len;
    STARTUPINFOW si = { sizeof(si) };
    PROCESS_INFORMATION pi;
    DWORD code = 1;
    int browser_process = wcsstr(cmd, L"--type=") == NULL;

    GetModuleFileNameW(NULL, self, MAX_PATH);
    wcscpy(real, self);
    dot = wcsrchr(real, L'.');
    if (!dot) return 1;
    wcscpy(dot, L"-real.exe");
    slash = wcsrchr(self, L'\\');
    slash = slash ? slash + 1 : self;

    if (browser_process)
    {
        if (!_wcsnicmp(slash, L"MathWorksServiceHostWindow", 26))
            flag = L" --remote-debugging-port=9223 --remote-allow-origins=*";
        else if (wcsstr(cmd, L"MathWorksProductInstaller"))
            flag = L" --remote-debugging-port=9222 --remote-allow-origins=*";
    }

    len = wcslen(real) + wcslen(cmd) + 128;
    line = malloc(len * sizeof(WCHAR));
    if (!line) return 1;
    {
        const WCHAR *args = cmd;   /* the first token is our own path: replace it */
        if (*args == L'"') { args++; while (*args && *args != L'"') args++; if (*args) args++; }
        else while (*args && *args != L' ') args++;
        wcscpy(line, L"\"");
        wcscat(line, real);
        wcscat(line, L"\"");
        wcscat(line, args);
        if (flag) wcscat(line, flag);
    }

    if (!CreateProcessW(real, line, NULL, NULL, TRUE, 0, NULL, NULL, &si, &pi)) return 1;
    WaitForSingleObject(pi.hProcess, INFINITE);
    GetExitCodeProcess(pi.hProcess, &code);
    return (int)code;
}
