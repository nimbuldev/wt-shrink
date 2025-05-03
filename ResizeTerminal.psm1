# Add Windows API functions for terminal resizing
Add-Type -TypeDefinition @"
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;
using System.Linq;
using System.Collections.Generic;
using System.Threading;

public class TerminalResizer
{
    #region Windows API Imports
    [DllImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);

    [DllImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool MoveWindow(IntPtr hWnd, int X, int Y, int nWidth, int nHeight, bool bRepaint);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);
    
    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);
    
    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    public static extern int GetClassName(IntPtr hWnd, StringBuilder lpClassName, int nMaxCount);
    
    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool IsWindowVisible(IntPtr hWnd);
    
    [DllImport("kernel32.dll")]
    public static extern uint GetCurrentProcessId();

    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();
    #endregion

    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    [StructLayout(LayoutKind.Sequential)]
    public struct RECT
    {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }

    private static IntPtr FoundWindowHandle = IntPtr.Zero;
    private static uint CurrentProcessId;
    
    private static readonly List<string> TerminalClassNames = new List<string> { 
        "CASCADIA_HOSTING_WINDOW_CLASS", "ConsoleWindowClass", "VirtualConsoleClass", 
        "mintty", "Cygwin-Terminal" 
    };
    
    private static readonly List<string> TerminalProcessNames = new List<string> {
        "WindowsTerminal", "powershell", "pwsh", "cmd", "wt", "mintty", "bash"
    };
    
    private static readonly List<string> TerminalTitleKeywords = new List<string> {
        "Windows Terminal", "PowerShell", "Command Prompt", "cmd", "bash", "Terminal", "Console"
    };

    private delegate double EasingFunction(double x);
    private static readonly Dictionary<string, EasingFunction> EasingFunctions = new Dictionary<string, EasingFunction>
    {
        {"Linear", x => x},
        {"EaseIn", x => Math.Pow(x, 4)},
        {"EaseOut", x => 1.0 - Math.Pow(1.0 - x, 4)},
        {"EaseInOut", x => x < 0.5 ? 8 * Math.Pow(x, 4) : 1 - Math.Pow(-2 * x + 2, 4) / 2}
    };
    
    public static double ApplyEasing(string easingType, double progress) {
        if (EasingFunctions.TryGetValue(easingType, out var function))
            return function(progress);
        return progress;
    }
    
    public static bool AnimateWindowResize(
        IntPtr hWnd,
        int startX,
        int startY,
        int startWidth,
        int startHeight,
        int endWidth,
        int endHeight,
        int durationMs,
        int frameRate,
        string easingType)
    {
        if (durationMs <= 0 || frameRate <= 0) {
            // Skip animation if duration or frame rate is invalid
            return MoveWindow(hWnd, startX, startY, endWidth, endHeight, true);
        }
        
        try {
            int totalFrames = Math.Max((durationMs * frameRate) / 1000, 2);
            int frameTimeMs = durationMs / totalFrames;
            bool success = true;
            
            for (int frame = 0; frame <= totalFrames; frame++) {
                double progress = (double)frame / totalFrames;
                double easedProgress = ApplyEasing(easingType, progress);
                
                int currentWidth = startWidth + (int)Math.Round((endWidth - startWidth) * easedProgress);
                int currentHeight = startHeight + (int)Math.Round((endHeight - startHeight) * easedProgress);
                
                success &= MoveWindow(hWnd, startX, startY, currentWidth, currentHeight, true);
                
                if (frame < totalFrames) {
                    Thread.Sleep(frameTimeMs);
                }
            }
            
            return MoveWindow(hWnd, startX, startY, endWidth, endHeight, true) && success;
        }
        catch {
            // If animation fails, attempt direct resize
            return MoveWindow(hWnd, startX, startY, endWidth, endHeight, true);
        }
    }

    public static IntPtr FindTerminalWindow()
    {
        IntPtr? result = GetForegroundTerminalWindow()
            ?? GetCurrentProcessTerminalWindow()
            ?? GetTerminalWindowByClass()
            ?? GetTerminalWindowByTitle();
            
        return result ?? IntPtr.Zero;
    }
    
    private static IntPtr? GetForegroundTerminalWindow() {
        IntPtr foregroundWindow = GetForegroundWindow();
        return (foregroundWindow != IntPtr.Zero && IsLikelyTerminalWindow(foregroundWindow)) 
            ? foregroundWindow 
            : (IntPtr?)null;
    }
    
    private static IntPtr? GetCurrentProcessTerminalWindow() {
        CurrentProcessId = GetCurrentProcessId();
        FoundWindowHandle = IntPtr.Zero;
        EnumWindows(EnumWindowsByProcessId, IntPtr.Zero);
        return (FoundWindowHandle != IntPtr.Zero) ? FoundWindowHandle : (IntPtr?)null;
    }
    
    private static IntPtr? GetTerminalWindowByClass() {
        foreach (string className in TerminalClassNames) {
            FoundWindowHandle = IntPtr.Zero;
            EnumWindows((hWnd, lParam) => {
                if (!IsWindowVisible(hWnd)) return true;
                
                StringBuilder classNameBuilder = new StringBuilder(256);
                GetClassName(hWnd, classNameBuilder, classNameBuilder.Capacity);
                
                if (classNameBuilder.ToString().Contains(className)) {
                    FoundWindowHandle = hWnd;
                    return false;
                }
                return true;
            }, IntPtr.Zero);
            
            if (FoundWindowHandle != IntPtr.Zero)
                return FoundWindowHandle;
        }
        return null;
    }
    
    private static IntPtr? GetTerminalWindowByTitle() {
        FoundWindowHandle = IntPtr.Zero;
        EnumWindows(EnumWindowsByTitle, IntPtr.Zero);
        return (FoundWindowHandle != IntPtr.Zero) ? FoundWindowHandle : (IntPtr?)null;
    }
    
    private static bool IsLikelyTerminalWindow(IntPtr hWnd) 
    {
        if (!IsWindowVisible(hWnd)) {
            return false;
        }
        
        StringBuilder className = new StringBuilder(256);
        GetClassName(hWnd, className, className.Capacity);
        string windowClass = className.ToString();
        
        if (TerminalClassNames.Any(c => windowClass.Contains(c))) {
            return true;
        }
        
        StringBuilder title = new StringBuilder(256);
        GetWindowText(hWnd, title, title.Capacity);
        string windowTitle = title.ToString();
        
        if (TerminalTitleKeywords.Any(t => windowTitle.Contains(t))) {
            return true;
        }
        
        uint processId = 0;
        GetWindowThreadProcessId(hWnd, out processId);
        try {
            Process process = Process.GetProcessById((int)processId);
            string processName = process.ProcessName.ToLower();
            if (TerminalProcessNames.Any(p => processName.Contains(p.ToLower()))) {
                return true;
            }
        }
        catch {
            // Process might have exited
        }
        
        return false;
    }
    
    private static bool EnumWindowsByProcessId(IntPtr hWnd, IntPtr lParam)
    {
        if (!IsWindowVisible(hWnd)) {
            return true;
        }
        
        uint processId = 0;
        GetWindowThreadProcessId(hWnd, out processId);
        
        if (processId == CurrentProcessId) {
            FoundWindowHandle = hWnd;
            return false;
        }
        return true;
    }
    
    private static bool EnumWindowsByTitle(IntPtr hWnd, IntPtr lParam)
    {
        if (!IsWindowVisible(hWnd)) {
            return true;
        }
        
        StringBuilder title = new StringBuilder(256);
        GetWindowText(hWnd, title, title.Capacity);
        string windowTitle = title.ToString();
        
        if (!string.IsNullOrEmpty(windowTitle) && 
            TerminalTitleKeywords.Any(k => windowTitle.Contains(k))) {
            FoundWindowHandle = hWnd;
            return false;
        }
        return true;
    }
}
"@

