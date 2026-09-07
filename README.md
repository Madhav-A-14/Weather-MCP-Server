# WeatherMCP Server

- A Python-based MCP ([Model Context Protocol](https://github.com/Anshul619/AI-ML-design-services/blob/main/MCP/Readme.md)) server that integrates with an MCP Client (GitHub Copilot or Claude Desktop) as a tool for fetching weather data.
- Built with Python, it runs as a local standard I/O server that can be configured in various MCP clients like VS Code's `mcp.json` or `.mcp.json` for Claude Desktop.
- [Read more](https://modelcontextprotocol.io/docs/develop/build-server)

> **Note:** This repo is cloned from [Anshul619/weather-mcp-server](https://github.com/Anshul619/weather-mcp-server). The base server code is not original — the additions in this repo are the MCP Inspector validation and the Pester test suite described below.

# High level design

![](assets/Weather-MCP-Server.drawio.png)

# Demo in action (with Claude Desktop)

![](assets/claude-demo.png)

# Sample prompts

````shell
get_weather {"city": "London"} # Retrieves current weather conditions.

get_forecast {"city": "London"} # Provides a short-term weather forecast.

get_alerts {"state": "CA"} # Fetches alerts for a specific region (e.g., US state).

Ask the WeatherMCP server for the weather in London.
````

# Setting Up the Weather MCP Server

## Clone the Repository

````powershell
git clone https://github.com/<your-username>/weather-mcp-server-test
cd weather-mcp-server-test
````

## Set up the environment (uv)

This repo uses [`uv`](https://docs.astral.sh/uv/) for dependency and environment management instead of plain `venv`/`pip`.

````powershell
uv sync
````

## Run the Server

````powershell
uv run python weather_server.py
````

# Configure for Claude Desktop (optional)
- Add the following JSON to your `claude_desktop_config.json` file.
- [Read more](https://modelcontextprotocol.io/docs/develop/build-server)

````json
{
  "mcpServers": {
    "WeatherMCP": {
      "type": "stdio",
      "command": "uv",
      "args": [
        "run",
        "python",
        "C:\\Users\\madhav.a\\Desktop\\weather-mcp-server-test\\weather_server.py"
      ]
    }
  }
}
````

# Configure for Copilot (through Visual Studio Code)
- If you're using VS Code with [GitHub Copilot](https://github.com/features/copilot), add the following configuration to your `~/.vscode/mcp.json` file and restart VS Code.
- [Read more](https://code.visualstudio.com/docs/copilot/customization/mcp-servers)

````json
{
  "servers": {
    "WeatherMCP": {
      "type": "stdio",
      "command": "uv",
      "args": [
        "run",
        "python",
        "C:\\Users\\madhav.a\\Desktop\\weather-mcp-server-test\\weather_server.py"
      ]
    }
  }
}
````

## Verify Copilot sees your MCP server
- Open VS Code Command Palette (Cmd+Shift+P on Mac, Ctrl+Shift+P on Windows).
- Search for `Copilot: List MCP Servers` (this command was added when MCP support shipped).
- You should see WeatherMCP in the list.

If it's missing:
- Check that your `~/.vscode/mcp.json` path is correct.
- Check the log: **View** → **Output** → **Copilot (dropdown)** for MCP errors.

## Debugging tips
- If Copilot doesn't show your server: check `~/.vscode/mcp.json` syntax (must be valid JSON).
- If the server crashes: run `uv run python weather_server.py` manually in a terminal to see errors.
- You can also add debug `print()` calls in `handle_tool_call` to see incoming requests.

---

# Testing

All testing was done from the project root:

````powershell
cd "C:\Users\madhav.a\Desktop\weather-mcp-server-test"
````

## 1. MCP Inspector

Verified all three tools (`get_weather`, `get_forecast`, `get_alerts`) using MCP Inspector, in both interactive and scripted modes.

**Web UI mode:**
````powershell
npx @modelcontextprotocol/inspector uv run python weather_server.py
````

**CLI mode:**
````powershell
# List available tools
npx @modelcontextprotocol/inspector --cli uv run python weather_server.py --method tools/list

# Call a tool
npx @modelcontextprotocol/inspector --cli uv run python weather_server.py --method tools/call --tool-name get_weather --tool-arg city=Mumbai
````

## 2. Pester Contract Tests — `weather_Contract_Tests.ps1`

Weather data (temperature, forecasts, alerts) changes constantly, so testing against specific values is unreliable. Instead, this suite validates that the **JSON response structure** stays stable — checking that expected keys (`content`, `structuredContent`, `isError`, and nested `type`/`text` fields) are present, independent of what the actual data values are.

The suite uses a `MCPContractValidator` class as a wrapper around the MCP server — it calls the server the same way MCP Inspector does (over the protocol, via CLI), keeping the validation logic fully independent of the server's internal implementation.

````powershell
Invoke-Pester -Path .\weather_Contract_Tests.ps1
````

---

# Credits

Base MCP server implementation: [Anshul619/weather-mcp-server](https://github.com/Anshul619/weather-mcp-server)