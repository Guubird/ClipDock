# ClipDock Development Log

## Project Name

ClipDock

## Product Concept

ClipDock is a lightweight macOS quick-access panel for saving links, text snippets, and prompt snippets.

It is meant to help users quickly save useful resources from different apps and reopen or copy them later.

ClipDock should behave like an intentional personal resource dock, not an automatic browsing history tracker.

## Core Product Principle

ClipDock should not silently record browsing history or app activity.

ClipDock should only save content that the user intentionally chooses to save.

Future clipboard detection should require user confirmation before saving anything.

Example future flow:

1. User copies a link.
2. User summons ClipDock.
3. ClipDock detects that the clipboard contains a URL.
4. ClipDock asks: "Save this link?"
5. User confirms by clicking Save.
6. Only then is the link added to ClipDock.

## Current Technology Stack

- macOS app
- Swift
- SwiftUI
- Xcode
- Codex CLI assisted development

## Current Implementation Status

The first MVP UI was implemented in `ClipDock/ContentView.swift`.

The UI uses sample data on first launch when no saved items exist yet.

The app currently shows:

- App title
- Subtitle
- Manual Add Item form
- Lightweight Quick Add floating window
- Search field
- Active / Trash view toggle
- Type filter
- Sort control
- Sample saved items
- Type badges for Link, Text, Prompt, and Command
- Tags
- Pinned indicators
- Active item actions: Open, Copy, and Delete
- Trash item actions: Restore and Delete Forever
- Subtle local usage count labels

Search filters items by title, content, or tag.

The type filter supports All, Link, Text, Prompt, and Command.

The sort control supports Newest, Oldest, and Most Used.

Copy uses `NSPasteboard`.

Open uses `NSWorkspace` for valid URLs.

Items are persisted locally with `UserDefaults`.

Copy and valid Link Open actions increment local `usageCount`.

Delete now performs a soft delete by moving items to local Trash.

Trash items are retained locally for 10 days and can be restored or permanently deleted.

The Quick Add floating window supports quick saving only.

The Quick Add window now starts as a compact floating widget and expands into a small form only when needed.

ClipDock includes a lightweight menu bar item for showing the main window, showing or hiding Quick Add, and quitting the app.

## Development Entries

### p2: Manual Add Item Form

A simple manual Add Item form was added to `ClipDock/ContentView.swift`.

The form supports:

- Title
- Content or URL
- Comma-separated tags
- Item type selection for Link, Text, and Prompt
- Add Item button

At p2, new items were added to the current in-memory item list and could be searched, copied, and opened when their content was a valid URL.

### p3: UserDefaults Persistence

UserDefaults persistence was added to `ClipDock/ContentView.swift`.

Items are encoded and decoded with `JSONEncoder` and `JSONDecoder` using the `clipDockItems` key.

On first launch, or when no saved items exist yet, ClipDock shows the existing sample items. After the user adds a new item, the updated item list is saved to `UserDefaults`.

Newly added items should remain after app restart. This is still local-only storage, not a database or sync system.

### p4: Lightweight Organization Features

Lightweight organization features were added to `ClipDock/ContentView.swift`.

Command was added as a fourth item type alongside Link, Text, and Prompt.

Users can filter by All, Link, Text, Prompt, and Command.

Users can sort by Newest, Oldest, and Most Used.

Copy and valid Link Open now increment a local `usageCount`, which is saved with the item list.

At p4, users could delete items permanently from the in-memory list and the updated list was saved to `UserDefaults`. This behavior was replaced by the p5 Trash system.

All p4 changes persist locally with `UserDefaults`. ClipDock still uses local-only storage and does not use a database or sync system.

The app is intentionally kept lightweight with no timers, polling, background monitoring, or automatic activity capture.

### p5: Trash and Restore

A lightweight local Trash and Restore system was added to `ClipDock/ContentView.swift`.

Delete now performs a soft delete instead of immediately removing an item. Deleted items move to Trash with `isDeleted = true` and a `deletedAt` timestamp.

Trash items are retained locally for 10 days. Users can restore items within that retention window, which moves them back to the Active view.

Users can also Delete Forever from Trash, which permanently removes the item from the local item list.

Expired Trash items older than 10 days are cleaned up during normal app load/update flow. No timers, polling, background observers, scheduled jobs, sync, or database were added.

This remains local-only `UserDefaults` storage.

### p6: Quick Add Floating Window

A lightweight floating Quick Add window was added.

The floating window is for quick saving only. It supports:

- Title
- Content or URL
- Type selection for Link, Text, Prompt, and Command
- Comma-separated tags
- Add Item button

Quick Add reuses the same local `UserDefaults` persistence through a shared `ClipDockStore`, so items saved from the floating window appear in the main ClipDock management window.

The floating window does not support Open, Copy, search, type filtering, sorting, Trash management, clipboard monitoring, global shortcuts, or automatic import from Safari, Chrome, WeChat, or other apps.

Closing the main window does not terminate the app immediately. The Quick Add window can be reopened from the app's standard ClipDock command menu.

The app remains intentionally local-only and lightweight. No database, sync, background monitoring, timers, polling, scheduled jobs, clipboard monitoring, or global shortcuts were added.

### p6.1: Quick Add Widget Refinement

The Quick Add floating window was refined to behave more like a compact floating widget.

It now launches in a small collapsed mode with a `+ Add` button. Clicking the widget expands it into a compact Quick Add form with no large unused area.

The collapsed widget spacing was refined so the `+ Add` button has more comfortable padding, especially below the button, while remaining small and quick-save only.

The expanded form remains quick-save only and includes Title, Content or URL, Type, Tags, Add Item, and Collapse controls. After a successful add, the form clears and collapses back to the compact widget.

The floating window still does not include Open, Copy, search, Trash management, clipboard monitoring, global shortcuts, or menu bar behavior.

### p7: Menu Bar App Behavior

A lightweight macOS menu bar item was added for ClipDock.

The menu includes:

- Show Main Window
- Show Quick Add
- Hide Quick Add
- Quit ClipDock

The menu bar item improves access when the main management window or Quick Add widget is closed or hidden.

Show Main Window opens or brings forward the single main ClipDock management window. Show Quick Add opens or brings forward the compact Quick Add widget. Hide Quick Add hides the Quick Add widget while keeping the app running. Quit ClipDock terminates the app cleanly.

No global shortcuts, clipboard monitoring, automatic app import, sync, database, timers, polling, background observers, or scheduled jobs were added.

## Files Changed So Far

- `ClipDock/ContentView.swift`
- `ClipDock/ClipDockApp.swift`
- `DEVELOPMENT_LOG.md`

## Features Intentionally Not Implemented Yet

- No database
- No sync
- No editable items yet
- No pin/unpin behavior yet
- No collections or folders yet
- No global keyboard shortcut yet
- No clipboard monitoring yet
- No automatic import from Safari, Chrome, WeChat, or other apps

## Known Verification Notes

- The app was manually run in Xcode on My Mac.
- The ClipDock UI appeared successfully.
- Codex attempted to run `xcodebuild` from CLI.
- CLI build verification encountered sandbox-related SwiftUI Preview macro issues.
- Final verification should currently be done by running the app in Xcode.

## How To Run Manually

1. Open `ClipDock.xcodeproj` in Xcode.
2. Select the `ClipDock` scheme.
3. Select My Mac as the destination.
4. Press Run.

## Suggested Next Development Steps

1. Add editing for existing items.
2. Add pin/unpin behavior.
3. Add clipboard URL detection with explicit user confirmation.
4. Consider global keyboard shortcut summon behavior.
5. Polish UI style and visual identity.