$script:SHIM_PREFIX = "Resized_"
$script:RESIZE_TERMINAL_MODULE = $PSScriptRoot

$script:CommonParameters = @{
    RibbonHeight       = 100
    EnableAnimation    = $true
    AnimationDuration  = 250
    AnimationFrameRate = 60
    AnimationType      = "EaseOut"
    Trigger            = @()
}

$script:SessionShims = @{} 

$MyInvocation.MyCommand.ScriptBlock.Module.OnRemove = {
    foreach ($command in @($script:SessionShims.Keys)) {
        Remove-ResizeShim -CommandNames $command -Internal
    }
}

function Get-TerminalWindow {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()
    
    try {
        $terminalHandle = [TerminalResizer]::FindTerminalWindow()
        
        if ($terminalHandle -eq [IntPtr]::Zero) {
            return $null
        }

        $rect = New-Object TerminalResizer+RECT
        if (-not [TerminalResizer]::GetWindowRect($terminalHandle, [ref]$rect)) {
            return $null
        }
        
        $width = $rect.Right - $rect.Left
        $height = $rect.Bottom - $rect.Top
                
        return @{
            Handle = $terminalHandle
            Left   = $rect.Left
            Top    = $rect.Top
            Width  = $width
            Height = $height
        }
    }
    catch {
        return $null
    }
}

