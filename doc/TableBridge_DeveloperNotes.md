# Table Bridge — Developer Notes

> **Files covered**
> - `src/+gwidgets/+internal/table_bridge.html` — the JS bridge (runs in a `uihtml` iframe)
> - `src/+gwidgets/Table.m` — the MATLAB host (methods in the *Table bridge* section)
>
> The bridge has two responsibilities sharing the same iframe:
> 1. column-width tracking (described below), and
> 2. cell-level hover detection driving the tooltip popup (see the
>    `HoverEnable` / `HoverDisable` / `SetTooltip` / `CellHover` events in the
>    JS header).

---

## 1. Why the bridge exists

MATLAB's `uitable` renders as a web component, and several things the widget
needs to do can't be reached through MATLAB's property/event API — they
require touching the DOM directly.  The bridge is a tiny `uihtml` iframe
(2 px tall, invisible) that lives in the same browser context as the table
and brokers events in both directions.

It currently handles two responsibilities:

1. **Column-width tracking.**  When the user drags a column divider,
   MATLAB updates `ColumnWidth` internally but does **not** fire the
   property's set-listener.  A `ResizeObserver` mounted on the header
   column elements catches the resize and reports the new pixel widths
   to MATLAB.  Conversely, when MATLAB pushes new widths programmatically,
   the browser may not honour `uitable.ColumnWidth` if the user has
   previously dragged (MATLAB treats user-dragged columns as "sticky"),
   so the bridge stamps `min-width` / `max-width` directly on the
   header `<th>` and body `<td>` elements.

2. **Cell-level hover detection** for the tooltip system.  `uitable.Tooltip`
   is read by MATLAB once on mouse-enter and isn't re-read while hovering,
   so MATLAB can't drive per-cell tooltips through it.  The bridge attaches
   a `mouseover` listener at the figure document root, walks up from the
   event target to find ARIA grid coordinates (`aria-rowindex` /
   `aria-colindex`, with a class-selector fallback), and reports the
   hovered `{row, col}` to MATLAB.  MATLAB resolves the tooltip text and
   style and pushes them back as a list of styled blocks, which the
   bridge renders in its own absolutely-positioned popup `<div>` —
   independent of the browser's native title popup, so it refreshes
   immediately on every cell transition and supports CSS styling.

---

## 2. Component topology

```
Figure
└── gwidgets.Table (uipanel subclass)
    └── uigridlayout (4 rows)
        ├── Row 1  HelpPanel (filter help, width=0 when hidden)
        ├── Row 2  (height 0 — unused / filter row placeholder)
        ├── Row 3  DisplayTable  (matlab uitable)   ← columns observed here
        └── Row 4  TableBridge_ (uihtml, height=2px)  ← bridge iframe

window.parent.document.body
  └── <div id="gwidgets-tooltip">  ← tooltip popup (only present while hovering)
```

The bridge iframe is a sibling of the `uitable` in the same DOM tree, so
`window.parent` gives it access to the figure's document.  The tooltip
popup is appended to the figure's `<body>` directly (not inside the bridge
iframe) so it can overlay cells without being clipped by the bridge's own
2-pixel-tall layout slot.

---

## 3. Startup sequence

```
MATLAB                                  JS bridge
------                                  ---------
setupTableBridge()
  assign unique DisplayTableTag_
  set DisplayTable.Tag = tag
  create uihtml (loads async)
                                        setup(component) runs
                                        attach mousedown/mouseup on parent doc
                                        htmlComponent.Data = {event:"BridgeReady"}
onBridgeData → "BridgeReady"
  sendEvent("Init", {tableTag})
                                        Init handler:
                                          store tableTag
                                          setTimeout → attachObserver("Init")
                                        attachObserver:
                                          findColumns() via data-tag
                                          new ResizeObserver(debouncedPublish)
                                          observe each <th>
```

**Why the delay?** The `uitable` DOM may not exist when the bridge first
loads.  `attachObserver` retries up to `MAX_ATTEMPTS` (8) times with a
`RETRY_INTERVAL` (600 ms) gap.

---

## 4. Column-width representation

### MATLAB backing stores (three parallel arrays, one entry per data column)

