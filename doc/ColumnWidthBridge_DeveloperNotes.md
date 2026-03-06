# Column Width Bridge — Developer Notes

> **Files covered**
> - `src/+gwidgets/+internal/column_width_bridge.html` — the JS bridge (runs in a `uihtml` iframe)
> - `src/+gwidgets/Table.m` — the MATLAB host (methods in the *Column-width bridge* section)

---

## 1. Why the bridge exists

MATLAB's `uitable` renders as a web component.  When the user drags a column
divider, MATLAB updates `ColumnWidth` internally but does **not** fire the
property's set-listener, so MATLAB code cannot detect the drag via normal
property observation.

The bridge solves this by mounting a `ResizeObserver` on the header column
elements from a tiny `uihtml` iframe (2 px tall, invisible) that lives in the
same browser context as the table.  When columns resize the observer fires,
and the bridge decides whether the change was a user drag or a window resize,
then tells MATLAB via `htmlComponent.Data`.

A second responsibility is the reverse direction: when MATLAB pushes new
widths programmatically, the browser may not honour `uitable.ColumnWidth` if
the user has previously dragged (MATLAB treats a user-dragged column as
"sticky").  The bridge works around this by directly stamping `min-width` /
`max-width` on the header `<th>` elements and the body `<td>` cells.

---

## 2. Component topology

```
Figure
└── gwidgets.Table (uipanel subclass)
    └── uigridlayout (4 rows)
        ├── Row 1  HelpPanel (filter help, width=0 when hidden)
        ├── Row 2  (height 0 — unused / filter row placeholder)
        ├── Row 3  DisplayTable  (matlab uitable)   ← columns observed here
        └── Row 4  ColumnWidthBridge_ (uihtml, height=2px)  ← bridge iframe
```

The bridge iframe is a sibling of the `uitable` in the same DOM tree, so
`window.parent` gives it access to the figure's document.

---

## 3. Startup sequence

```
MATLAB                                  JS bridge
------                                  ---------
setupColumnWidthBridge()
  assign unique DisplayTableTag_
  set DisplayTable.Tag = tag
  create uihtml (loads async)
                                        setup(component) runs
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

| Layer | Type | Meaning |
|---|---|---|
| `DataColumnWidth_` (MATLAB cell) | `{120}` | pixel: 120 px |
| | `{"1x"}` / `{"2.5x"}` | proportional (nx) |
| | `{"auto"}` / `{"fit"}` | browser-sized |
| `jsWidths` sent via `SetWidths` | `120` (positive) | pixel |
| | `-1` (negative) | auto / proportional |
| `jsNotify` sent via `ColumnWidthChanged` | `150` (positive) | pixel |
| | `-125` (negative) | proportional: weight = 125 → "125x" |

**nx weight encoding** — The JS computes integer weights so MATLAB's
`ColumnWidth` validation (which requires positive integers for nx columns)
is satisfied:

```
weight_i = round( (pixel_i / propTotal) * propCount * 100 )
```

This gives ~2 significant figures of ratio precision.  The `×100` scale means
a single-nx-column table always gets weight 100 ("100x"), two equal columns
get [100, 100], a 3:1 pair gets [150, 50], etc.

---

## 5. State variables (JS)

| Variable | Type | Meaning |
|---|---|---|
| `colAutoFlags` | `bool[]` | `true` = auto/nx col, `false` = pixel col; from most recent SetWidths |
| `prevWidths` | `number[]` | Pixel widths at last stable state; baseline for change detection |
| `settledPropWidths` | `number[]` | Proportional col widths at Pause expiry (0 for pixel cols); used for redistribution |
| `allPixelMode` | `bool` | All columns are pixel → body table needs an explicit px width |
| `paused` | `bool` | MATLAB is pushing; suppress ColumnWidthChanged |
| `echoSuppressUntil` | `timestamp` | ResizeObserver echoes muted until this time |
| `pendingRedistrib` | `bool` | Set in publishWidths before ColumnWidthChanged; cleared at start of applyColumnWidths |
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
    ┌───────────────────┐                                    ┌──────────────────────────┐
    │  paused or echo?  │──yes──► snapshot prevWidths        │   applyColumnWidths()    │
    └────────┬──────────┘         return                     │   stamp header + body    │
             │ no                                            │   RAF → syncBodyWithHdr  │
             ▼                                              └──────────────────────────┘
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
       │      ┌──────────────────────────┐
       │      │  pin pixel cols          │
       │      │  compute nx weights      │
       │      │  pendingRedistrib = true │
       │      │  → ColumnWidthChanged    │
       │      └──────────┬───────────────┘
       │                 │
       │            MATLAB side
       │                 ▼
       │      ┌──────────────────────────┐
       │      │  onColumnWidthChanged()  │
       │      │  update DataColumnWidth_ │
       │      │  → applyColumnWidthToDisplay │
       │      └──────────┬───────────────┘
       │                 │
       │      ┌──────────▼───────────────┐
       │      │  pauseColumnWidthBridge  │
       │      │    Pause event → JS      │
       │      │    SetWidths event → JS  │
       │      └──────────┬───────────────┘
       │                 │
       │      ┌──────────▼───────────────┐
       │      │  applyColumnWidths()     │
       │      │  pendingRedistrib → false│
       │      │  (redistrib if mixed)    │
       │      └──────────┬───────────────┘
       │                 │
       │      ┌──────────▼───────────────┐
       │      │  Pause expires           │
       │      │  snapshot settledPropWid │
       │      │  snapshot prevWidths     │
       │      └──────────────────────────┘
       │
       ▼
    re-stamp pixel header cols only; no MATLAB notification
```

