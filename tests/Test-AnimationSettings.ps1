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
Invoke-Command -ScriptBlock $global:WriteTestHeader -ArgumentList "Animation Settings Tests"

# Clean up any existing test shims
Remove-ResizeShim -CommandNames "anim-test-*" -ErrorAction SilentlyContinue | Out-Null

# Test 1: Default animation settings
try {
    # First create a shim to get the default values
    New-ResizeShim -TargetCommand "anim-test-default" -RibbonHeight 150
    $shim = Get-ResizeShim -CommandName "anim-test-default"
    
    # Store defaults for later comparison
    $defaultEnableAnimation = $shim.EnableAnimation 
    $defaultAnimationDuration = $shim.AnimationDuration
    $defaultAnimationFrameRate = $shim.AnimationFrameRate
    $defaultAnimationType = $shim.AnimationType
    
    # Check that defaults are reasonable values
    $result = ($null -ne $shim) -and 
    ($null -ne $defaultEnableAnimation) -and
    ($defaultAnimationDuration -gt 0) -and
    ($defaultAnimationFrameRate -gt 0) -and
    (-not [string]::IsNullOrEmpty($defaultAnimationType))
              
    Invoke-Command -ScriptBlock $global:WriteTestResult -ArgumentList "Default animation settings", $result, "Animation settings contain null or invalid values"
}
catch {
    Invoke-Command -ScriptBlock $global:WriteTestResult -ArgumentList "Default animation settings", $false, "Exception: $_"
}

# Test 2: Animation disabled
try {
    New-ResizeShim -TargetCommand "anim-test-disabled" -RibbonHeight 150 -EnableAnimation:$false
    $shim = Get-ResizeShim -CommandName "anim-test-disabled"
    $result = ($null -ne $shim) -and ($shim.EnableAnimation -eq $false)
              
    Invoke-Command -ScriptBlock $global:WriteTestResult -ArgumentList "Animation disabled setting", $result, "Failed to set animation disabled"
}
catch {
    Invoke-Command -ScriptBlock $global:WriteTestResult -ArgumentList "Animation disabled setting", $false, "Exception: $_"
}

# Test 3: Custom animation duration
try {
    New-ResizeShim -TargetCommand "anim-test-duration" -RibbonHeight 150 -AnimationDuration 500
    $shim = Get-ResizeShim -CommandName "anim-test-duration"
    $result = ($null -ne $shim) -and ($shim.AnimationDuration -eq 500)
              
    Invoke-Command -ScriptBlock $global:WriteTestResult -ArgumentList "Custom animation duration", $result, "Failed to set custom animation duration"
}
catch {
    Invoke-Command -ScriptBlock $global:WriteTestResult -ArgumentList "Custom animation duration", $false, "Exception: $_"
}

# Test 4: Custom animation frame rate
try {
    New-ResizeShim -TargetCommand "anim-test-framerate" -RibbonHeight 150 -AnimationFrameRate 90
    $shim = Get-ResizeShim -CommandName "anim-test-framerate"
    $result = ($null -ne $shim) -and ($shim.AnimationFrameRate -eq 90)
              
    Invoke-Command -ScriptBlock $global:WriteTestResult -ArgumentList "Custom animation frame rate", $result, "Failed to set custom animation frame rate"
}
catch {
    Invoke-Command -ScriptBlock $global:WriteTestResult -ArgumentList "Custom animation frame rate", $false, "Exception: $_"
}

# Test 5: Animation types
try {
    $animTypes = @("Linear", "EaseIn", "EaseOut", "EaseInOut")
    $allSuccess = $true
    $failedType = ""
    
    foreach ($type in $animTypes) {
        $cmdName = "anim-test-type-$type"
        New-ResizeShim -TargetCommand $cmdName -RibbonHeight 150 -AnimationType $type
        $shim = Get-ResizeShim -CommandName $cmdName
        
        if (($null -eq $shim) -or ($shim.AnimationType -ne $type)) {
            $allSuccess = $false
            $failedType = $type
            break
        }
    }
              
    Invoke-Command -ScriptBlock $global:WriteTestResult -ArgumentList "Animation type settings", $allSuccess, "Failed to set animation type: $failedType"
}
catch {
    Invoke-Command -ScriptBlock $global:WriteTestResult -ArgumentList "Animation type settings", $false, "Exception: $_"
}

# Test 6: Validation of animation parameters
try {
    $validationTests = @(
        @{ Test = "Invalid duration low"; Success = $false; Params = @{ AnimationDuration = -100 } },
        @{ Test = "Invalid duration high"; Success = $false; Params = @{ AnimationDuration = 3000 } },
        @{ Test = "Invalid frame rate low"; Success = $false; Params = @{ AnimationFrameRate = 5 } },
        @{ Test = "Invalid frame rate high"; Success = $false; Params = @{ AnimationFrameRate = 150 } },
        @{ Test = "Invalid anim type"; Success = $false; Params = @{ AnimationType = "InvalidType" } }
    )
    
    $allSuccess = $true
    $failedTest = ""
    
    foreach ($test in $validationTests) {
        $cmdName = "anim-test-validation"
        $exception = $null
        
        try {
            $splat = $test.Params
            $splat["TargetCommand"] = $cmdName
            $splat["RibbonHeight"] = 150
            
            New-ResizeShim @splat
            # If we get here without an exception, the test failed
            if ($test.Success -eq $false) {
                $allSuccess = $false
                $failedTest = $test.Test
                break
            }
        }
        catch {
            # If we catch an exception, that's expected for invalid tests
            if ($test.Success -eq $true) {
                $allSuccess = $false
                $failedTest = $test.Test
                break
            }
        }
    }
              
    Invoke-Command -ScriptBlock $global:WriteTestResult -ArgumentList "Parameter validation", $allSuccess, "Failed validation test: $failedTest"
}
catch {
    Invoke-Command -ScriptBlock $global:WriteTestResult -ArgumentList "Parameter validation", $false, "Exception: $_"
}

# Clean up all test shims
$testShims = Get-ResizeShim | Where-Object { $_.Command -like "anim-test-*" }
if ($testShims) {
    Remove-ResizeShim -CommandNames $testShims.Command -ErrorAction SilentlyContinue | Out-Null
}