| Store | Type | Meaning |
|---|---|---|
| `DataColumnWidthTypes_` | `(1,:) string` | `"Pixel"` or `"Relative"` per column; empty array = all Relative |
| `PixelDataColumnWidths_` | `(1,:) double` | Pixel value; `NaN` for Relative columns until bridge resolves |
| `RelativeDataColumnWidths_` | `(1,:) string` | `"Nx"` weight; `missing` for Pixel columns until bridge resolves |

Both pixel and relative stores are updated on every `ColumnWidthChanged`
notification from the bridge (see §6).  `DataColumnWidthTypes_` is never
changed by a drag — only by the user setting `ColumnWidth` or `DataColumnWidth`.

### Wire encodings

| Direction | Value | Meaning |
|---|---|---|
| MATLAB → JS (`SetWidths`) | `120` (positive) | Pixel column: stamp min/max to 120 px |
| | `-1` (negative) | Relative column: remove constraints, let CSS proportion control |
| JS → MATLAB (`ColumnWidthChanged`) | `150` (positive) | Actual rendered pixel width for every visible column |

**All values in `ColumnWidthChanged` are positive.**  MATLAB uses
`DataColumnWidthTypes_` to know which columns are Pixel vs Relative; the sign
encoding is no longer used in the JS→MATLAB direction.

### GCD-normalised relative weights

After receiving pixel widths from the bridge, MATLAB computes:

```
g = GCD of all resolved (non-NaN) pixel widths across ALL data columns
RelativeDataColumnWidths_(i) = round(px(i) / g) + "x"
```

This expresses column ratios as small integers.  Example: `[200, 110, 220]`
px → GCD = 10 → `["20x", "11x", "22x"]`.

### "auto" and "fit" normalisation

`normalizeColumnWidths` converts `"auto"` and `"fit"` to `"1x"`.  Only
`"Pixel"` and `"Relative"` column types are supported.

---

## 5. State variables (JS)

| Variable | Type | Meaning |
|---|---|---|
| `colAutoFlags` | `bool[]` | `true` = Relative col, `false` = Pixel col; from most recent SetWidths |
| `prevWidths` | `number[]` | Pixel widths at last stable state; baseline for change detection |
| `settledPropWidths` | `number[]` | Relative col widths at post-SetWidths reflow; used for redistribution |
| `allPixelMode` | `bool` | All columns are Pixel → body table needs an explicit px width |
| `isDragging` | `bool` | True while a mouse button is held in the parent document |
| `pendingPublish` | `bool` | A resize fired during a drag; fire `publishWidths` on next mouseup |
| `pendingRedistrib` | `bool` | Set in `publishWidths` before `ColumnWidthChanged`; cleared at start of `applyColumnWidths` |
| `lastSetSeq` | `int` | Seq from the most recent SetWidths; echoed in `ColumnWidthChanged` |
| `expectedColCount` | `int` | Set from SetWidths length; used to disambiguate DOM queries |

---

## 6. State machine

