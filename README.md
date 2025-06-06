# ResizeTerminal

ResizeTerminal is a PowerShell module that temporarily resizes your terminal window when running certain commands, creating a "ribbon" effect for commands with long output. After the command completes, the terminal returns to its original size. Primarily intended for me to babysit build processes while saving screen space.

![ResizeTerminal Demo](images/demo-main.gif)

## Features

-   Automatically shrinks your terminal window when running configured commands
-   Smooth animations when resizing (with customizable easing functions)
-   Easily create and manage shims for your most-used commands
-   Trigger resizing only when specific arguments are used
-   Works with Windows Terminal, PowerShell, cmd, and other console applications
-   Works great with [Windows-Terminal-Quake](https://github.com/flyingpie/windows-terminal-quake)


## Installation

### Manual Installation

1. Clone this repository:

```
git clone https://github.com/nimbuldev/wt-shrink.git
```

2. Copy the module to your PowerShell modules directory:

```pwsh
# Create the module directory if it doesn't exist
$modulesDir = "$env:USERPROFILE\Documents\PowerShell\Modules\ResizeTerminal"
if (-not (Test-Path $modulesDir)) {
    New-Item -Path $modulesDir -ItemType Directory -Force
}

# Copy module files
Copy-Item -Path ".\wt-shrink\*" -Destination $modulesDir -Recurse -Force
```

### Loading the Module in Your PowerShell Profile

Add the following to your PowerShell profile to load the module automatically when PowerShell starts:

1. Open your PowerShell profile:

```powershell
notepad $PROFILE # best code editor
```

2. Add the following line to your profile:

```powershell
Import-Module ResizeTerminal

# Optionally, add your shims here for persistence.
```

3. Save and close the file.

4. Reload your profile:

```powershell
. $PROFILE
```

## Basic Usage

### Direct Command Execution with Resizing

```powershell
# Run a command in a resized terminal window (basic usage)
Resize-Terminal -Command "npm install" -RibbonHeight 150

# Run a command with custom animation
Resize-Terminal -Command { docker ps -a } -RibbonHeight 200 -AnimationType "EaseInOut" -AnimationDuration 300 -AnimationFrameRate 90
```

[Basic Usage Example](https://github.com/user-attachments/assets/57d8b849-d6be-47e4-ae55-183610500e53)

### Creating Simple Command Shims

```powershell
# Create a basic shim for npm
New-ResizeShim "npm" -RibbonHeight 150

# Now just run the command as usual, and it will execute with the terminal resized
npm install

# Create a shim with custom animation settings
New-ResizeShim "docker" -RibbonHeight 200 -AnimationType "EaseInOut" -AnimationDuration 300
```
Note: Creating a shim with arguments or using a relative path is not fully supported. For example, `New-ResizeShim "npm install" -RibbonHeight 150` will alias "npm" to invoke "npm install." 
If you're trying to do this, you're probably actually looking for the next section of this README.


### Conditional Resizing with Triggers

You can create shims that only resize the terminal when specific subcommands or arguments are present:

```powershell
# Only resize terminal when running "npm install" or "npm update", but not other npm commands
New-ResizeShim "npm" -Trigger @("install", "update") -RibbonHeight 150

# Create a shim for python that only resizes when running a specific script
New-ResizeShim "python" -Trigger @("data_processing.py", "long_running.py") -RibbonHeight 200

# Shim for kubectl that resizes only when viewing logs
New-ResizeShim "kubectl" -Trigger @("logs", "describe pod") -RibbonHeight 300
```

[Trigger Feature Demo](https://github.com/user-attachments/assets/263b31da-6aee-433f-8073-74a714506ceb)


### Managing Shims
Shims are session-scoped. This module saves no files and has no persistence. For permanent shims, add the module and New-ResizeShim commands to your terminal profile.

```powershell
# List all created shims
Get-ResizeShim

# Get details about a specific shim
Get-ResizeShim npm

# Remove a shim
Remove-ResizeShim npm
```

## Configuration Options

### Ribbon Height

Control how tall the ribbon should be:

```powershell
New-ResizeShim "npm" -RibbonHeight 150  # Smaller ribbon (minimum: 50)
New-ResizeShim "docker" -RibbonHeight 300    # Larger ribbon
```

### Animation Settings

Customize the animation behavior:

```powershell
# Disable animation
New-ResizeShim "npm" -EnableAnimation:$false

# Change animation duration (milliseconds)
New-ResizeShim "npm" -AnimationDuration 500  # Slower animation
New-ResizeShim "npm" -AnimationDuration 100  # Faster animation

# Change animation easing type
New-ResizeShim "npm" -AnimationType "Linear"    # Linear animation
New-ResizeShim "npm" -AnimationType "EaseIn"    # Accelerating animation
New-ResizeShim "npm" -AnimationType "EaseOut"   # Decelerating animation (default)
New-ResizeShim "npm" -AnimationType "EaseInOut" # Smooth acceleration and deceleration
```

## Troubleshooting

### Window Detection Issues

If the module fails to detect your terminal window correctly, try running in the main terminal window (not a nested console)

### Command Not Found After Creating Shim

If your command is not found after creating a shim:

```powershell
# Check if the shim exists
Get-ResizeShim yourcommand

# Try removing and recreating the shim
Remove-ResizeShim yourcommand
New-ResizeShim "yourcommand" -RibbonHeight 150

# Or just do that faster with -Force
New-ResizeShim "yourcommand" -RibbonHeight 150 -Force
```

### Animation Not Working

Verify your Windows config has animation enabled.

## Compatibility

-   Windows 10/11
-   PowerShell 5.1 and PowerShell 7+
-   Probably like... most terminals. If you have an integrated terminal that loads your profile-- be warned. My VSCode is still sore.
-   Works with Windows Terminal Quake Mode

## License

This project is licensed under the MIT License I guess - you know the one. I don't care what you do.