function Set-WindowSize {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [IntPtr]$Handle,
        
        [Parameter(Mandatory = $true)]
        [int]$X,
        
        [Parameter(Mandatory = $true)]
        [int]$Y,
        
        [Parameter(Mandatory = $true)]
        [int]$Width,
        
        [Parameter(Mandatory = $true)]
        [int]$Height,
        
        [Parameter()]
        [bool]$UseAnimation = $true,
        
        [Parameter()]
        [int]$Duration = 0,
        
        [Parameter()]
        [int]$FrameRate = 60,
        
        [Parameter()]
        [string]$EasingType = "EaseOut"
    )
    
    try {
        $rect = New-Object TerminalResizer+RECT
        [TerminalResizer]::GetWindowRect($Handle, [ref]$rect)
        $currentWidth = $rect.Right - $rect.Left
        $currentHeight = $rect.Bottom - $rect.Top
        
        $success = $false
        
        if ($UseAnimation -and $Duration -gt 0) {
            $success = [TerminalResizer]::AnimateWindowResize(
                $Handle, $X, $Y, 
                $currentWidth, $currentHeight, 
                $Width, $Height, 
                $Duration, $FrameRate, 
                $EasingType
            )
        }
        else {
            # Direct resize without animation
            $success = [TerminalResizer]::MoveWindow($Handle, $X, $Y, $Width, $Height, $true)
        }
        
        return $success
    }
    catch {
        Write-Host "Error resizing window"
        return $false
    }
}