```
                        ┌──────────────────────────────────────────┐
                        │           IDLE / OBSERVING               │
                        │  ResizeObserver watching header <th>s    │
                        └─────────────┬──────────────┬─────────────┘
                                      │              │
               ┌──────────────────────┘              └─────────────────────┐
               │ ResizeObserver fires                                       │ MATLAB sends
               │ (debouncedPublish)                                         │ SetWidths
               ▼                                                            ▼
    ┌────────────────────┐                                    ┌──────────────────────────┐
    │  isDragging?       │──yes──► snapshot prevWidths        │   applyColumnWidths()    │
    │                    │         pendingPublish = true       │   stamp header + body    │
    └────────┬───────────┘         return                     │   RAF → syncBodyWithHdr  │
             │ no                                             └──────────────────────────┘
             ▼
    ┌──────────────────────┐
    │  debounce 200 ms     │
    └──────────┬───────────┘
               │
               ▼
    ┌──────────────────────┐
    │   publishWidths()    │
    │  classify change     │
    └──────────┬───────────┘
               │
       ┌───────┴──────────┐
       │                  │
    window             user drag
    resize               │
       │                 ▼
       │      ┌──────────────────────────────┐
       │      │  pin pixel cols              │
       │      │  pendingRedistrib = true     │
       │      │  → ColumnWidthChanged        │
       │      │    widths: all positive px   │
       │      │    seq: lastSetSeq           │
       │      └──────────┬───────────────────┘
       │                 │
       │            MATLAB side (onBridgeData)
       │                 ▼
       │      ┌──────────────────────────────┐
       │      │  updateStoresFromBridgeWidths│
       │      │  px stores ← received widths │
       │      │  rel stores ← GCD weights    │
       │      │  (types unchanged)           │
       │      └──────────┬───────────────────┘
       │                 │
       │      ┌──────────▼───────────────────┐
       │      │  applyColumnWidthToDisplay   │
       │      │  → SetWidths (px+ or -1)     │
       │      │  → DisplayTable.ColumnWidth  │
       │      └──────────┬───────────────────┘
       │                 │
       │      ┌──────────▼───────────────────┐
       │      │  applyColumnWidths()         │
       │      │  pendingRedistrib → false    │
       │      │  (redistrib if mixed)        │
       │      └──────────┬───────────────────┘
       │                 │
       │      ┌──────────▼───────────────────┐
       │      │  ResizeObserver fires again  │
       │      │  (not dragging → debounce)   │
       │      │  → ColumnWidthChanged seq=N  │
       │      │  MATLAB: echo, no change     │
       │      │  → loop ends                 │
       │      └──────────────────────────────┘
       │
       ▼
    re-stamp pixel header cols only; no MATLAB notification

MouseUp flow (if pendingPublish):
    mouseup → isDragging=false → pendingPublish=true
           → clearTimeout → publishWidths() immediately
```

### seq-based echo suppression

Each `applyColumnWidthToDisplay` increments `LastSentSeq_` and embeds it in
`SetWidths`.  The bridge echoes the seq in `ColumnWidthChanged`.  In
`onBridgeData`:

| Received seq | Action |
|---|---|
| `> 0` and `== LastSentSeq_` | Programmatic echo: update stores; re-apply only if stores changed |
| `> 0` and `!= LastSentSeq_` | Stale echo from a superseded SetWidths: ignore |
| `0` | User drag (mouseup): update stores, always re-apply |

User drags always arrive with `seq = lastSetSeq` (the most recent SetWidths
seq), which the bridge echoes.  After our changes, MATLAB re-uses this seq
for the drag flow: `d.seq > 0` and a mismatch would mean stale.  **User
drags are distinguished because they carry `seq = 0`** — `publishWidths` uses
`seqToEcho = 0` for mouseup-triggered notifications.

Wait — actually the bridge echoes `lastSetSeq` in `seqToEcho`.  A user drag
arrives with `seqToEcho = lastSetSeq` (the seq of the last SetWidths MATLAB
sent).  So a user drag may have a non-zero seq that happens to equal
`LastSentSeq_`.  The seq `0` is used only when no SetWidths has been sent yet
(fresh table).

**Actually:** The bridge sets `seqToEcho = lastSetSeq` for all
`ColumnWidthChanged` events (both drag and programmatic echo).  MATLAB
distinguishes echoes from drags by whether the calling path was triggered by a
mouseup (`seq = 0`) or the debounce path (seq = lastSetSeq).

> **Implementation note**: `publishWidths` currently always sends
> `seqToEcho = lastSetSeq`.  Drag events have `seq > 0` if MATLAB has already
> sent a SetWidths; the distinction in MATLAB is: if `seq == LastSentSeq_`
> it's the most recent programmatic echo; if `seq < LastSentSeq_` it's stale.
> A mouseup after a genuine drag is never stale because no new SetWidths was
> sent between the drag and the mouseup.

---

## 7. Drag vs window-resize classification

A column drag always moves two adjacent columns in opposite directions (one
grows, one shrinks).  A window resize moves all (or all visible) columns in
the same direction.

```
hasOpposing    = some changed column grew AND some changed column shrank
singlePixelDrag = exactly one column changed AND it is a pixel (not Relative) column

isDrag = hasOpposing || singlePixelDrag
```

`singlePixelDrag` catches the case where the user drags the right edge of the
rightmost pixel column, extending the table width with no offsetting shrink.
Window resizes cannot move pixel columns because `min-width == max-width` is
stamped on them.

