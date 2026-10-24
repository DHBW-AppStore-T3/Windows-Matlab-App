/* wmredraw: under Wine the embedded Chromium of MATLAB (the MathWorks
 * sign-in dialog, the desktop) accepts keys and mouse clicks but does not
 * repaint afterwards, so typed text stays invisible until something else
 * forces a redraw. This helper runs next to MATLAB and invalidates the
 * Chromium windows: shortly after every keystroke or click, and once a
 * second for changes that need no input (page loads).
 */
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <wchar.h>

/* with no window SetTimer picks the ids itself; passing one back resets it */
static UINT_PTR t_soon, t_later, t_tick;

static int is_chromium(HWND hwnd)
{
    WCHAR cls[64];
    return hwnd && GetClassNameW(hwnd, cls, 64) && wcsncmp(cls, L"Chrome_Widget", 13) == 0;
}

static BOOL CALLBACK redraw_cb(HWND hwnd, LPARAM lp)
{
    (void)lp;
    if (is_chromium(hwnd) && IsWindowVisible(hwnd))
        RedrawWindow(hwnd, NULL, NULL, RDW_INVALIDATE | RDW_ALLCHILDREN | RDW_UPDATENOW);
    EnumChildWindows(hwnd, redraw_cb, 0);
    return TRUE;
}

static void redraw_all(void)
{
    EnumWindows(redraw_cb, 0);
}

static LRESULT CALLBACK input_proc(int code, WPARAM wp, LPARAM lp)
{
    /* mouse moves are skipped: only presses, releases and the wheel matter */
    if (code == HC_ACTION && wp != WM_MOUSEMOVE)
    {
        t_soon = SetTimer(NULL, t_soon, 60, NULL);
        t_later = SetTimer(NULL, t_later, 400, NULL);
    }
    return CallNextHookEx(NULL, code, wp, lp);
}

int main(void)
{
    MSG msg;
    SetWindowsHookExW(WH_KEYBOARD_LL, input_proc, GetModuleHandleW(NULL), 0);
    SetWindowsHookExW(WH_MOUSE_LL, input_proc, GetModuleHandleW(NULL), 0);
    t_tick = SetTimer(NULL, 0, 1000, NULL);
    while (GetMessageW(&msg, NULL, 0, 0) > 0)
    {
        if (msg.message == WM_TIMER)
        {
            if (msg.wParam == t_soon) { KillTimer(NULL, t_soon); t_soon = 0; }
            else if (msg.wParam == t_later) { KillTimer(NULL, t_later); t_later = 0; }
            redraw_all();
        }
    }
    return 0;
}
