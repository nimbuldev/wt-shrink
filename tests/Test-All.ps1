# Master test runner for ResizeTerminal module tests
param(
    [switch]$Verbose,
    [switch]$StopOnFailure
)

# Test tracking variables - making these global so they can be accessed from script blocks
$Global:TestsPassed = 0
$Global:TestsFailed = 0

function Write-TestHeader {
    param([string]$Title)
    Write-Host "`n=== $Title ===`n"
}

function Write-TestResult {
    param(
        [string]$Name,
        [bool]$Success,
        [string]$Message = ""
    )
    
    if ($Success) {
        Write-Host "PASS: $Name"
        $Global:TestsPassed++
    }
    else {
        Write-Host "FAIL: $Name - $Message"
        $Global:TestsFailed++
        
        if ($StopOnFailure) {
            throw "Test failed: $Name - $Message"
        }
    }
}

function Invoke-TestFile {
    param([string]$FilePath)
    
    $fileName = Split-Path -Leaf $FilePath
    Write-TestHeader "Running $fileName"
    
    try {
        # Define functions in the global scope that test files will use
        $Global:WriteTestResult = {
            param(
                [string]$Name,
                [bool]$Success,
                [string]$Message = ""
            )
            
            if ($Success) {
                Write-Host "PASS: $Name"
                $Global:TestsPassed++
            }
            else {
                Write-Host "FAIL: $Name - $Message"
                $Global:TestsFailed++
                
                if ($StopOnFailure) {
                    throw "Test failed: $Name - $Message"
                }
            }
        }
        
        $Global:WriteTestHeader = {
            param([string]$Title)
            Write-Host "`n=== $Title ===`n"
        }
        
        # Execute the test file
        $params = @{
            Verbose = $Verbose
        }
        
        & $FilePath @params
    }
    catch {
        Write-Host "ERROR executing $fileName`: $_"
        $Global:TestsFailed++
    }
}

# Verify module exists before trying to import it
$moduleFile = "$PSScriptRoot\..\ResizeTerminal.psm1"
$manifestFile = "$PSScriptRoot\..\ResizeTerminal.psd1"

if (-not (Test-Path $moduleFile)) {
    Write-Host "ERROR: Module file not found at $moduleFile"
    exit 1
}

if (-not (Test-Path $manifestFile)) {
    Write-Host "ERROR: Module manifest not found at $manifestFile"
    exit 1
}

# Start with a clean session
Remove-Module ResizeTerminal -ErrorAction SilentlyContinue
try {
    Import-Module $manifestFile -Force -ErrorAction Stop
}
catch {
    Write-Host "ERROR importing module: $_"
    exit 1
}

# Get the path to all test files
$testPath = $PSScriptRoot

# Run cleanup test first to ensure we start with a clean slate
$cleanupTest = Join-Path -Path $testPath -ChildPath "Test-ModuleCleanup.ps1"
if (Test-Path $cleanupTest) {
    Invoke-TestFile -FilePath $cleanupTest
    
    # Reimport the module after cleanup
    Remove-Module ResizeTerminal -ErrorAction SilentlyContinue
    Import-Module $manifestFile -Force -ErrorAction Stop
}

# Get all other test files (excluding this one and Test-ModuleCleanup.ps1)
$testFiles = Get-ChildItem -Path $testPath -Filter "Test-*.ps1" | 
Where-Object { $_.Name -ne "Test-All.ps1" -and $_.Name -ne "Test-ModuleCleanup.ps1" } |
Sort-Object Name

if ($testFiles.Count -eq 0) {
    Write-Host "No test files found in $testPath"
    exit 1
}

# Execute all test files
foreach ($file in $testFiles) {
    Invoke-TestFile -FilePath $file.FullName
}

# Display summary
Write-Host "`n=== Test Summary ===`n"
Write-Host "Tests passed: $Global:TestsPassed"
Write-Host "Tests failed: $Global:TestsFailed"

# Clean up global variables
Remove-Variable -Name WriteTestResult, WriteTestHeader, TestsPassed, TestsFailed -Scope Global -ErrorAction SilentlyContinue

# Set exit code based on test results
exit $(if ($Global:TestsFailed -gt 0) { 1 } else { 0 })