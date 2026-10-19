"""Hunters HQ for squadron members: HQ (https://hq.101huntersqn.com) as a Windows program.

A pywebview window on Windows' WebView2 engine: own taskbar button and icon, no address bar or
tabs, remembers the login (%LOCALAPPDATA%\\HuntersHQ\\WebView) and its size and place
(%LOCALAPPDATA%\\HuntersHQ\\window.json). Opened twice, the open window is brought to the front.

Security: the window only ever shows HQ (and the squadron website). Any other address, whether a
clicked link, a redirect or a popup, is cancelled and handed to the default browser (http/https
only). Microphone, camera and notifications are allowed without a prompt for HQ's own origin and
denied for everything else. No dev tools; the right-click menu only offers text editing
(cut / copy / paste / select all) in release builds.

It never opens anything local: it is only a window onto the public HQ site.
"""
import ctypes
import json
import os
import sys
import time
import webbrowser
import winreg
from pathlib import Path
from urllib.parse import urlsplit

VERSION = "1.0.0"
URL = "https://hq.101huntersqn.com/"
HQ_HOST = "hq.101huntersqn.com"
SITE_HOSTS = {HQ_HOST, "101huntersqn.com", "www.101huntersqn.com"}   # may be shown in the window
# Discord OAuth (HQ's "Login with Discord", off for now): the authorize / login pages only.
AUTH_PAGES = {"discord.com": ("/oauth2/", "/login")}
TITLE = "Hunters HQ"
APP_ID = "HuntersSQN.HuntersHQ.Member"                     # taskbar identity; the installer's shortcuts carry it
FROZEN = getattr(sys, "frozen", False)
DEBUG = not FROZEN and "--debug" in sys.argv               # dev tools only when run from source
HERE = Path(sys.executable).parent if FROZEN else Path(__file__).parent
BUNDLE = Path(getattr(sys, "_MEIPASS", HERE))            # PyInstaller's _internal folder when frozen
ICON = next((p for p in (BUNDLE / "hunters-hq.ico", HERE.parent / "hunters-hq.ico") if p.exists()), None)
DATA = Path(os.environ.get("LOCALAPPDATA") or Path.home() / "AppData" / "Local") / "HuntersHQ"
STORAGE = DATA / "WebView"
STATE = DATA / "window.json"
WEBVIEW2_DOWNLOAD = "https://go.microsoft.com/fwlink/p/?LinkId=2124703"   # Microsoft's Evergreen bootstrapper
WEBVIEW2_CLIENT = "{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}"

user32 = ctypes.WinDLL("user32")
kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
user32.FindWindowW.restype = user32.LoadImageW.restype = ctypes.c_void_p
user32.SendMessageW.argtypes = [ctypes.c_void_p, ctypes.c_uint, ctypes.c_size_t, ctypes.c_void_p]
user32.ShowWindow.argtypes = [ctypes.c_void_p, ctypes.c_int]
user32.SetForegroundWindow.argtypes = [ctypes.c_void_p]
user32.MessageBoxW.argtypes = [ctypes.c_void_p, ctypes.c_wchar_p, ctypes.c_wchar_p, ctypes.c_uint]


# ── where the window may go ──────────────────────────────────────────────────
def is_hq(uri: str) -> bool:
    """HQ's own origin exactly: https, hq.101huntersqn.com, default port."""
    try:
        u = urlsplit(uri)
        return u.scheme == "https" and u.hostname == HQ_HOST and u.port in (None, 443)
    except ValueError:
        return False


def may_show(uri: str) -> bool:
    """True if the main window may navigate to this address."""
    if uri.startswith(("data:text/html", "about:blank")):   # our own offline page / the empty start page
        return True
    try:
        u = urlsplit(uri)
        host, port = u.hostname, u.port
    except ValueError:
        return False
    if u.scheme != "https" or port not in (None, 443) or u.username or u.password:
        return False
    if host in SITE_HOSTS:
        return True
    return any(host == h and u.path.startswith(paths) for h, paths in AUTH_PAGES.items())


_recent: dict[str, float] = {}


def open_outside(uri: str) -> None:
    """Hand a web address to the default browser. Never anything but http(s): no file:, no app protocols.
    The same address is not opened twice within a few seconds (a page redirecting in a loop)."""
    try:
        if urlsplit(uri).scheme not in ("http", "https"):
            return
    except ValueError:
        return
    now = time.monotonic()
    if now - _recent.get(uri, -99) < 5:
        return
    if len(_recent) > 50:
        _recent.clear()
    _recent[uri] = now
    webbrowser.open(uri)