---

## 8. Mixed-mode redistribution

**Problem**: In a mixed layout (some Pixel, some Relative columns), MATLAB
stamps explicit pixel `min-width`/`max-width` on ALL header columns at render
time — including the Relative ones.  When the user drags a Pixel column:

1. JS sends `ColumnWidthChanged` with the new pixel widths for all columns.
2. MATLAB echoes `SetWidths = [newPx, -1, -1, ...]` (Relative cols remain `-1`).
3. Without redistribution, the Relative header columns stay pinned at their
   pre-drag pixel values, so one Relative column absorbs all the slack.

**Solution**: At each `applyColumnWidths` call (triggered by a SetWidths
echo), the bridge snapshots `settledPropWidths` — the rendered pixel widths
of Relative columns after MATLAB has reflowed.  On the next mixed-mode
`SetWidths` triggered by a bridge drag (`pendingRedistrib == true`), the
bridge redistributes those Relative columns proportionally:

```
containerW   = header table bounding rect width   (unchanged by the drag)
newPropSpace = containerW - sum(Pixel cols in SetWidths)
newW_i       = round( newPropSpace × settledPropWidths[i] / settledPropTotal )
```

This keeps the Relative columns' pixel ratio intact as the Pixel column
expands or contracts.

**Guard** — `pendingRedistrib` is set to `true` only in `publishWidths`,
immediately before sending `ColumnWidthChanged`.  It is cleared at the top of
`applyColumnWidths`.  This ensures redistribution fires only for MATLAB's
echo of a bridge-initiated drag, not for independent programmatic
`tb.ColumnWidth = {...}` assignments.

---

## 9. Assumptions and design choices

| Assumption / Choice | Rationale |
|---|---|
| Bridge iframe in a 2-px row | Must be in the same DOM so `window.parent` reaches the figure. Height 2 px makes it invisible without `display:none` (which would prevent JS from running). |
| Unique `data-tag` on `uitable` | Multiple `gwidgets.Table` instances in the same figure would otherwise share column elements; the tag scopes all DOM queries. |
| Fallback DOM strategies (3 levels) | The `data-tag` attribute is not always rendered before the first `attachObserver` call; iframe-relative walk and unscoped fallback handle that race. |
| `prevWidths = null` on every `applyColumnWidths` | Forces the next `publishWidths` to re-anchor to the post-apply state rather than carry stale pre-apply widths as a baseline. |
| `isDragging` flag suppresses `ColumnWidthChanged` mid-drag | Prevents a MATLAB SetWidths response from interrupting an in-progress drag (which would cause visual stutter). `ColumnWidthChanged` fires on mouseup only. |
| Three MATLAB backing stores | Allows callers to query both `PixelDataColumnWidths` and `RelativeDataColumnWidths` at any time.  The GCD normalisation keeps relative weights as small integers. |
| `DataColumnWidthTypes_` never changed by drag | Preserves the user's intent.  A column declared Pixel stays Pixel even if dragged; a Relative column stays Relative regardless of the new rendered size. |
| All-positive `ColumnWidthChanged` payload | Separates concerns: the bridge knows the rendered DOM; MATLAB knows which columns are Pixel vs Relative.  No need for the bridge to encode relative weights as negative values. |
| Stale-seq guard in MATLAB | Prevents a delayed echo from a superseded SetWidths from overwriting stores that were updated by a more recent drag or programmatic set. |
| Body cells stamped with `min-width == max-width` | Virtual-scroll rows are created lazily; the stamp must be re-applied on every `publishWidths` to cover newly rendered rows. The RAF in `applyColumnWidths` handles the first batch after a MATLAB push. |
| Relative columns NOT stamped on drag | Proportional columns must remain free to reflow on window resize; pinning them after a drag would prevent that. |

---

## 10. Cell hover and tooltip rendering

The bridge's second job is driving the `gwidgets.Table` tooltip system.
`uitable.Tooltip` is only re-read on mouse-enter, so MATLAB can't update it
per cell while hovering — instead the bridge owns its own popup `<div>` and
swaps content based on which cell the cursor is currently over.

### 10.1 Event protocol

