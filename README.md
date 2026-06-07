# promptlet

Windows Terminal prompt snippets powered by AutoHotkey v2.

## Requirements

- Windows
- Windows Terminal
- AutoHotkey v2

## Usage

1. Install AutoHotkey v2 from <https://www.autohotkey.com/>.
2. Run `main.ahk`.
3. Focus a Windows Terminal window.
4. Type a template hotstring to insert a prompt prefix.
5. Type `;;` to open the prompt menu.
6. Type `;c` at the end of the current input line to clear it.
7. Type `;n` to insert a multiline newline.

The shortcuts only work when the active window is Windows Terminal.

## Templates

Templates are stored in `templates.ini`, next to `main.ahk`.

On startup, `main.ahk` reads `templates.ini`, registers template hotstrings, and builds the prompt menu. If a built-in template is missing, the script adds it back without overwriting existing template entries.

Each template has:

- `label`: menu label
- `trigger`: hotstring trigger
- `text`: text inserted into the terminal
- `kind`: insertion behavior
- `builtin`: `1` for built-in templates, `0` for custom templates
- `uses`: usage count
- `order`: tie-break order when usage counts are equal

Built-in templates:

| Hotstring | Inserts |
| --- | --- |
| `;a` | `add: ` |
| `;x` | `fix: ` |
| `;u` | `update: ` |
| `;q` | `ask: ?` with the cursor before `?` |
| `;rv` | `review code: ` |
| `;ex` | `explain: ` |
| `;doc` | `write docs: ` |
| `;wt` | `write tests: ` |
| `;safe` | `minimal changes, no refactor: ` |

## Control Hotstrings

Control hotstrings are handled by `main.ahk`. They are not stored as templates and do not participate in usage sorting.

| Hotstring | Action |
| --- | --- |
| `;;` | Opens a menu with all templates at the start of the current input line |
| `;c` | Clears the current input line by sending `Ctrl+U` |
| `;n` | Inserts a multiline newline by sending `Shift+Enter` |
| `;h` | Shows control hotstring help |

## Prompt Menu

Type `;;` at the start of the current input line in Windows Terminal to open the prompt menu.

The menu opens near the text cursor when Windows exposes caret coordinates. If caret coordinates are unavailable, it falls back to the active terminal window instead of the mouse pointer.

The menu shows every template and sorts by:

1. Higher `uses`
2. Lower `order`

Both hotstring use and menu selection increment `uses`, so custom templates can move up in the menu if they are used often enough.

Each menu item shows the template label and its hotstring trigger.

Selecting an item inserts text only. It does not press Enter or submit the prompt.

To keep `;;` line-start-only, the script tracks only a current-line character count while Windows Terminal is active. It does not store the typed text.

## Adding Templates

To add a template, edit `templates.ini` directly, then reload `main.ahk`.

Example:

```ini
[template.debug]
label="debug:"
trigger=";debug"
text="debug: "
kind="text"
builtin=0
uses=0
order=1000
```

For templates that should leave the cursor before the final character, use `kind=cursor_before_last_char`:

```ini
[template.ask_alt]
label="ask: ?"
trigger=";2q"
text="ask: ?"
kind="cursor_before_last_char"
builtin=0
uses=0
order=1010
```

That inserts `ask: ?` and leaves the cursor before the question mark.

## Notes

- The script uses `#SingleInstance Force`, so launching it again replaces the previous instance.
- The script uses `SendText` through `InsertPrompt(text)` for literal text insertion.
- It does not implement ghost text and does not read Codex internals.
