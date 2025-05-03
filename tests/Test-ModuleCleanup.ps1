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
Invoke-Command -ScriptBlock $global:WriteTestHeader -ArgumentList "Module Cleanup Tests"

# Make sure the module is loaded
if (-not (Get-Module -Name ResizeTerminal)) {
    Import-Module "$PSScriptRoot\..\ResizeTerminal.psd1" -Force
}

# Test 1: Module cleanup function exists
try {
    $module = Get-Module ResizeTerminal
    $result = $null -ne $module.OnRemove
    
    Invoke-Command -ScriptBlock $global:WriteTestResult -ArgumentList "Module cleanup function exists", $result, "Module cleanup function is not defined"
}
catch {
    Invoke-Command -ScriptBlock $global:WriteTestResult -ArgumentList "Module cleanup function exists", $false, "Exception: $_"
}

# Test 2: Cleanup removes shims properly
try {
    # Create some test shims for cleanup testing
    $testShims = @("cleanup-test1", "cleanup-test2", "cleanup-test3")
    
    foreach ($shimName in $testShims) {
        New-ResizeShim -TargetCommand $shimName -RibbonHeight 150
    }
    
    # Verify shims were created
    $createdShims = @(Get-ResizeShim | Where-Object { $testShims -contains $_.Command })
    $allShimsCreated = ($createdShims.Count -eq $testShims.Count)
    
    if (-not $allShimsCreated) {
        throw "Failed to create test shims for cleanup test"
    }
    
    # Get the list of functions before removal
    $beforeFunctions = @(Get-ChildItem Function: | Where-Object { $_.Name -like "Resized_cleanup-test*" })
    $beforeAliases = @(Get-Alias | Where-Object { $testShims -contains $_.Name })
    
    # Reload the module to trigger cleanup
    Remove-Module ResizeTerminal -Force
    Import-Module "$PSScriptRoot\..\ResizeTerminal.psd1" -Force
    
    # Check if the shims were cleaned up
    $afterFunctions = @(Get-ChildItem Function: | Where-Object { $_.Name -like "Resized_cleanup-test*" })
    $afterAliases = @(Get-Alias | Where-Object { $testShims -contains $_.Name })
    
    $functionsCleaned = ($afterFunctions.Count -eq 0)
    $aliasesCleaned = ($afterAliases.Count -eq 0)
    $result = $functionsCleaned -and $aliasesCleaned
    
    Invoke-Command -ScriptBlock $global:WriteTestResult -ArgumentList "Module cleanup removes shims", $result, "Shims not properly removed during module cleanup"
}
catch {
    Invoke-Command -ScriptBlock $global:WriteTestResult -ArgumentList "Module cleanup removes shims", $false, "Exception: $_"
}

# Test 3: Verify internal state is clean after module reload
try {
    # Create a new test shim
    New-ResizeShim -TargetCommand "cleanup-session-test" -RibbonHeight 150
    
    # Store the reference to the shim we just created
    $shimBefore = Get-ResizeShim -CommandName "cleanup-session-test"
    $shimExists = $null -ne $shimBefore
    
    # Remove the module to trigger cleanup
    Remove-Module ResizeTerminal -Force
    
    # Clean up any stray aliases or functions that might remain
    Remove-Item -Path "Function:Resized_cleanup-session-test" -ErrorAction SilentlyContinue
    Remove-Item -Path "Alias:cleanup-session-test" -ErrorAction SilentlyContinue
    
    # Reimport the module
    Import-Module "$PSScriptRoot\..\ResizeTerminal.psd1" -Force
    
    # Check if shim is gone after module reload - this tests the internal state
    $shimAfter = Get-ResizeShim -CommandName "cleanup-session-test"
    $clearedCorrectly = ($null -eq $shimAfter)
    
    Invoke-Command -ScriptBlock $global:WriteTestResult -ArgumentList "Module cleanup clears internal state", $clearedCorrectly, "Internal module state not properly cleared during cleanup"
}
catch {
    Invoke-Command -ScriptBlock $global:WriteTestResult -ArgumentList "Module cleanup clears internal state", $false, "Exception: $_"
}

# Clean up any remaining test shims
$testShims = @("cleanup-test1", "cleanup-test2", "cleanup-test3", "cleanup-session-test")
foreach ($shimName in $testShims) {
    Remove-ResizeShim -CommandNames $shimName -ErrorAction SilentlyContinue | Out-Null
}