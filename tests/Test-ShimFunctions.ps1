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

# Call test header
Invoke-Command -ScriptBlock $global:WriteTestHeader -ArgumentList "Shim Function Tests"

# Clean up any existing test shims
Remove-ResizeShim -CommandNames "test-cmd", "test-cmd-args", "test-cmd-override" -ErrorAction SilentlyContinue | Out-Null

# Test 1: Create a basic shim
try {
    New-ResizeShim -TargetCommand "test-cmd" -RibbonHeight 120
    $shim = Get-ResizeShim -CommandName "test-cmd"
    $result = ($null -ne $shim) -and ($shim.RibbonHeight -eq 120) -and ($shim.Command -eq "test-cmd")
    Invoke-Command -ScriptBlock $global:WriteTestResult -ArgumentList "Creating basic shim", $result, "Failed to create or verify basic shim"
    
    # Also test if the function and alias were created
    $shimFunction = Get-Command -Name "Resized_test-cmd" -CommandType Function -ErrorAction SilentlyContinue
    $shimAlias = Get-Alias -Name "test-cmd" -ErrorAction SilentlyContinue
    
    $result = ($null -ne $shimFunction) -and ($null -ne $shimAlias)
    Invoke-Command -ScriptBlock $global:WriteTestResult -ArgumentList "Shim function and alias creation", $result, "Shim function or alias not created properly"
}
catch {
    Invoke-Command -ScriptBlock $global:WriteTestResult -ArgumentList "Creating basic shim", $false, "Exception: $_"
}

# Test 2: Create a shim with arguments
try {
    New-ResizeShim -TargetCommand "test-cmd-args arg1 arg2" -RibbonHeight 150
    $shim = Get-ResizeShim -CommandName "test-cmd-args"
    $result = ($null -ne $shim) -and 
    ($shim.RibbonHeight -eq 150) -and 
    ($shim.Command -eq "test-cmd-args") -and 
    ($shim.Arguments -eq "arg1 arg2")
              
    Invoke-Command -ScriptBlock $global:WriteTestResult -ArgumentList "Creating shim with arguments", $result, "Failed to create or verify shim with arguments"
}
catch {
    Invoke-Command -ScriptBlock $global:WriteTestResult -ArgumentList "Creating shim with arguments", $false, "Exception: $_"
}

# Test 3: Override an existing shim
try {
    New-ResizeShim -TargetCommand "test-cmd-override" -RibbonHeight 120
    New-ResizeShim -TargetCommand "test-cmd-override" -RibbonHeight 180 -Force $true
    
    $shim = Get-ResizeShim -CommandName "test-cmd-override"
    $result = ($null -ne $shim) -and ($shim.RibbonHeight -eq 180)
    
    Invoke-Command -ScriptBlock $global:WriteTestResult -ArgumentList "Overriding existing shim", $result, "Failed to override existing shim"
}
catch {
    Invoke-Command -ScriptBlock $global:WriteTestResult -ArgumentList "Overriding existing shim", $false, "Exception: $_"
}

# Test 4: Try to create a duplicate shim without override
try {
    New-ResizeShim -TargetCommand "test-cmd" -RibbonHeight 200
    $shim = Get-ResizeShim -CommandName "test-cmd"
    # Should still be the original height
    $result = ($shim.RibbonHeight -eq 120)
    Invoke-Command -ScriptBlock $global:WriteTestResult -ArgumentList "Duplicate shim protection", $result, "Failed to protect against duplicate shim"
}
catch {
    Invoke-Command -ScriptBlock $global:WriteTestResult -ArgumentList "Duplicate shim protection", $false, "Exception: $_"
}

# Test 5: Get all shims
try {
    $shims = Get-ResizeShim
    $result = ($shims.Count -ge 3) -and 
    ($shims | Where-Object { $_.Command -eq "test-cmd" }) -and
    ($shims | Where-Object { $_.Command -eq "test-cmd-args" }) -and
    ($shims | Where-Object { $_.Command -eq "test-cmd-override" })
              
    Invoke-Command -ScriptBlock $global:WriteTestResult -ArgumentList "List all shims", $result, "Failed to list all shims"
}
catch {
    Invoke-Command -ScriptBlock $global:WriteTestResult -ArgumentList "List all shims", $false, "Exception: $_"
}

# Test 6: Get specific shim
try {
    $shim = Get-ResizeShim -CommandName "test-cmd-args"
    $result = ($null -ne $shim) -and ($shim.Command -eq "test-cmd-args") -and ($shim.Arguments -eq "arg1 arg2")
    Invoke-Command -ScriptBlock $global:WriteTestResult -ArgumentList "Get specific shim", $result, "Failed to get specific shim"
}
catch {
    Invoke-Command -ScriptBlock $global:WriteTestResult -ArgumentList "Get specific shim", $false, "Exception: $_"
}

# Test 7: Remove a shim
try {
    Remove-ResizeShim -CommandNames "test-cmd-args"
    $shim = Get-ResizeShim -CommandName "test-cmd-args"
    $shimFunction = Get-Command -Name "Resized_test-cmd-args" -CommandType Function -ErrorAction SilentlyContinue
    
    $result = ($null -eq $shim) -and ($null -eq $shimFunction)
    Invoke-Command -ScriptBlock $global:WriteTestResult -ArgumentList "Remove shim", $result, "Failed to remove shim"
}
catch {
    Invoke-Command -ScriptBlock $global:WriteTestResult -ArgumentList "Remove shim", $false, "Exception: $_"
}

# Test 8: Multiple shim removal
try {
    Remove-ResizeShim -CommandNames "test-cmd", "test-cmd-override"
    $shim1 = Get-ResizeShim -CommandName "test-cmd"
    $shim2 = Get-ResizeShim -CommandName "test-cmd-override"
    
    $result = ($null -eq $shim1) -and ($null -eq $shim2)
    Invoke-Command -ScriptBlock $global:WriteTestResult -ArgumentList "Remove multiple shims", $result, "Failed to remove multiple shims"
}
catch {
    Invoke-Command -ScriptBlock $global:WriteTestResult -ArgumentList "Remove multiple shims", $false, "Exception: $_"
}

# Test 9: Verify all test shims are removed
try {
    $shims = @(Get-ResizeShim | Where-Object { $_.Command -like "test-cmd*" })
    $result = ($shims.Count -eq 0)
    Invoke-Command -ScriptBlock $global:WriteTestResult -ArgumentList "Verify all test shims removed", $result, "Some test shims remain after cleanup"
}
catch {
    Invoke-Command -ScriptBlock $global:WriteTestResult -ArgumentList "Verify all test shims removed", $false, "Exception: $_"
}