

# GOAL: Check that the MCP server's JSON response has the RIGHT KEYS present.

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8    
$OutputEncoding = [System.Text.Encoding]::UTF8  


# ---------------------------------------------------------------------------
# WRAPPER CLASS: MCPContractValidator
# ---------------------------------------------------------------------------
# This class is a "middleman" that talks to weather_server.py from the OUTSIDE
# — the same way MCP Inspector does — instead of importing/touching the
# server's actual code. That's what makes it "independent": the server has
# zero idea this validator exists.
class MCPContractValidator{

    # Stores the base command pieces used to launch the Inspector CLI.
    # We reuse this every time we call a tool, so we don't repeat ourselves.
     [string[]]$CliArgBase

    # Stores the base command pieces used to launch the Inspector CLI.
    # We reuse this every time we call a tool, so we don't repeat ourselves.
    # Constructor

    MCPContractValidator() {
        $this.CliArgBase = @("@modelcontextprotocol/inspector","--cli","uv","run",
                            "weather_server.py","--method","tools/call")
    }

    # CallTool: sends a request to one MCP tool (e.g. get_weather) and
    # returns the parsed JSON response as a PowerShell object.
    [PSCustomObject] CallTool([string]$toolName,[string]$toolArg){


        # Start with the base command, then add which tool we're calling.
        $cliArgs = $this.CliArgBase + @("--tool-name", $toolName, "--format","json")

        # Some tools need an argument (like city=Mumbai), some might not.
        if ($toolArg) {
            $cliArgs += @("--tool-arg", $toolArg)
        }
        else {
            # No extra argument needed — nothing to add here.
        }

        # Actually run the command and capture whatever it prints out.
        $raw = & npx @cliArgs
        
        # Convert the raw JSON text into a PowerShell object we can inspect.
        return($raw|ConvertFrom-Json)

    }


    # CheckKeysExist: Similar to the above custom object 
    # given an object and a list of keys we EXPECT to find,
    # this checks each one and builds a small "report" — like a checklist
    # with a tick or cross next to each item, instead of just one big
    # pass/fail for everything at once.

    [PSCustomObject[]]CheckKeysExist([PSCustomObject]$obj, [string[]]$expectedKeys,  [string]$parentKey){

        # This array will holds one row per key check.
        $report = @()

        # If the object we need to inspect doesn't exists at all
        # mark every expected keys as FAIL with the reason 
        # "Parent object is null" and report it 

        if ($null -eq $obj) {
            foreach ($key in $expectedKeys){
                $report += [PSCustomObject]@{
                    ParentKey = $parentKey
                    Key = $key
                    Expected  = "Present"
                    Actual  = "Parent object is null"
                    Status = "FAIL"

                }
            }
            return $report
        }

         # Get the list of key names that actually exist on this object.
        $actualKeys = $obj.PSObject.Properties.Name

        # Go through each key we expect, one at a time, and log whether
        # it was actually found or not.

        foreach ($key in $expectedKeys) {
            $isPresent = $actualKeys -contains $key

            $report += [PSCustomObject]@{
                    ParentKey = $parentKey
                    Key = $key
                    Expected  = "Present"
                    Actual  = if ($isPresent) {"Present"} else {"Missing"}
                    Status = if ($isPresent) {"PASS"} else {"FAIL"}

                }

        }
        return $report
            
    }

    #checks if a key's actual value matches what we expect.
    # Used only for fields like "isError" where the value matters —
    [PSCustomObject]Checkis_Error([PSCustomObject]$obj, [string]$key, [bool]$expectedValue, [string]$parentKey){

        $actualValue = $obj.$key

        $report = [PSCustomObject]@{
                ParentKey = $parentKey
                Key       = $key
                Expected  = $expectedValue
                Actual    = $actualValue
                Status = if ($actualValue -eq $expectedValue) {"PASS"} else {"FAIL"}

        }
        return $report
    }
}