function Resize-Terminal {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Command,
        
        [Parameter()]
        [ValidateRange(50, 2000)]
        [int]$RibbonHeight = $script:CommonParameters.RibbonHeight,
        
        [Parameter()]
        [bool]$EnableAnimation = $script:CommonParameters.EnableAnimation,
        
        [Parameter()]
        [ValidateRange(0, 2000)]
        [int]$AnimationDuration = $script:CommonParameters.AnimationDuration,
        
        [Parameter()]
        [ValidateRange(10, 120)]
        [int]$AnimationFrameRate = $script:CommonParameters.AnimationFrameRate,
        
        [Parameter()]
        [ValidateSet("Linear", "EaseIn", "EaseOut", "EaseInOut")]
        [string]$AnimationType = $script:CommonParameters.AnimationType
    )

    $terminalWindow = $null
    
    # Create a more comprehensive trap that will catch any type of terminating exception
    # This ensures terminal restoration works regardless of when Ctrl+C is pressed
    trap {
        if ($null -ne $terminalWindow) {
            $restoreSuccess = Set-WindowSize -Handle $terminalWindow.Handle `
                -X $terminalWindow.Left `
                -Y $terminalWindow.Top `
                -Width $terminalWindow.Width `
                -Height $terminalWindow.Height `
                -UseAnimation $EnableAnimation
            
            if (-not $restoreSuccess) {
                Write-Host "Failed to restore terminal size after interruption"
            }
        }
        # Re-throw the exception to continue normal exception handling
        throw $_
    }

    try {        
        $terminalWindow = Get-TerminalWindow
        
        if ($null -eq $terminalWindow) {
            throw "Failed to get terminal window information"
        }
        
        $resizeSuccess = Set-WindowSize -Handle $terminalWindow.Handle `
            -X $terminalWindow.Left `
            -Y $terminalWindow.Top `
            -Width $terminalWindow.Width `
            -Height $RibbonHeight `
            -UseAnimation $EnableAnimation `
            -Duration $AnimationDuration `
            -FrameRate $AnimationFrameRate `
            -EasingType $AnimationType
        
        if (-not $resizeSuccess) {
            Write-Host "Terminal resize failed"
        }
                
        $cleanCommand = $Command.Trim('"''')        
        try {            
            # Extract the executable path
            $parts = $cleanCommand -split ' ', 2
            $executable = $parts[0]
            $argumentString = if ($parts.Count -gt 1) { $parts[1] } else { "" }
            
            # Parse the arguments
            $argList = @()
            if (-not [string]::IsNullOrWhiteSpace($argumentString)) {
                $inQuote = $false
                $currentArg = ""
                $quoteChar = ""
                                
                for ($i = 0; $i -lt $argumentString.Length; $i++) {
                    $char = $argumentString[$i]
                    
                    # Handle quotes
                    if ($char -eq '"' -or $char -eq "'") {
                        if (-not $inQuote) {
                            $inQuote = $true
                            $quoteChar = $char
                        } 
                        elseif ($char -eq $quoteChar) {
                            $inQuote = $false
                        }
                        else {
                            $currentArg += $char
                        }
                    }
                    # Handle spaces outside quotes
                    elseif ($char -eq ' ' -and -not $inQuote) {
                        if ($currentArg -ne "") {
                            $argList += $currentArg
                            $currentArg = ""
                        }
                    }
                    else {
                        $currentArg += $char
                    }
                }
                
                # Add the last argument if there is one
                if ($currentArg -ne "") {
                    $argList += $currentArg
                }
            }
            
            try {
                # Execute the command with properly separated arguments
                $oldPreference = $ErrorActionPreference
                $ErrorActionPreference = 'Stop'
                
                if ($argList.Count -eq 0) {
                    & $executable
                }
                else {
                    & $executable $argList
                }
                
                $ErrorActionPreference = $oldPreference
            }
            catch {
                # Fallback to Invoke-Expression as last resort
                Invoke-Expression -Command $cleanCommand
            }
        }
        catch {
            Write-Host "Command execution failed with error: $_"
        }
    }
    catch {
        Write-Host "Error occurred: $_"
    }
    finally {
        # Always restore the terminal, even if an error occurs
        if ($null -ne $terminalWindow) {
            $restoreSuccess = Set-WindowSize -Handle $terminalWindow.Handle `
                -X $terminalWindow.Left `
                -Y $terminalWindow.Top `
                -Width $terminalWindow.Width `
                -Height $terminalWindow.Height `
                -UseAnimation $EnableAnimation `
                -Duration $AnimationDuration `
                -FrameRate $AnimationFrameRate `
                -EasingType $AnimationType
        }
    }
}

function Find-PowerShellExecutable {
    $psExecutables = @("pwsh", "powershell")
    
    foreach ($exe in $psExecutables) {
        try {
            if (Get-Command $exe -ErrorAction SilentlyContinue) {
                return $exe
            }
        }
        catch {
            # Executable not found, continue to next one
        }
    }
    
    # If no executable was found in PATH, try with full paths for common locations
    $commonPaths = @(
        "$env:LOCALAPPDATA\Microsoft\WindowsApps\pwsh.exe",
        "$env:ProgramFiles\PowerShell\7\pwsh.exe",
        "${env:ProgramFiles(x86)}\PowerShell\7\pwsh.exe",
        "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
    )
    
    foreach ($path in $commonPaths) {
        if (Test-Path $path) {
            return $path
        }
    }
    
    Write-Host "No PowerShell executable found. Some features may be unavailable."
    return $null
}

function New-ShimFunction {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Command,

        [Parameter(Mandatory = $true)]
        [string]$Target,

        [Parameter()]
        [string]$Arguments = $null,

        [Parameter()]
        [string]$CommandPath = $null,

        [Parameter()]
        [int]$RibbonHeight = $script:CommonParameters.RibbonHeight,
        
        [Parameter()]
        [bool]$EnableAnimation = $script:CommonParameters.EnableAnimation,
        
        [Parameter()]
        [int]$AnimationDuration = $script:CommonParameters.AnimationDuration,
        
        [Parameter()]
        [int]$AnimationFrameRate = $script:CommonParameters.AnimationFrameRate,
        
        [Parameter()]
        [string]$AnimationType = $script:CommonParameters.AnimationType,
        
        [Parameter()]
        [string[]]$Trigger = $script:CommonParameters.Trigger
    )
    
    $shimName = $script:SHIM_PREFIX + $Command
    
    # Build the command string to be executed
    $commandString = $Target
    if (-not [string]::IsNullOrWhiteSpace($Arguments)) {
        $commandString += " " + $Arguments
    }

    # Build the function code that will execute the command with terminal resizing
    $functionCode = @"
function global:$shimName {
    param (
        [Parameter(ValueFromRemainingArguments = `$true)]
        [string[]]`$Arguments
    )

    try {
        # Access this shim's metadata from the session store
        `$shimMetadata = `$script:SessionShims['$Command']
        
        if (`$null -eq `$shimMetadata) {
            throw "Shim metadata not found for '$Command'. The shim may need to be recreated."
        }

        `$commandToExecute = '$($commandString.Replace("'", "''"))'
        
        if (`$Arguments.Count -gt 0) {
            `$additionalArgs = `$Arguments -join ' '
            `$commandToExecute += " " + `$additionalArgs
        }
        
        `$triggerWords = if (`$shimMetadata.ContainsKey('Trigger') -and `$shimMetadata.Trigger) {
            [string[]]`$shimMetadata.Trigger
        } else {
            @()
        }
        
        # Determine if we should resize based on triggers
        `$shouldResize = `$true
        
        if (`$triggerWords.Count -gt 0) {
            `$shouldResize = `$false
            `$argString = `$Arguments -join " "
            
            foreach (`$trigger in `$triggerWords) {
                if (`$argString -like "*`$trigger*") {
                    `$shouldResize = `$true
                    break
                }
            }
        }
        
        # Define the local function to execute the command directly
        function ExecuteCommand {
            try {
                Invoke-Expression -Command `$commandToExecute
            }
            catch {
                Write-Host "Error executing command: `$_"
            }
        }
                    
        if (`$shouldResize) {
            # Use shim-specific parameters from metadata, falling back to defaults if missing
            `$ribbonHeight = if (`$shimMetadata.ContainsKey('RibbonHeight')) { `$shimMetadata.RibbonHeight } else { $RibbonHeight }
            `$enableAnimation = if (`$shimMetadata.ContainsKey('EnableAnimation')) { `$shimMetadata.EnableAnimation } else { $EnableAnimation }
            `$animationDuration = if (`$shimMetadata.ContainsKey('AnimationDuration')) { `$shimMetadata.AnimationDuration } else { $AnimationDuration }
            `$animationFrameRate = if (`$shimMetadata.ContainsKey('AnimationFrameRate')) { `$shimMetadata.AnimationFrameRate } else { $AnimationFrameRate }
            `$animationType = if (`$shimMetadata.ContainsKey('AnimationType')) { `$shimMetadata.AnimationType } else { "$AnimationType" }
            
            Resize-Terminal -Command `$commandToExecute -RibbonHeight `$ribbonHeight -EnableAnimation:`$enableAnimation -AnimationDuration `$animationDuration -AnimationFrameRate `$animationFrameRate -AnimationType `$animationType
        } else {
            # Execute directly without resizing
            ExecuteCommand
        }
    }
    catch {
        `$errorMsg = "Error in resize shim for '$Command': `$_"
        Write-Host `$errorMsg
        
        # Don't re-execute the command if it already ran but failed
        # Only execute if the initial execution didn't happen at all
        if (`$_.Exception.Message -like "*metadata not found*" -or `$_.Exception.Message -like "*Failed to get terminal*") {
            try {
                Invoke-Expression -Command `$commandToExecute
            }
            catch {
                Write-Host "Error executing command: `$_"
            }
        }
    }
}
Set-Alias -Name "$Command" -Value "$shimName" -Scope Global -Force -ErrorAction Stop
"@

    return $functionCode
}