---

## 7. Drag vs window-resize classification

A column drag always moves two adjacent columns in opposite directions (one
grows, one shrinks).  A window resize moves all (or all visible) columns in
the same direction.

```
hasOpposing    = some changed column grew AND some changed column shrank
singlePixelDrag = exactly one column changed AND it is a pixel (not nx) column

isDrag = hasOpposing || singlePixelDrag
```

`singlePixelDrag` catches the case where the user drags the right edge of the
rightmost pixel column, extending the table width with no offsetting shrink.
Window resizes cannot move pixel columns because `min-width == max-width` is
stamped on them.

---

## 8. Mixed-mode redistribution

**Problem**: In a mixed layout (some pixel, some nx columns), MATLAB stamps
explicit pixel `min-width`/`max-width` on ALL header columns at render time —
including the nx ones.  When the user drags a pixel column:

1. JS sends `ColumnWidthChanged` with the new pixel width and the current nx
   weights.
2. MATLAB echoes `SetWidths = [newPx, -1, -1, ...]` (nx cols remain `-1`).
3. Without redistribution, the nx header columns stay pinned at their
   pre-drag pixel values, so one nx column absorbs all the slack.

**Solution**: At each `Pause` expiry the bridge snapshots `settledPropWidths`
— the rendered pixel widths of nx columns after MATLAB has reflowed.  On the
next mixed-mode `SetWidths` triggered by a bridge drag (`pendingRedistrib ==
true`), the bridge redistributes those nx columns proportionally:

```
containerW   = header table bounding rect width   (unchanged by the drag)
newPropSpace = containerW - sum(pixel cols in SetWidths)
newW_i       = round( newPropSpace × settledPropWidths[i] / settledPropTotal )
```

