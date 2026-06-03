# summon-list

List all snippets in the Summon text expander.

## Trigger phrases
"list my snippets", "show my snippets", "what snippets do I have", "summon list", "show all triggers"

## Instructions

1. Call the Summon companion API:
   ```
   GET http://localhost:14732/snippets
   ```
   via `mcp__workspace__bash`: `curl -s http://localhost:14732/snippets`

2. If the API is unreachable, tell the user: "Summon doesn't appear to be running. Launch it from /Applications/Summon.app."

3. Parse the JSON array. Each item has: `id`, `trigger`, `expansion`, `label`, `enabled`.

4. Present as a clean table:

   | Trigger | Label | Enabled |
   |---------|-------|---------|
   | ;addr   | Home address | ✅ |
   | ;sig    | Email signature | ✅ |

5. Show total count. If none: "No snippets yet — say 'add a snippet' to create one."