# ---------------------------------------------------------------------------
# SETUP: runs once before all tests below
# ---------------------------------------------------------------------------
Describe "Weather MCP -- Response Structure Contract"{

    BeforeAll{

        # Create one shared validator we can reuse across every test.
        $script:validator = [MCPContractValidator]::new()

        #defines the "contract" — the two sets of keys every response must have:

            #Top level: content, structuredContent, isError
            #Each content item: type, text
        $script:expectedTopLevelKeys = @("content","structuredContent","isError")
        $script:expectedContentItemKeys = @("type","text")

    }

# ---------------------------------------------------------------------------
# TESTS
# ---------------------------------------------------------------------------


# One Context per tool (get_weather, get_forecast, get_alerts).
# Each Context runs THREE checks, 
#   1. Do the expected top-level keys exist?
#   2. Do the expected keys exist inside content[0]?
#   3. Did the call succeed (isError is false)?


    Context "get_weather"{

        It "has required top-level keys" {

            # Call the tool and get back the parsed JSON response
            $response = $script:validator.CallTool("get_weather", "city=Mumbai")

            # Check that "content", "structuredContent", "isError" all exist on $response.result 
            $report = $script:validator.CheckKeysExist(
                $response.result,
                $script:expectedTopLevelKeys,
                "result"

            )
            # Print a readable checklist table so failures are easy to spot.
            $report | Format-Table -AutoSize | Out-String | Write-Host

             # Test fails only if at least one expected key was missing.
             $failures = $report | Where-Object {$_.Status -eq "FAIL"}
             $failures.Count | Should Be 0

        }

        It "content items have required keys" {

            $response = $script:validator.CallTool("get_weather", "city=Mumbai")


            # Same idea as the earlier one but one level deeper - checking items inside "content" has both 
            # "type" and "text" keys.
            $report = $script:validator.CheckKeysExist(
                $response.result.content[0],
                $script:expectedContentItemKeys,
                "result.content[0]"
            )
            # Print a readable checklist table so failures are easy to spot.
            $report | Format-Table -AutoSize | Out-String | Write-Host

             # Test fails only if at least one expected key was missing.
             $failures = $report | Where-Object {$_.Status -eq "FAIL"}
             $failures.Count | Should Be 0

        }

        It "isError is False(tool call succeeded)" {

            $response = $script:validator.CallTool("get_weather", "city=Mumbai")


            # "isError" is part of the response ENVELOPE (like an HTTP status code) 
            # — it tells us whether the call itself
            # succeeded or failed, so it's worth checking its actual value.
            $report = $script:validator.Checkis_Error(
                $response.result,       # -the object to look inside
                "isError",              # -the value to check
                $false,                 # -the value that is expected to hold
                "result"                # -location of key
            )
            # Print a readable checklist table so failures are easy to spot.
            $report | Format-Table -AutoSize | Out-String | Write-Host

             $report.Status | Should Be "PASS"

        }
    }

    Context "get_forecast"{

        It "has required top-level keys" {

            # Call the tool and get back the parsed JSON response
            $response = $script:validator.CallTool("get_forecast", "city=Mumbai")

            # Check that "content", "structuredContent", "isError" all exist on $response.result 
            $report = $script:validator.CheckKeysExist(
                $response.result,
                $script:expectedTopLevelKeys,
                "result"

            )
            # Print a readable checklist table so failures are easy to spot.
            $report | Format-Table -AutoSize | Out-String | Write-Host

             # Test fails only if at least one expected key was missing.
             $failures = $report | Where-Object {$_.Status -eq "FAIL"}
             $failures.Count | Should Be 0

        }

        It "content items have required keys" {

            $response = $script:validator.CallTool("get_forecast", "city=Mumbai")


            # Same idea as the earlier one but one leve deeper - checking items inside "content" has both 
            # "type" and "text" keys.
            $report = $script:validator.CheckKeysExist(
                $response.result.content[0],
                $script:expectedContentItemKeys,
                "result.content[0]"
            )
            # Print a readable checklist table so failures are easy to spot.
            $report | Format-Table -AutoSize | Out-String | Write-Host

             # Test fails only if at least one expected key was missing.
             $failures = $report | Where-Object {$_.Status -eq "FAIL"}
             $failures.Count | Should Be 0

        }

        It "isError is False(tool call succeeded)" {

            $response = $script:validator.CallTool("get_forecast", "city=Mumbai")


            # "isError" is part of the response ENVELOPE (like an HTTP status code) 
            # — it tells us whether the call itself
            # succeeded or failed, so it's worth checking its actual value.
            $report = $script:validator.Checkis_Error(
                $response.result,       # -the object to look inside
                "isError",              # -the value to check
                $false,                 # -the value that is expected to hold
                "result"                # -location of key
            )
            # Print a readable checklist table so failures are easy to spot.
            $report | Format-Table -AutoSize | Out-String | Write-Host

             $report.Status | Should Be "PASS"

        }
    }

    Context "get_alerts"{

        It "has required top-level keys" {

            # Call the tool and get back the parsed JSON response
            $response = $script:validator.CallTool("get_alerts", "state=CA")

            # Check that "content", "structuredContent", "isError" all exist on $response.result 
            $report = $script:validator.CheckKeysExist(
                $response.result,
                $script:expectedTopLevelKeys,
                "result"

            )
            # Print a readable checklist table so failures are easy to spot.
            $report | Format-Table -AutoSize | Out-String | Write-Host

             # Test fails only if at least one expected key was missing.
             $failures = $report | Where-Object {$_.Status -eq "FAIL"}
             $failures.Count | Should Be 0

        }

        It "content items have required keys" {

            $response = $script:validator.CallTool("get_alerts", "state=CA")


            # Same idea as the earlier one but one leve deeper - checking items inside "content" has both 
            # "type" and "text" keys.
            $report = $script:validator.CheckKeysExist(
               $response.result.content[0],
                $script:expectedContentItemKeys,
                "result.content[0]"
            )
            # Print a readable checklist table so failures are easy to spot.
            $report | Format-Table -AutoSize | Out-String | Write-Host

             # Test fails only if at least one expected key was missing.
             $failures = $report | Where-Object {$_.Status -eq "FAIL"}
             $failures.Count | Should Be 0

        }

        It "isError is False(tool call succeeded)" {

            $response = $script:validator.CallTool("get_alerts", "state=CA")


            # "isError" is part of the response ENVELOPE (like an HTTP status code) 
            # — it tells us whether the call itself
            # succeeded or failed, so it's worth checking its actual value.
            $report = $script:validator.Checkis_Error(
                $response.result,       # -the object to look inside
                "isError",              # -the value to check
                $false,                 # -the value that is expected to hold
                "result"                # -location of key
            )
            # Print a readable checklist table so failures are easy to spot.
            $report | Format-Table -AutoSize | Out-String | Write-Host

             $report.Status | Should Be "PASS"

        }
    }
}


