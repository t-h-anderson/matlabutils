%[text] # gwidgets.Table Developer Guide
%[text] This guide documents the internal architecture of |gwidgets.Table| and |gwidgets.UITable| for maintainers. It complements |TableBridge_DeveloperNotes.md|, which covers the JavaScript bridge in detail.
%%
%[text] ## Public Wrapper and Internal Widget
%[text] |gwidgets.Table| is the public compatibility wrapper. It exposes user-facing controller properties and legacy aliases. |gwidgets.UITable| owns the actual UI component tree, controller instances, update sequencing, and bridge integration.
%%
%[text] ## Controller Ownership
%[text] Controllers are narrow ownership boundaries. |Column| owns column names, widths, visibility, editability, and sortability. |Data| owns source, filtered, grouped, folded, sorted, and display data. |FilterControl| adapts the reusable filter UI. |Group| owns grouping and group folding state. |Sort| owns sort columns and direction. |SelectionControl| owns data/display selection mapping. |Style| owns table styles. |TooltipControl| owns tooltip registration and resolution. |Menu| owns context-menu actions. |Callback| translates MATLAB table events to stable event payloads. |Bridge| owns uihtml communication.
%%
%[text] ## Construction Sequence
%[text] |gwidgets.UITable| creates controllers first, assigns source data, applies constructor name-value arguments, normalises selection, then runs a single update pipeline. |gwidgets.Table| suppresses construction refresh while it forwards wrapper constructor arguments, then runs one construction update and one optional post-construction refresh.
%%
%[text] ## Update Pipeline
%[text] Controller setters do not update the display directly. They ask the owner whether an update should run and then request an update from the earliest affected phase. The update phases are |Filtering|, |Grouping|, |Sorting|, |Folding|, |Display|, |Style|, and |Interaction|. Starting later in the pipeline avoids repeating upstream work.
%%
%[text] ## Suppression
%[text] Use |owner.addControllerUpdateSuppression(propertyName, Times=n)| when a setter is about to make a known follow-up assignment. Suppression is counted, local to the owner, and consumed by |owner.doControllerUpdate(propertyName)|. Avoid global flags and avoid silent empty catch blocks.
%%
%[text] ## Filter Controller Contract
%[text] |gwidgets.internal.table.FilterController| stores detached state when no graphics component is attached. Setting |FilterValue| updates the reusable filter component when present and requests an owner update from |Filtering|. That keeps |Table.Filter| and |Table.FilterControl.FilterValue| behavior identical.
%%
%[text] ## Selection Mapping Contract
%[text] Selection state has two coordinate systems. |Value| is in source data coordinates. |DisplayValue| is in visible display coordinates. Mapping methods must handle folded group headers, filtered rows, hidden columns, empty tables, and out-of-range inputs. Static mapping helpers are unit-tested so selection logic can be verified without creating UI components.
%%
%[text] ## Tooltip Contract
%[text] Tooltip registrations are represented by |TableTooltip| objects. Matching resolves most-specific-first in the order cell, row, column, table. Function tooltips receive a |TooltipContext| that includes value, row slice, column slice, table data, display coordinates, data coordinates, and target. Tooltip style functions must be contained: failures warn when diagnostics are enabled and fall back to default style.
%%
%[text] ## Bridge Contract
%[text] The bridge is an implementation detail owned by |BridgeController| and |table_bridge.html|. MATLAB sends initialization, width, diagnostic, hover, and tooltip-render events. JavaScript sends bridge-ready, column-width, diagnostic, and hover events. DOM selectors must remain scoped by the table tag so multiple tables in one figure do not interfere.
%%
%[text] ## Performance Policy
%[text] Component creation and customisation must not call |drawnow| or |pause| by default. |gwidgets.internal.Drawnow| is disabled by default, and |UITable.forceRefresh| returns before invoking it unless it is explicitly enabled. Keep expensive visual flushes out of constructors, setters, callbacks that may run in loops, and controller update phases.
%%
%[text] ## Opt-In Visual Flushes
%[text] If a maintainer needs to diagnose a MATLAB rendering race, enable the internal flush gate temporarily with |gwidgets.internal.Drawnow.toggleDrawnow(true)|, reproduce the issue, then turn it off. Do not require this gate for correctness, and do not add new |pause| calls.
%%
%[text] ## Extending the Table
%[text] Add user-facing behavior through an existing controller when the behavior belongs to that domain. Add a new controller only when it owns independent state and has a clear update phase or event boundary. The public |gwidgets.Table| wrapper should expose a controller accessor for new primary APIs and retain legacy aliases only for compatibility.
%%
%[text] ## Testing Requirements
%[text] Add focused unit tests for controller state, detached state, mapping helpers, and error identifiers. Add integration or system tests only when MATLAB graphics event behavior is the subject under test. Tests that need private lifecycle methods should use |Access = ?matlab.unittest.TestCase| rather than broadening methods to public.
%%
%[text] ## Documentation Requirements
%[text] Public examples should use controller properties, |Name=Value| syntax, string arrays, and hidden figures during setup. Developer docs should explain ownership, update phase, and performance effects for any new controller or bridge behavior.
%%
%[text] ## See Also
%[text] |gwidgets.Table|, |gwidgets.UITable|, |gwidgets.internal.table.UpdateController|, |gwidgets.internal.Drawnow|, |doc/TableBridge_DeveloperNotes.md|, |doc/TableUserGuide.m|
%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline"}
%---