# ── WebView2 runtime ─────────────────────────────────────────────────────────
def webview2_version() -> str | None:
    """Installed WebView2 Runtime version (per-machine or per-user), or None."""
    keys = [(winreg.HKEY_LOCAL_MACHINE, rf"SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\{WEBVIEW2_CLIENT}"),
            (winreg.HKEY_LOCAL_MACHINE, rf"SOFTWARE\Microsoft\EdgeUpdate\Clients\{WEBVIEW2_CLIENT}"),
            (winreg.HKEY_CURRENT_USER, rf"SOFTWARE\Microsoft\EdgeUpdate\Clients\{WEBVIEW2_CLIENT}")]
    for root, path in keys:
        try:
            with winreg.OpenKey(root, path) as k:
                pv = str(winreg.QueryValueEx(k, "pv")[0])
                if pv and pv != "0.0.0.0":
                    return pv
        except OSError:
            pass
    return None


def message(text: str, flags: int = 0x40) -> int:        # MB_ICONINFORMATION
    return user32.MessageBoxW(None, text, TITLE, flags | 0x10000)   # MB_SETFOREGROUND


def need_webview2(detail: str = "") -> None:
    text = ("Hunters HQ, Windows'un \"Microsoft Edge WebView2 Runtime\" bileşenine ihtiyaç duyar ve bu "
            "bilgisayarda bulunamadı" + (f" ({detail})" if detail else "") + ".\n\n"
            "Evet'e basınca Microsoft'un resmi WebView2 kurulum dosyası indirilecek. Kurduktan sonra "
            "Hunters HQ'yu yeniden açın.\n\nİndirme sayfası açılsın mı?")
    if message(text, 0x04 | 0x30) == 6:                   # MB_YESNO | MB_ICONWARNING → IDYES
        webbrowser.open(WEBVIEW2_DOWNLOAD)


# ── window helpers ───────────────────────────────────────────────────────────
def bring_to_front() -> None:
    hwnd = user32.FindWindowW(None, TITLE)
    if hwnd:
        user32.ShowWindow(hwnd, 9)                          # SW_RESTORE
        user32.SetForegroundWindow(hwnd)


def load_state() -> dict:
    try:
        s = json.loads(STATE.read_text(encoding="utf-8"))
        # keep the window on a screen that still exists
        vx, vy = user32.GetSystemMetrics(76), user32.GetSystemMetrics(77)   # virtual screen origin
        vw, vh = user32.GetSystemMetrics(78), user32.GetSystemMetrics(79)   # virtual screen size
        if not (vx - 50 <= s.get("x", 0) < vx + vw - 100 and vy - 50 <= s.get("y", 0) < vy + vh - 100):
            s.pop("x", None), s.pop("y", None)
        return s
    except Exception:
        return {}


def save_state(data: dict) -> None:
    try:
        STATE.write_text(json.dumps(data), encoding="utf-8")
    except Exception:
        pass


OFFLINE = """<!doctype html><html lang="tr"><head><meta charset="utf-8"><style>
html,body{height:100%;margin:0;background:#0b1220;color:#cbd5e1;font:15px "Segoe UI",sans-serif}
body{display:flex;flex-direction:column;align-items:center;justify-content:center;gap:14px}
b{font:700 22px "Segoe UI";letter-spacing:.2em;color:#e2e8f0} p{margin:0;max-width:460px;text-align:center}
button{margin-top:6px;padding:9px 22px;border:0;border-radius:8px;background:#38bdf8;color:#0b1220;
font:600 14px "Segoe UI";cursor:pointer} small{color:#64748b}</style></head><body>
<b>HUNTERS HQ</b><p>Hunters HQ'ya bağlanılamadı. İnternet bağlantınızı kontrol edin; HQ kısa bir bakımda da olabilir.</p>
<button onclick="go()">Tekrar dene</button><small id="t"></small>
<script>let n=15;function go(){location.replace("__URL__")}
setInterval(()=>{n--;document.getElementById("t").textContent=n+" sn içinde yeniden denenecek";if(n<=0)go()},1000)</script>
</body></html>""".replace("__URL__", URL)


