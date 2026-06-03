# summon-add

Add a new snippet to Summon.

## Trigger phrases
"add a snippet", "create a snippet", "new snippet", "summon add", "add trigger", "teach summon"

## Instructions

1. Gather from the user (or infer from their message):
   - `trigger` — the short text (e.g. `;addr`). Suggest a `;`-prefixed version if not provided.
   - `expansion` — the full text to insert.
   - `label` — optional description.

2. Confirm with the user before adding:
   > Trigger: `;addr`
   > Expansion: 123 Main Street, Post Falls, ID 83854
   > Add this snippet?

3. On confirmation, POST to the API:
   ```bash
   curl -s -X POST http://localhost:14732/snippets \
     -H 'Content-Type: application/json' \
     -d '{"trigger":";addr","expansion":"123 Main Street, Post Falls, ID 83854","label":"Home address"}'
   ```

4. Confirm success: "Done — type `;addr` anywhere and Summon will expand it."

5. If API unreachable: "Summon doesn't appear to be running. Launch /Applications/Summon.app first."