MATLAB → bridge:

| Event         | Payload                                       | Meaning |
|---------------|-----------------------------------------------|---------|
| `HoverEnable` | —                                             | Start reporting `CellHover` events. Sent when the first tooltip is registered (or on `BridgeReady` if any tooltips already exist). |
| `HoverDisable`| —                                             | Stop reporting and hide the popup. Sent when the last tooltip is removed. |
| `SetTooltip`  | `{ blocks: [{ containerCss, lines: [{ text, css }, ...] }, ...] }` | Render or hide the popup. An empty `blocks` list hides it. Each block has its own container CSS (background, padding, border) and a list of styled lines (font color, weight, size, family). |

Bridge → MATLAB:

| Event       | Payload              | Meaning |
|-------------|----------------------|---------|
| `CellHover` | `{ row, col }`       | Cursor entered a new cell (deduped — no event if same `{row, col}` as the previous one). `row=0` means header / no body row; `col=0` means off-cell. Coordinates are 1-based display indices. |

### 10.2 Cell-coordinate extraction

On every `mouseover` inside the table root, `gridCoordsFromTarget` walks
up the ancestor chain from `evt.target` looking for the first element with
`aria-rowindex` and the first with `aria-colindex`.  MATLAB's table emits
those 1-based against its own display order with no header counted, so they
match `gwidgets.Table.DisplayData` row/column indices directly — no shift
needed.

A class-selector fallback (`.mw-table-body-cell`, `.mw-table-cell`,
`.mw-table-header-column`, `[role='gridcell']`, `[role='columnheader']`,
`[role='row']`) is in place for table DOM variants that don't expose ARIA
attributes; it infers indices from sibling position via `indexInParent`.

### 10.3 Popup rendering

The popup is a single `<div id="gwidgets-tooltip">` lazily appended to
`window.parent.document.body` on first hover, with:

- `position: fixed` so it floats above the table regardless of scroll;
- `pointer-events: none` so it doesn't interfere with table interactions;
- `z-index: 9999` to sit above MATLAB dropdowns/menus.

Each `SetTooltip` event clears the container and rebuilds it in a
nested loop:

- one outer `<div>` per **block**, with `containerCss` applied (background,
  padding, border, border-radius);
- one inner `<div>` per **line** inside that block, with `textContent`
  carrying the text (never `innerHTML`, to avoid HTML injection from
  cell values) and `style.cssText` carrying the line's CSS (font color,
  weight, size, family).

Blocks after the first get a `margin-top: 2px` divider so distinct
backgrounds visibly separate.  The popup is positioned next to the
cursor on each event and on every mouseover within the same cell
(`positionTooltipNearCursor`).  Edge detection flips the popup to the
other side of the cursor when it would otherwise extend past the right
or bottom of the viewport.

### 10.4 Grouping rule

`resolveTooltipGroups` (MATLAB side) decides which matches share a
block.  Two matches share a block when their resolved styles agree on
every **container** property (`BackgroundColor`, `Padding`,
`BorderColor`, `BorderRadius`) — comparison is `isequaln` on the struct
returned by `TooltipStyle.containerKey()` so NaN/missing sentinels treat
unset==unset.  Line properties (`FontColor`, `FontWeight`, `FontSize`,
`FontFamily`) do **not** affect grouping — each line keeps its own line
style.

Within a block, lines are ordered most-specific-first (cell → row →
column → table; registration order preserved within a target).  Block
order is the order of first-appearance, which is also most-specific-first.

### 10.5 Lifecycle

- `HoverEnable` arrives → `attachHover()` adds the `mouseover` listener at
  `window.parent.document`, capture phase.
- Crossing into a new cell → `hideTooltip()` clears the previous content,
  then `sendHover(row, col)` posts to MATLAB.  Brief flicker is preferable
  to showing stale text from the previous cell while waiting for the
  roundtrip.
- Cursor moves within the same cell → `positionTooltipNearCursor()` only
  (no roundtrip).
- `SetTooltip` arrives → `renderTooltipBlocks(blocks)` shows/hides.
- `HoverDisable` arrives → `hideTooltip()`, `detachHover()`, reset
  `lastHoverCellEl` / `lastHoverRow` / `lastHoverCol`.