function Get-ResizeShim {
    [OutputType([PSCustomObject])]
    param (
        [Parameter(Position = 0)]
        [string]$CommandName
    )

    $results = [System.Collections.Generic.List[PSCustomObject]]::new()

    $sessionShimsToProcess = if ([string]::IsNullOrEmpty($CommandName)) { 
        $script:SessionShims.Keys 
    } 
    else { 
        @($CommandName) 
    }
    
    foreach ($cmd in $sessionShimsToProcess) {
        if ($script:SessionShims.ContainsKey($cmd)) {
            $results.Add([PSCustomObject]$script:SessionShims[$cmd])
        }
    }
    $results
}

function New-ResizeShim {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$TargetCommand,

        [Parameter()]
        [ValidateRange(50, 1000)]
        [int]$RibbonHeight = $script:CommonParameters.RibbonHeight,
        
        [Parameter()]
        [bool]$Force = $false,

        [Parameter()]
        [bool]$EnableAnimation = $script:CommonParameters.EnableAnimation,
        
        [Parameter()]
        [ValidateRange(0, 2000)]
        [int]$AnimationDuration = $script:CommonParameters.AnimationDuration,
        
        [Parameter()]
        [ValidateRange(10, 120)]
        [int]$AnimationFrameRate = $script:CommonParameters.AnimationFrameRate,
        
        [Parameter()]
        [ValidateSet("Linear", "EaseIn", "EaseOut", "EaseInOut")]
        [string]$AnimationType = $script:CommonParameters.AnimationType,
        
        [Parameter()]
        [string[]]$Trigger = $script:CommonParameters.Trigger
    )

    process {
        # Parse the target command into command name and arguments
        $targetParts = $TargetCommand.Trim() -split '\s+', 2
        $commandName = $targetParts[0]
        $arguments = if ($targetParts.Count -gt 1) { $targetParts[1] } else { $null }

        if ([string]::IsNullOrWhiteSpace($commandName)) {
            Write-Host "Could not parse a command name from '$TargetCommand'."
            return
        }
        
        # Check if the command is an alias and capture original target
        $originalTarget = $null
        try {
            $existingAlias = Get-Alias -Name $commandName -ErrorAction Stop
            if ($null -ne $existingAlias) {
                $originalTarget = $existingAlias.Definition
            }
        }
        catch {
            # Not an alias, or alias retrieval failed
        }

        $resolvedTarget = $null
        $resolvedPath = $null
        
        try {
            $cmdInfo = Get-Command $commandName -ErrorAction SilentlyContinue
            
            if ($null -eq $cmdInfo) {
                Write-Host "Command '$commandName' not found. Shim might fail unless it's available at runtime."
                $resolvedTarget = $commandName
            } 
            elseif ($cmdInfo.CommandType -eq 'Alias') {
                # Resolve aliases to their ultimate target
                $targetCmd = $cmdInfo.ResolvedCommand
                
                if ($null -ne $targetCmd) {
                    $resolvedTarget = $targetCmd.Name
                    
                    # Get path for Application or ExternalScript
                    if ($targetCmd.CommandType -eq 'Application' -or $targetCmd.CommandType -eq 'ExternalScript') {
                        $resolvedPath = $targetCmd.Path
                    }
                }
                else {
                    $resolvedTarget = $commandName
                }
            } 
            elseif ($cmdInfo.CommandType -eq 'Application' -or $cmdInfo.CommandType -eq 'ExternalScript') {
                # Direct executable or script
                $resolvedTarget = $cmdInfo.Name
                $resolvedPath = $cmdInfo.Path
            }
            else {
                $resolvedTarget = $cmdInfo.Name
            }

            # Ensure path is absolute if available
            if (-not [string]::IsNullOrEmpty($resolvedPath) -and -not [System.IO.Path]::IsPathRooted($resolvedPath)) {
                try {
                    $resolvedPath = (Resolve-Path -LiteralPath $resolvedPath -ErrorAction Stop).ProviderPath
                }
                catch {
                    # Keep original path if resolution fails
                }
            }
        }
        catch {
            Write-Host "Error resolving command '$commandName': $_. Using command name as target."
            $resolvedTarget = $commandName
        }

        $circularCommandNames = @()
        
        # For applications/executables with path, check for path collisions
        if (-not [string]::IsNullOrEmpty($resolvedPath)) {
            # Check session shims
            $sessionCircularCommands = $script:SessionShims.Keys | Where-Object {
                $script:SessionShims[$_].Path -eq $resolvedPath -and $_ -ne $commandName
            }
            if ($sessionCircularCommands) {
                $circularCommandNames += $sessionCircularCommands
            }
        }
        
        $sessionCircularCommands = $script:SessionShims.Keys | Where-Object {
            ($script:SessionShims[$_].Command -eq $commandName) -and $_ -ne $commandName
        }
        if ($sessionCircularCommands) {
            $circularCommandNames += $sessionCircularCommands
        }

        $circularCommandNames = $circularCommandNames | Select-Object -Unique
        foreach ($circularCommand in $circularCommandNames) {
            try {
                Remove-ResizeShim -CommandNames $circularCommand -Internal
            } 
            catch {
                Write-Host "Failed to remove circular reference shim '$circularCommand': $_"
            }
        }

        $shimExists = $script:SessionShims.ContainsKey($commandName)
        
        if ($shimExists) {
            $originalTarget = $null
            $originalPath = $null
            
            # Get the original target information from the existing shim
            if ($script:SessionShims.ContainsKey($commandName)) {
                $originalTarget = $script:SessionShims[$commandName].Target
                $originalPath = $script:SessionShims[$commandName].Path
            }
            
            if (-not $Force) {
                Write-Host "Shim for '$commandName' already exists. Use -Force to override."
                return
            }
            
            # Remove the existing shim before creating the new one
            Remove-ResizeShim -CommandNames $commandName -Internal
            
            # Use stored original values if our resolution failed
            if (($null -eq $resolvedTarget -or $resolvedTarget -like "$($script:SHIM_PREFIX)*") -and $null -ne $originalTarget) {
                $resolvedTarget = $originalTarget
            }
            
            if ([string]::IsNullOrEmpty($resolvedPath) -and -not [string]::IsNullOrWhiteSpace($originalPath)) {
                $resolvedPath = $originalPath
            }
        }
            
        $shimName = $script:SHIM_PREFIX + $commandName
        
        try {
            $shimInfo = @{
                Target             = $resolvedTarget
                Path               = $resolvedPath
                Arguments          = $arguments
                RibbonHeight       = $RibbonHeight
                EnableAnimation    = $EnableAnimation
                AnimationDuration  = $AnimationDuration
                AnimationFrameRate = $AnimationFrameRate
                AnimationType      = $AnimationType
                Command            = $commandName
            }

            if ($Trigger -and $Trigger.Count -gt 0) {
                $shimInfo['Trigger'] = $Trigger
            }

            # Store the original alias target if it exists
            if ($null -ne $originalTarget) {
                $shimInfo['Target'] = $originalTarget
            }

            $shimParams = @{
                Command            = $commandName
                Target             = $shimInfo.Target
                Arguments          = $shimInfo.Arguments
                CommandPath        = $shimInfo.Path
                RibbonHeight       = $shimInfo.RibbonHeight
                EnableAnimation    = $shimInfo.EnableAnimation
                AnimationDuration  = $shimInfo.AnimationDuration
                AnimationFrameRate = $shimInfo.AnimationFrameRate
                AnimationType      = $shimInfo.AnimationType
                Trigger            = $Trigger
            }

            $functionCode = New-ShimFunction @shimParams

            Invoke-Expression $functionCode
            
            $script:SessionShims[$commandName] = $shimInfo
            
            Write-Host "Created shim for '$commandName'"
        }
        catch {
            $errorMessage = $_
            
            # Clean up the function if it exists
            $shimFunction = Get-Command -Name $shimName -CommandType Function -ErrorAction SilentlyContinue
            if ($shimFunction) {
                try {
                    Remove-Item -Path "Function:$shimName" -Force -ErrorAction SilentlyContinue
                }
                catch {
                    # Ignore errors during cleanup
                }
            }
            
            $aliasExists = Get-Command -Name $commandName -CommandType Alias -ErrorAction SilentlyContinue | 
            Where-Object { $_.Definition -like "$shimName*" -or $_.Definition -eq $shimName }
            
            if ($aliasExists) {
                try {
                    Remove-Item -Path "Alias:$commandName" -Force -ErrorAction SilentlyContinue
                    
                    # Restore original alias if it existed
                    if ($originalTarget) {
                        Set-Alias -Name $commandName -Value $originalTarget -Scope Global -Force -ErrorAction SilentlyContinue
                    }
                }
                catch {
                    # Ignore errors during cleanup
                }
            }
            
            # Remove from session tracking if it exists
            if ($script:SessionShims.ContainsKey($commandName)) {
                $script:SessionShims.Remove($commandName) | Out-Null
            }
            
            Write-Host "Failed to create shim for '$commandName': $errorMessage"
        }
    }
}

