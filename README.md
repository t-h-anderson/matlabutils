# MATLAB Utils

MATLAB Utils is a small MATLAB project containing general-purpose utilities and reusable UI widgets.

The main packages are:

- `mlut`: utility functions and robust wrappers around `table` and `timetable`.
- `mlut.sl`: Simulink session, data dictionary, bus, model-wrapper, and trace utilities.
- `mlut.workspace`: scoped access and guard utilities for base-workspace changes.
- `gwidgets`: interactive graphics widgets, including a filterable/sortable table and drag-link helpers.

## Requirements

- MATLAB R2025a or newer is required.
- Simulink is required for `mlut.sl` utilities and their tests.
- Statistics and Machine Learning Toolbox is currently required by the source dependency graph.

## Getting Started

Install a release by downloading `MatlabUtils <version>.mltbx` from the [GitHub releases](https://github.com/t-h-anderson/matlabutils/releases), or work from source:

Open `MLUT.prj` in MATLAB, or add the source folder to the path manually:

```matlab
addpath(genpath("src"))
```

Run the table demo from MATLAB with:

```matlab
run("doc/TableDemo.m")
```

For fuller MATLAB-style documentation, open:

- `doc/TableUserGuide.m`: user-facing workflow and controller API examples.
- `doc/TableDeveloperGuide.m`: controller architecture, update phases, bridge boundaries, and performance rules.
- `doc/TableBridge_DeveloperNotes.md`: detailed JavaScript bridge notes.

### Table Controller API

`gwidgets.Table` exposes focused controller objects for table behavior. Prefer these for new code:

```matlab
t = gwidgets.Table(Data=data);

t.Column.Sortable = true;
t.FilterControl.FilterValue = "Category=A|B";
t.Group.By = ["Category", "Status"];
t.Group.openAll();
t.SelectionControl.Type = "row";
t.SelectionControl.Value = 1;
t.Sort.By = ["Status", "Value"];
t.Sort.Direction = "Ascend";
t.TooltipControl.Text = "Visible table row";
```

The older pass-through properties, such as `GroupingVariable`, `OpenGroups`, `SortByColumn`, and `SortDirection`,
remain supported as compatibility aliases. Where a legacy value property already uses the natural name, the controller
surface uses a `Control` suffix, such as `FilterControl`, `SelectionControl`, and `TooltipControl`.

Automatic `drawnow`/`pause` flushing is disabled during normal table creation and customisation. Build larger apps by
creating figures hidden, setting controller state, and showing the figure once setup is complete.

## Testing

### Copying table data

Use **Copy selection** in the table context menu or **Ctrl+C** to copy
selected cells, rows or columns. **Copy visible table** copies the filtered,
sorted and folded view with its displayed column headers. Hidden columns
are omitted. The clipboard text is tab-separated for pasting into spreadsheets;
tabs, newlines and quotes inside cells are quoted.

Programmatically, use `t.Clipboard.copySelection()` or
`t.Clipboard.copySelection(AllVisible=true, IncludeHeaders=true)`.
`t.Clipboard.selectionText(...)` formats the same data without writing to the
clipboard. Applications can supply `t.Clipboard.WriteFcn` to receive the text.

### Searching table rows

Column filters use the displayed header, including spaces:
`Model Reference=ctrlDsp1` matches exactly and
`GDS Target?="Pole 1"` searches for text within a column. Quote values
containing spaces or operators. Exact column names take precedence over
longer names sharing the same prefix.

Enable **Apply filter to all text columns** for a plain-text search such as
`ctrlDsp1`. Changing this checkbox immediately reapplies the current query.
Invalid or ambiguous column filters show no rows and an **Invalid filter**
message; clear or correct the query to restore the rows.

The project uses class-based `matlab.unittest` tests under `tests/+test`.

Run the full suite through the build tool:

```matlab
buildtool test
```

Or run it directly:

```matlab
addpath(genpath("src"))
addpath("tests")
results = [
    runtests("tests/+test/+unit", IncludeSubfolders=true), ...
    runtests("tests/+test/+integration", IncludeSubfolders=true), ...
    runtests("tests/+test/+system", IncludeSubfolders=true)
];
```

## Build Tasks

`buildfile.m` defines these tasks:

- `check`: run MATLAB Code Analyzer over `src` and print reported issues.
- `test`: run the unit, integration, and system test suites with `src` and `tests` on the path.
- `package`: package the toolbox from `MLUT.prj`.

## License

The license is available in `license.txt`.
