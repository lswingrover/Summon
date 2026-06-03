# summon-search

Search snippets by keyword.

## Trigger phrases
"find a snippet", "search snippets", "do I have a snippet for", "what's my trigger for", "summon search"

## Instructions

1. Fetch all snippets:
   ```bash
   curl -s http://localhost:14732/snippets
   ```

2. Filter client-side: match the user's keyword against `trigger`, `expansion`, and `label` (case-insensitive).

3. Present matches in a table. If no matches: "No snippets match '\(keyword)'. Say 'add a snippet' to create one."

4. If API unreachable: "Summon doesn't appear to be running. Launch /Applications/Summon.app."