This keeps the nx columns' pixel ratio intact as the pixel column expands or
contracts.

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
| `prevWidths = null` on every `applyColumnWidths` | Forces the next `publishWidths` to re-anchor to the post-apply state rather than carry stale pre-apply widths as a baseline. Suppression windows prevent the null baseline from triggering false drags. |
| Pause window covers attach + debounce | Worst-case echo: 600 ms (retry attach) + 200 ms (debounce) = 800 ms.  Default Pause = 500 ms; auto-mode Pause = 1200 ms to cover this. |
| Integer nx weight encoding (×100) | MATLAB's `ColumnWidth` validator requires positive integers for nx values.  ×100 gives ~2 sig figs of ratio accuracy without floating point. |
| `isequal(dataWidths, DataColumnWidth_)` guard in `onColumnWidthChanged` | Breaks the potential echo loop: if the ResizeObserver re-fires after the SetWidths stamp (within the suppress window leak), the recomputed widths match the stored widths and MATLAB returns early. |
| Body cells stamped with `min-width == max-width` | Virtual-scroll rows are created lazily; the stamp must be re-applied on every `publishWidths` to cover newly rendered rows. The RAF in `applyColumnWidths` handles the first batch after a MATLAB push. |
| nx columns NOT stamped on drag | Proportional columns must remain free to reflow on window resize; pinning them after a drag would prevent that. |

---

## 10. Known limitations

- **No timer cancellation on rapid pauses** — `pauseColumnWidthBridge` starts
  a new `timer` on each call without cancelling any in-flight timer from a
  prior call.  Since all calls use the same `pauseMs` value (500 or 1200 ms),
  concurrent timers are harmless in practice, but the flag may be cleared
  slightly after the expected deadline if a 500 ms timer races a 1200 ms one.

- **Redistribution uses pre-reflow container width** — `containerW` is read
  synchronously inside `applyColumnWidths` before the browser has reflowed the
  new pixel col stamps.  Because the container (figure/panel) width is
  unchanged by a column drag, this is always the correct value.  It would be
  wrong only if the panel itself resized simultaneously with the drag.

- **nx columns silently ignore right-edge drag** — dragging the right edge of
  the rightmost *auto/nx* column is classified as a window resize and not
  reported to MATLAB.  This is intentional: we cannot pin an nx column to a
  pixel value based on a drag (it must remain proportional).

- **MutationObserver re-attach uses a 50 ms heuristic** — when MATLAB
  re-renders the header, `setupMutationObserver` fires `attachObserver` after
  50 ms.  If MATLAB takes longer, `attachObserver` retries (up to 8 × 600 ms),
  so it recovers, but there is a brief window during which column drags go
  undetected.

---

## 11. Bug history (key fixes)

| Commit | Issue fixed |
|---|---|
| `pendingRedistrib` guard | Redistribution was firing on any mixed-mode `SetWidths`, including programmatic `tb.ColumnWidth = {...}`.  Now only fires for bridge-initiated drag echoes. |
| `!allPixel` RAF condition | Replaced the overly complex `allAuto || (!allPixel && settledPropWidths)` guard; the simpler form also fixes a first-time mixed `SetWidths` with no prior `settledPropWidths` skipping the RAF. |
| `prevColAutoFlags` guard on constraint removal | Prevents removing CSS that MATLAB itself stamped for proportional columns. |
| Integer weight encoding | MATLAB's `ColumnWidth` validator rejects non-integer nx values; ×100 rounding satisfies it. |
| `settledPropWidths` invalidation | Stale snapshots from a different pixel/auto layout (e.g. all-auto → mixed) would drive incorrect redistribution; clearing on layout change fixes this. |

---

## 12. How to test

1. **Pixel drag** — set all columns to fixed pixel widths; drag any divider;
   verify MATLAB `ColumnWidth` updates and body cells track header.

2. **Mixed drag (px/nx boundary)** — set some columns to "1x" and some to a
   pixel value; drag the pixel column's right edge; verify nx columns
   maintain their ratio.

3. **Window resize** — resize the figure; verify MATLAB is NOT notified and
   nx columns reflow freely.

4. **Programmatic push after drag** — drag a column, then set
   `tb.ColumnWidth = {...}` in MATLAB; verify the new widths land in the DOM
   and redistribution does NOT fire.

5. **Multi-table figure** — two `gwidgets.Table` instances in the same figure;
   drag in one; verify the other is unaffected.

6. **Timer cleanup** — run `timerfindall` before and after several drag
   operations; confirm no zombie timers accumulate.
