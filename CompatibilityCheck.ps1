# CompatibilityCheck.ps1
# This script runs before the module loads to check if terminal resizing is supported
# If the environment doesn't support terminal resizing, it will prevent the module from loading entirely

# Add minimal Windows API imports needed for testing
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public class TerminalCompatibilityCheck
{
    [DllImport("user32.dll", SetLastError = true)]
    public static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);

    [StructLayout(LayoutKind.Sequential)]
    public struct RECT
    {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }
}
"@

function Test-ResizeSupport {
    try {
        # Try to get the foreground window handle
        $terminalHandle = [TerminalCompatibilityCheck]::GetForegroundWindow()
        
        if ($terminalHandle -eq [IntPtr]::Zero) {
            return $false
        }

        # Try to get window dimensions
        $rect = New-Object TerminalCompatibilityCheck+RECT
        return [TerminalCompatibilityCheck]::GetWindowRect($terminalHandle, [ref]$rect)
    }
    catch {
        return $false
    }
}

# Perform compatibility check before module loads
if (-not (Test-ResizeSupport)) {
    throw "Terminal resizing is not supported in this environment. The ResizeTerminal module will not be loaded."
}