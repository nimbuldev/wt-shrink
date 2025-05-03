# ResizeTerminal

ResizeTerminal is a PowerShell module that temporarily resizes your terminal window when running commands, creating a "ribbon" effect for commands with extensive output. After the command completes, the terminal returns to its original size.

<!-- TODO: Replace with an actual GIF demonstration of the basic resize functionality -->

![ResizeTerminal Demo](images/demo-main.gif)

## Features

-   **Temporary Window Resizing**: Automatically shrinks your terminal window when running commands
-   **Animated Transitions**: Smooth animations when resizing (with customizable easing functions)
-   **Command Shimming**: Easily create shims for your most-used commands
-   **Conditional Resizing**: Trigger resizing only when specific arguments are used
-   **Compatible**: Works with Windows Terminal, PowerShell, cmd, and other console applications
-   **Quake Mode Compatible**: Works great with [Windows-Terminal-Quake](https://github.com/flyingpie/windows-terminal-quake) for an even more dynamic terminal experience

<!-- TODO: Add a GIF showing integration with Windows-Terminal-Quake -->

![ResizeTerminal with Quake Mode](images/demo-quake-mode.gif)

## Installation

### Manual Installation

1. Clone this repository:

```powershell
git clone https://github.com/nimbuldev/wt-shrink.git
```

2. Copy the module to your PowerShell modules directory:

```powershell
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
notepad $PROFILE
```

2. Add the following line to your profile:

```powershell
Import-Module ResizeTerminal
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
Resize-Terminal -Command "docker ps -a" -RibbonHeight 200 -AnimationType "EaseInOut" -AnimationDuration 300 -AnimationFrameRate 90
```

<!-- TODO: Add a GIF showing a simple command being executed with terminal resizing -->

![Basic Usage Example](images/demo-basic-usage.gif)

### Creating Command Shims

```powershell
# Create a basic shim for npm install
New-ResizeShim "npm install" -RibbonHeight 150

# Now just run the command as usual, and it will execute with the terminal resized
npm install

# Create a shim with custom animation settings
New-ResizeShim "docker ps -a" -RibbonHeight 200 -AnimationType "EaseInOut" -AnimationDuration 300
```

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

<!-- TODO: Add a GIF demonstrating conditional resizing with triggers -->

![Trigger Feature Demo](images/demo-triggers.gif)

### Managing Shims

```powershell
# List all created shims
Get-ResizeShim

# Get details about a specific shim
Get-ResizeShim npm

# Remove a shim
Remove-ResizeShim npm
```

## Windows Terminal Quake Mode Integration

ResizeTerminal works especially well with [Windows-Terminal-Quake](https://github.com/flyingpie/windows-terminal-quake), which provides a Quake-style drop-down terminal for Windows.

When combined with Quake mode, you can:

1. Drop down your terminal with a hotkey
2. Run commands that automatically resize to a ribbon
3. Return to full size after command completion
4. Hide the terminal with the hotkey when done

This creates an efficient workflow where the terminal is only visible when needed and automatically adjusts its size based on the current task.

<!-- TODO: Add a GIF showing a complete workflow with Quake mode and ResizeTerminal -->

![Complete Workflow Demo](images/demo-workflow.gif)

### Setup with Windows Terminal Quake

1. Install [Windows-Terminal-Quake](https://github.com/flyingpie/windows-terminal-quake)
2. Configure your preferred hotkey for the drop-down terminal
3. Install the ResizeTerminal module as described above
4. Create shims for your common commands

Now you can enjoy a streamlined terminal experience that dynamically resizes based on your needs.

## Configuration Options

### Ribbon Height

Control how tall the ribbon should be:

```powershell
New-ResizeShim "npm install" -RibbonHeight 150  # Smaller ribbon (minimum: 50)
New-ResizeShim "docker ps" -RibbonHeight 300    # Larger ribbon
```

### Animation Settings

Customize the animation behavior:

```powershell
# Disable animation
New-ResizeShim "npm install" -EnableAnimation:$false

# Change animation duration (milliseconds)
New-ResizeShim "npm install" -AnimationDuration 500  # Slower animation
New-ResizeShim "npm install" -AnimationDuration 100  # Faster animation

# Change animation easing type
New-ResizeShim "npm install" -AnimationType "Linear"    # Linear animation
New-ResizeShim "npm install" -AnimationType "EaseIn"    # Accelerating animation
New-ResizeShim "npm install" -AnimationType "EaseOut"   # Decelerating animation (default)
New-ResizeShim "npm install" -AnimationType "EaseInOut" # Smooth acceleration and deceleration
```

## Advanced Examples

### Example 1: Creating a git shim that only resizes for specific operations

```powershell
# Create a git shim that only resizes for potentially verbose operations
New-ResizeShim "git" -RibbonHeight 200 -Trigger @("log", "diff", "blame", "reflog")
```

### Example 2: Custom animation for different commands

```powershell
# Fast animation for quick commands
New-ResizeShim "npm list" -AnimationDuration 100 -RibbonHeight 300

# Slower, smoother animation for commands where you want to see the transition
New-ResizeShim "docker build" -AnimationDuration 400 -AnimationType "EaseInOut" -RibbonHeight 200
```

## Troubleshooting

### Window Detection Issues

If the module fails to detect your terminal window correctly:

```powershell
# Try running in the main terminal window (not a nested console)
# Make sure you're using a supported terminal (Windows Terminal, PowerShell, CMD)
```

### Command Not Found After Creating Shim

If your command is not found after creating a shim:

```powershell
# Check if the shim exists
Get-ResizeShim yourcommand

# Try removing and recreating the shim
Remove-ResizeShim yourcommand
New-ResizeShim "yourcommand" -RibbonHeight 150
```

### Animation Not Working

If animations aren't working:

```powershell
# Try with a longer duration to make sure it's not just too fast
New-ResizeShim "yourcommand" -AnimationDuration 1000 -RibbonHeight 150

# Verify your Windows version supports the animation APIs
```

## Compatibility

-   Windows 10/11
-   PowerShell 5.1 and PowerShell 7+
-   Windows Terminal, PowerShell Console, and Command Prompt
-   Works with Windows Terminal Quake Mode

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request
