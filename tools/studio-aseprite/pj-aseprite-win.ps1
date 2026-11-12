# Aseprite dans Pokémon Studio Extra : petit assistant Windows (fenêtres) piloté par Studio, une commande par ligne
#   find <pid>                     -> found <hwnd>  (fenêtre principale visible du processus)
#   attach <hwnd> <parent>         -> ok            (la fenêtre d'Aseprite devient une partie de Studio)
#   detach <hwnd>                  -> ok            (rend sa fenêtre normale à Aseprite)
#   move <hwnd> <x> <y> <w> <h>    -> ok
#   show <hwnd> <0|1>              -> ok
#   focus <hwnd>                   -> ok
$ErrorActionPreference = 'Stop'
$src = @"
using System;
using System.Runtime.InteropServices;
public static class PjWin {
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc f, IntPtr l);
  [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] static extern IntPtr GetWindow(IntPtr h, uint cmd);
  [DllImport("user32.dll")] static extern IntPtr SetParent(IntPtr c, IntPtr p);
  [DllImport("user32.dll", EntryPoint = "GetWindowLongPtrW")] static extern IntPtr GetLong(IntPtr h, int i);
  [DllImport("user32.dll", EntryPoint = "SetWindowLongPtrW")] static extern IntPtr SetLong(IntPtr h, int i, IntPtr v);
  [DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr h, int x, int y, int w, int hh, bool r);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
  [DllImport("user32.dll")] public static extern IntPtr SetFocus(IntPtr h);
  [DllImport("user32.dll")] static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int w, int hh, uint f);
  const int GWL_STYLE = -16, GWL_EXSTYLE = -20;
  const long WS_CHILD = 0x40000000L, WS_POPUP = 0x80000000L, WS_CAPTION = 0x00C00000L, WS_THICKFRAME = 0x00040000L,
             WS_MINIMIZEBOX = 0x00020000L, WS_MAXIMIZEBOX = 0x00010000L, WS_SYSMENU = 0x00080000L, WS_CLIPSIBLINGS = 0x04000000L,
             WS_EX_APPWINDOW = 0x00040000L;
  static long savedStyle, savedEx;
  public static IntPtr Find(uint pid) {
    IntPtr found = IntPtr.Zero;
    EnumWindows((h, l) => {
      uint p; GetWindowThreadProcessId(h, out p);
      if (p == pid && IsWindowVisible(h) && GetWindow(h, 4) == IntPtr.Zero) { found = h; return false; }
      return true;
    }, IntPtr.Zero);
    return found;
  }
  public static void Attach(IntPtr c, IntPtr parent) {
    savedStyle = (long)GetLong(c, GWL_STYLE); savedEx = (long)GetLong(c, GWL_EXSTYLE);
    long st = savedStyle & ~(WS_POPUP | WS_CAPTION | WS_THICKFRAME | WS_MINIMIZEBOX | WS_MAXIMIZEBOX | WS_SYSMENU);
    SetLong(c, GWL_STYLE, (IntPtr)(st | WS_CHILD | WS_CLIPSIBLINGS));
    SetLong(c, GWL_EXSTYLE, (IntPtr)(savedEx & ~WS_EX_APPWINDOW));
    SetParent(c, parent);
    SetWindowPos(c, IntPtr.Zero, 0, 0, 0, 0, 0x0027); // NOSIZE|NOMOVE|NOZORDER|FRAMECHANGED
  }
  public static void Detach(IntPtr c) {
    SetParent(c, IntPtr.Zero);
    if (savedStyle != 0) { SetLong(c, GWL_STYLE, (IntPtr)savedStyle); SetLong(c, GWL_EXSTYLE, (IntPtr)savedEx); }
    SetWindowPos(c, IntPtr.Zero, 80, 80, 1280, 800, 0x0024); // NOZORDER|FRAMECHANGED
    ShowWindow(c, 5);
  }
}
"@
Add-Type -TypeDefinition $src
[Console]::Out.WriteLine('ready')
while ($true) {
  $line = [Console]::In.ReadLine()
  if ($null -eq $line) { break }
  $a = $line.Trim().Split(' ')
  try {
    switch ($a[0]) {
      'find' { $r = 'found ' + [PjWin]::Find([uint32]$a[1]).ToInt64() }
      'attach' { [PjWin]::Attach([IntPtr][int64]$a[1], [IntPtr][int64]$a[2]); $r = 'ok' }
      'detach' { [PjWin]::Detach([IntPtr][int64]$a[1]); $r = 'ok' }
      'move' { [void][PjWin]::MoveWindow([IntPtr][int64]$a[1], [int]$a[2], [int]$a[3], [int]$a[4], [int]$a[5], $true); $r = 'ok' }
      'show' { [void][PjWin]::ShowWindow([IntPtr][int64]$a[1], $(if ($a[2] -eq '1') { 5 } else { 0 })); $r = 'ok' }
      'focus' { [void][PjWin]::SetFocus([IntPtr][int64]$a[1]); $r = 'ok' }
      'quit' { exit }
      default { $r = 'err commande inconnue' }
    }
  } catch { $r = 'err ' + ($_.Exception.Message -replace '\s+', ' ') }
  [Console]::Out.WriteLine($r)
}
