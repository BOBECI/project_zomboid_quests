Recorded dressing files go here.

Exports arrive as .txt and must be renamed to .lua before they go in here --
the game will not open a .lua file for writing, so the recorder cannot produce
one directly. The contents are already Lua.

Produced by the in-game recorder: right-click the ground ->
[KnoxStories] Debug -> Start recording dressing here, place your objects, then
Finish recording and export.

The file lands in Zomboid/Lua/ -- the Lua subfolder, not the Zomboid root, and
not next to console.txt. That is where the engine sandboxes mod file writes.
Copy it in here and rename the `id` inside it to something meaningful.

Each file contains only what was added during the recording, never the building
itself, so it stays valid across map updates.