# ── WebView2 hooks ───────────────────────────────────────────────────────────
def install_hooks() -> None:
    """pywebview 5.4 does not expose WebView2's navigation / permission / context-menu events, so hook
    them in EdgeChrome.on_webview_ready (runs once per window when the engine is ready)."""
    from webview.platforms import edgechromium as ec
    from Microsoft.Web.WebView2.Core import (CoreWebView2ContextMenuItemKind as MenuKind,
                                             CoreWebView2PermissionKind as Kind,
                                             CoreWebView2PermissionState as State,
                                             CoreWebView2WebErrorStatus as Err)
    allowed_kinds = [Kind.Microphone, Kind.Camera, Kind.Notifications]
    offline_errors = [Err.CannotConnect, Err.ConnectionAborted, Err.ConnectionReset, Err.Disconnected,
                      Err.HostNameNotResolved, Err.ServerUnreachable, Err.Timeout]
    keep_menu = {"cut", "copy", "paste", "pasteAndMatchStyle", "selectAll", "undo", "redo", "emoji"}
    original_ready = ec.EdgeChrome.on_webview_ready

    def on_permission(_sender, e) -> None:
        try:
            if is_hq(str(e.Uri)) and any(e.PermissionKind == k for k in allowed_kinds):
                e.State = State.Allow
            elif not is_hq(str(e.Uri)):
                e.State = State.Deny                        # nothing but HQ gets devices, location, …
        except Exception:
            e.State = State.Deny

    def on_navigation(sender, e) -> None:
        uri = str(e.Uri)
        if may_show(uri):
            return
        e.Cancel = True
        if uri.startswith("http://") and urlsplit(uri).hostname in SITE_HOSTS:
            sender.Navigate("https://" + uri[len("http://"):])
        else:
            open_outside(uri)

    def on_new_window(_sender, e) -> None:
        e.Handled = True                                    # no popup windows: links open in the browser
        open_outside(str(e.Uri))

    def on_completed(sender, e) -> None:
        try:
            if not e.IsSuccess and any(e.WebErrorStatus == s for s in offline_errors) and is_hq(str(sender.Source)):
                sender.NavigateToString(OFFLINE)
        except Exception:
            pass

    def on_context_menu(_sender, e) -> None:
        try:
            items = e.MenuItems
            for i in range(items.Count - 1, -1, -1):
                if items[i].Kind == MenuKind.Separator or str(items[i].Name) not in keep_menu:
                    items.RemoveAt(i)
            if items.Count == 0:
                e.Handled = True                            # nothing to edit here: no menu at all
        except Exception:
            e.Handled = True

    def on_ready(self, sender, args) -> None:
        if not args.IsSuccess:
            need_webview2(str(args.InitializationException.Message) if args.InitializationException else "")
            self.form.Close()
            return
        core = sender.CoreWebView2
        core.PermissionRequested += on_permission
        core.NavigationStarting += on_navigation
        core.NavigationCompleted += on_completed
        core.Settings.UserAgent = f"{core.Settings.UserAgent} HuntersHQDesktop/{VERSION}"
        original_ready(self, sender, args)                  # pywebview's own setup, then the first navigation
        if not DEBUG:
            core.Settings.AreDefaultContextMenusEnabled = True   # filtered down to text editing below
            core.ContextMenuRequested += on_context_menu

    ec.EdgeChrome.on_webview_ready = on_ready
    ec.EdgeChrome.on_new_window_request = lambda self, sender, e: on_new_window(sender, e)


def main(after_start=None) -> None:
    """after_start(window) runs once the window is up (tests only)."""
    mutex = kernel32.CreateMutexW(None, False, "Local\\HuntersHQ.MemberApp")  # noqa: F841 (held until exit)
    if ctypes.get_last_error() == 183:                      # ERROR_ALREADY_EXISTS: already open
        bring_to_front()
        return
    if not webview2_version():
        need_webview2()
        return
    DATA.mkdir(parents=True, exist_ok=True)
    ctypes.windll.shell32.SetCurrentProcessExplicitAppUserModelID(APP_ID)

    import webview
    from webview.platforms import winforms
    if winforms.renderer != "edgechromium":                  # never fall back to the old IE engine
        need_webview2(".NET Framework 4.6.2+ veya WebView2 eksik")
        return
    webview.settings["ALLOW_DOWNLOADS"] = True
    webview.settings["OPEN_EXTERNAL_LINKS_IN_BROWSER"] = True
    install_hooks()

    state = load_state()
    window = webview.create_window(
        TITLE, URL, width=state.get("width", 1400), height=state.get("height", 900), x=state.get("x"), y=state.get("y"),
        min_size=(960, 620), maximized=state.get("maximized", False), background_color="#0b1220", text_select=True)

    def on_maximized() -> None:
        state["maximized"] = True

    def on_restored() -> None:
        state["maximized"] = False

    def on_closing() -> None:
        saved = load_state()
        if not state.get("maximized") and window.x is not None and window.x > -10000:   # not minimized
            saved = {"width": window.width, "height": window.height, "x": window.x, "y": window.y}
        saved["maximized"] = bool(state.get("maximized"))
        save_state(saved)

    def set_icon() -> None:
        if not ICON:
            return
        hwnd = window.native.Handle.ToInt64()
        for size, kind in ((16, 0), (32, 1)):               # ICON_SMALL, ICON_BIG
            h = user32.LoadImageW(None, str(ICON), 1, size, size, 0x10)   # IMAGE_ICON, LR_LOADFROMFILE
            if h:
                user32.SendMessageW(hwnd, 0x80, kind, h)    # WM_SETICON

    window.events.maximized += on_maximized
    window.events.restored += on_restored
    window.events.closing += on_closing
    window.events.shown += set_icon

    webview.start(after_start, window, gui="edgechromium", debug=DEBUG, private_mode=False, storage_path=str(STORAGE))


if __name__ == "__main__":
    main()
