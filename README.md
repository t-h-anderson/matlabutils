# MATLAB Utils

MATLAB Utils is a small MATLAB project containing general-purpose utilities and reusable UI widgets.

The main packages are:

- `mlut`: utility functions and robust wrappers around `table` and `timetable`.
- `gwidgets`: interactive graphics widgets, including a filterable/sortable table and drag-link helpers.

## Requirements

- MATLAB R2023b or newer is recommended.
- Statistics and Machine Learning Toolbox is currently required by the source dependency graph.

## Getting Started

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
