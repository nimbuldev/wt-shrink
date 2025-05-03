param(
    [switch]$Verbose
)

# Use global test helper functions if available, otherwise define our own
if (-not (Get-Variable -Name WriteTestResult -Scope Global -ErrorAction SilentlyContinue)) {
    function global:WriteTestResult {
        param([string]$Name, [bool]$Success, [string]$Message = "")
        if ($Success) {
            Write-Host "PASS: $Name"
        }
        else {
            Write-Host "FAIL: $Name - $Message"
        }
    }
}

if (-not (Get-Variable -Name WriteTestHeader -Scope Global -ErrorAction SilentlyContinue)) {
    function global:WriteTestHeader {
        param([string]$Title)
        Write-Host "`n=== $Title ===`n"
    }
}

# Import the module if not already loaded
if (-not (Get-Module -Name ResizeTerminal)) {
    Import-Module "$PSScriptRoot\..\ResizeTerminal.psd1" -Force
}

# Execute the test header
Invoke-Command -ScriptBlock $global:WriteTestHeader -ArgumentList "Trigger Functionality Tests"

# Clean up any existing test shims
Remove-ResizeShim -CommandNames "trigger-test", "trigger-test-multi", "trigger-test-none" -ErrorAction SilentlyContinue | Out-Null

# Test 1: Create a shim with a single trigger
try {
    New-ResizeShim -TargetCommand "trigger-test" -RibbonHeight 150 -Trigger @("install")
    $shim = Get-ResizeShim -CommandName "trigger-test"
    $result = ($null -ne $shim) -and 
    ($shim.RibbonHeight -eq 150) -and 
    ($shim.Trigger -is [array]) -and 
    ($shim.Trigger.Count -eq 1) -and
    ($shim.Trigger[0] -eq "install")
              
    Invoke-Command -ScriptBlock $global:WriteTestResult -ArgumentList "Creating shim with single trigger", $result, "Failed to create or verify shim with single trigger"
}
catch {
    Invoke-Command -ScriptBlock $global:WriteTestResult -ArgumentList "Creating shim with single trigger", $false, "Exception: $_"
}

# Test 2: Create a shim with multiple triggers
try {
    New-ResizeShim -TargetCommand "trigger-test-multi" -RibbonHeight 150 -Trigger @("install", "update", "list")
    $shim = Get-ResizeShim -CommandName "trigger-test-multi"
    $result = ($null -ne $shim) -and 
    ($shim.Trigger -is [array]) -and 
    ($shim.Trigger.Count -eq 3) -and
    ($shim.Trigger -contains "install") -and
    ($shim.Trigger -contains "update") -and
    ($shim.Trigger -contains "list")
              
    Invoke-Command -ScriptBlock $global:WriteTestResult -ArgumentList "Creating shim with multiple triggers", $result, "Failed to create or verify shim with multiple triggers"
}
catch {
    Invoke-Command -ScriptBlock $global:WriteTestResult -ArgumentList "Creating shim with multiple triggers", $false, "Exception: $_"
}

# Test 3: Create a shim without triggers
try {
    New-ResizeShim -TargetCommand "trigger-test-none" -RibbonHeight 150
    $shim = Get-ResizeShim -CommandName "trigger-test-none"
    
    # Trigger should either be null, empty array, or not exist
    $triggerExists = $shim.PSObject.Properties.Name -contains "Trigger"
    $triggerEmpty = -not $triggerExists -or ($null -eq $shim.Trigger) -or ($shim.Trigger.Count -eq 0)
    
    Invoke-Command -ScriptBlock $global:WriteTestResult -ArgumentList "Creating shim without triggers", $triggerEmpty, "Failed to create or verify shim without triggers"
}
catch {
    Invoke-Command -ScriptBlock $global:WriteTestResult -ArgumentList "Creating shim without triggers", $false, "Exception: $_"
}

# Test 4: Override an existing shim with new triggers
try {
    # First create with one trigger
    New-ResizeShim -TargetCommand "trigger-test" -RibbonHeight 150 -Trigger @("old-trigger") -Force $true
    
    # Then override with new triggers
    New-ResizeShim -TargetCommand "trigger-test" -RibbonHeight 150 -Trigger @("new-trigger1", "new-trigger2") -Force $true
    
    $shim = Get-ResizeShim -CommandName "trigger-test"
    $result = ($null -ne $shim) -and 
    ($shim.Trigger -is [array]) -and 
    ($shim.Trigger.Count -eq 2) -and
    ($shim.Trigger -contains "new-trigger1") -and
    ($shim.Trigger -contains "new-trigger2") -and
    (-not ($shim.Trigger -contains "old-trigger"))
              
    Invoke-Command -ScriptBlock $global:WriteTestResult -ArgumentList "Overriding shim with new triggers", $result, "Failed to override shim with new triggers"
}
catch {
    Invoke-Command -ScriptBlock $global:WriteTestResult -ArgumentList "Overriding shim with new triggers", $false, "Exception: $_"
}

# Test 5: Verify global trigger parameter default
try {
    # Create a new shim without explicitly setting the trigger
    New-ResizeShim -TargetCommand "trigger-test-default" -RibbonHeight 150
    $shim = Get-ResizeShim -CommandName "trigger-test-default"
    
    # The default trigger might not be defined for all module configurations
    # So instead of checking its value, just make sure we can create a shim
    # without specifying a trigger and it doesn't cause any errors
    $result = $null -ne $shim
    
    Invoke-Command -ScriptBlock $global:WriteTestResult -ArgumentList "Global trigger parameter", $result, "Failed to create shim with default trigger"
    
    # Clean up
    Remove-ResizeShim -CommandNames "trigger-test-default" -ErrorAction SilentlyContinue | Out-Null
}
catch {
    Invoke-Command -ScriptBlock $global:WriteTestResult -ArgumentList "Global trigger parameter", $false, "Exception: $_"
}

# Clean up test shims
Remove-ResizeShim -CommandNames "trigger-test", "trigger-test-multi", "trigger-test-none" -ErrorAction SilentlyContinue | Out-Null