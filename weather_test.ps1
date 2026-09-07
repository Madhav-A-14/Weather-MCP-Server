

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

    MCPContractValidator() {
        $this.CliArgBase = @("@modelcontextprotocol/inspector","--cli","uv","run",
                            "weather_server.py","--method","tools/call")
    }

    # CallTool: sends a request to one MCP tool (e.g. get_weather) and
    # returns the parsed JSON response as a PowerShell object.
    [pscustomobject] CallTool([string]$toolName,[string]$toolArg){


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









}