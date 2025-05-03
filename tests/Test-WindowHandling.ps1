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

# Execute the test header
Invoke-Command -ScriptBlock $global:WriteTestHeader -ArgumentList "Window Handling and External Functions Tests"

# Test 1: Resize-Terminal function basic validation
try {
    # We're not actually going to call Resize-Terminal with a real command
    # since that would execute something, but we can validate it has the expected parameters
    
    $cmdInfo = Get-Command -Name Resize-Terminal
    
    $hasRequiredParams = $cmdInfo.Parameters.ContainsKey("Command") -and
    $cmdInfo.Parameters.ContainsKey("RibbonHeight") -and
    $cmdInfo.Parameters.ContainsKey("EnableAnimation") -and
    $cmdInfo.Parameters.ContainsKey("AnimationDuration") -and
    $cmdInfo.Parameters.ContainsKey("AnimationFrameRate") -and
    $cmdInfo.Parameters.ContainsKey("AnimationType")
                        
    # Make sure the command parameter is positional and mandatory
    $commandParam = $cmdInfo.Parameters["Command"]
    $correctPosition = $commandParam.Attributes | 
    Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] -and $_.Position -eq 0 }
                      
    $commandIsMandatory = $commandParam.Attributes | 
    Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] -and $_.Mandatory -eq $true }
    
    $result = $hasRequiredParams -and $correctPosition -and $commandIsMandatory
              
    Invoke-Command -ScriptBlock $global:WriteTestResult -ArgumentList "Resize-Terminal validation", $result, "Resize-Terminal function missing expected parameters"
}
catch {
    Invoke-Command -ScriptBlock $global:WriteTestResult -ArgumentList "Resize-Terminal validation", $false, "Exception: $_"
}

# Test 2: Verify the module has loaded the .NET types needed
try {
    # Check if the module has loaded the types needed for window manipulation
    $moduleLoaded = Get-Module -Name ResizeTerminal
    $result = $null -ne $moduleLoaded
    
    Invoke-Command -ScriptBlock $global:WriteTestResult -ArgumentList "Module loaded", $result, "Module not properly loaded"
}
catch {
    Invoke-Command -ScriptBlock $global:WriteTestResult -ArgumentList "Module loaded", $false, "Exception: $_"
}

# Test 3: Test creating and manipulating a shim
try {
    # Create a test shim that does nothing but echo
    $testCmd = "test-window-cmd"
    Remove-ResizeShim -CommandNames $testCmd -ErrorAction SilentlyContinue | Out-Null
    
    # Create a shim with custom window settings
    New-ResizeShim -TargetCommand $testCmd -RibbonHeight 200 -EnableAnimation $true -AnimationDuration 300
    
    # Check if the shim was created properly
    $shim = Get-ResizeShim -CommandName $testCmd
    $result = ($null -ne $shim) -and 
    ($shim.RibbonHeight -eq 200) -and
    ($shim.EnableAnimation -eq $true) -and
    ($shim.AnimationDuration -eq 300)
    
    Invoke-Command -ScriptBlock $global:WriteTestResult -ArgumentList "Window-related shim parameters", $result, "Failed to create shim with custom window parameters"
    
    # Clean up
    Remove-ResizeShim -CommandNames $testCmd -ErrorAction SilentlyContinue | Out-Null
}
catch {
    Invoke-Command -ScriptBlock $global:WriteTestResult -ArgumentList "Window-related shim parameters", $false, "Exception: $_"
    # Attempt to clean up even after a failure
    Remove-ResizeShim -CommandNames "test-window-cmd" -ErrorAction SilentlyContinue | Out-Null
}