---

## 11. Known limitations

- **Redistribution uses pre-reflow container width** — `containerW` is read
  synchronously inside `applyColumnWidths` before the browser has reflowed the
  new pixel col stamps.  Because the container (figure/panel) width is
  unchanged by a column drag, this is always the correct value.  It would be
  wrong only if the panel itself resized simultaneously with the drag.

- **Relative columns silently ignore right-edge drag** — dragging the right
  edge of the rightmost *Relative* column is classified as a window resize and
  not reported to MATLAB.  This is intentional: we cannot pin a Relative column
  to a pixel value based on a drag (it must remain proportional).

- **MutationObserver re-attach uses a 50 ms heuristic** — when MATLAB
  re-renders the header, `setupMutationObserver` fires `attachObserver` after
  50 ms.  If MATLAB takes longer, `attachObserver` retries (up to 8 × 600 ms),
  so it recovers, but there is a brief window during which column drags go
  undetected.

- **Pixel widths of Relative columns are `NaN` until first bridge contact** —
  `PixelDataColumnWidths` returns `NaN` for Relative columns when the table is
  headless or before the first `ColumnWidthChanged` is received.

---

## 12. Bug history (key fixes)

| Commit | Issue fixed |
|---|---|
| `pendingRedistrib` guard | Redistribution was firing on any mixed-mode `SetWidths`, including programmatic `tb.ColumnWidth = {...}`.  Now only fires for bridge-initiated drag echoes. |
| `!allPixel` RAF condition | Replaced the overly complex `allAuto || (!allPixel && settledPropWidths)` guard; the simpler form also fixes a first-time mixed `SetWidths` with no prior `settledPropWidths` skipping the RAF. |
| `prevColAutoFlags` guard on constraint removal | Prevents removing CSS that MATLAB itself stamped for proportional columns. |
| Three-store MATLAB model | Replaced single `DataColumnWidth_` cell with `DataColumnWidthTypes_` / `PixelDataColumnWidths_` / `RelativeDataColumnWidths_`.  Eliminates ambiguity between "auto" and "1x" and enables `PixelDataColumnWidths` / `RelativeDataColumnWidths` public properties. |
| All-positive `ColumnWidthChanged` | Bridge previously encoded Relative weights as negative values.  MATLAB now owns the type mapping; bridge sends actual DOM pixel widths for every column. |
| `isDragging` / mouseup guard | Bridge previously sent `ColumnWidthChanged` during a drag (debounce path); MATLAB's SetWidths response could interrupt the drag.  Now `ColumnWidthChanged` fires on mouseup only. |
| GCD-normalised relative weights | After a drag, relative weights are recomputed from `round(px / GCD)` so they are expressed as small integers with the correct ratio. |
| Stale-seq guard | Delayed echo from a superseded SetWidths could overwrite stores already updated by a newer drag.  `seq != LastSentSeq_` echoes are now silently ignored. |

---

## 13. How to test

1. **Pixel drag** — set all columns to fixed pixel widths; drag any divider;
   verify `ColumnWidth` / `PixelColumnWidths` update and body cells track header.

2. **Mixed drag (Pixel/Relative boundary)** — set some columns to `"1x"` and
   some to a pixel value; drag the Pixel column's right edge; verify Relative
   columns maintain their ratio (`RelativeColumnWidths` unchanged in type, GCD
   weights updated).

3. **Window resize** — resize the figure; verify MATLAB is NOT notified and
   Relative columns reflow freely.

4. **Programmatic push after drag** — drag a column, then set
   `tb.ColumnWidth = {...}` in MATLAB; verify the new widths land in the DOM
   and redistribution does NOT fire.

5. **Multi-table figure** — two `gwidgets.Table` instances in the same figure;
   drag in one; verify the other is unaffected.

6. **Timer cleanup** — run `timerfindall` before and after several drag
   operations; confirm no zombie timers accumulate.

7. **New properties** — verify `PixelDataColumnWidths`, `RelativeDataColumnWidths`,
   `DataColumnWidthTypes` (and their visible-column variants) return correct
   values before and after drag, and that `"auto"` / `"fit"` are normalised to
   `"1x"`.