function Remove-ResizeShim {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [string[]]$CommandNames,
        
        [Parameter(DontShow)] 
        [switch]$Internal
    )

    process {
        foreach ($commandName in $CommandNames) {
            $shimName = $script:SHIM_PREFIX + $commandName
            
            # Get original alias information for restoration
            $originalTarget = $null
            $isActualAlias = $false
            
            if ($script:SessionShims.ContainsKey($commandName)) {
                $isActualAlias = [string]::IsNullOrEmpty($script:SessionShims[$commandName].Path)
                
                if ($script:SessionShims[$commandName].ContainsKey('Target')) {
                    $originalTarget = $script:SessionShims[$commandName].Target
                }
            }
            else {
                if (-not $Internal) {
                    Write-Host "Shim for '$commandName' not found."
                }
            }
            
            try {
                $aliasesToRemove = Get-Command -Name $commandName -CommandType Alias -ErrorAction SilentlyContinue | 
                Where-Object { $_.Definition -like "$shimName*" -or $_.Definition -eq $shimName }
                
                foreach ($alias in $aliasesToRemove) {
                    Remove-Item -Path "Alias:$($alias.Name)" -Force -ErrorAction Stop
                }
            }
            catch {
                if (-not $Internal) {
                    Write-Host "Error removing alias for $commandName`: $_"
                }
            }
            
            # Remove the shim function
            try {
                $shimFunction = Get-Command -Name $shimName -CommandType Function -ErrorAction SilentlyContinue
                if ($shimFunction) {
                    Remove-Item -Path "Function:$shimName" -Force -ErrorAction Stop
                }
            }
            catch {
                if (-not $Internal) {
                    Write-Host "Error removing shim function $shimName`: $_"
                }
            }
            
            if ($script:SessionShims.ContainsKey($commandName)) {
                $script:SessionShims.Remove($commandName) | Out-Null
            }
            
            # Restore original alias if applicable
            if ($isActualAlias -and $originalTarget) {
                try {
                    Set-Alias -Name $commandName -Value $originalTarget -Scope Global -Force
                }
                catch {
                    if (-not $Internal) {
                        Write-Host "Error restoring original alias for $commandName`: $_"
                    }
                }
            }
            
            if (-not $Internal) {
                Write-Host "Removed shim for '$commandName'"
            }
        }
    }
}

Export-ModuleMember -Function Resize-Terminal, New-ResizeShim, Get-ResizeShim, Remove-ResizeShim