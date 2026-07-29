classdef tContextMenuParity < test.WithExampleTables
    % Context-menu behaviour that both table backends must satisfy.

    properties (TestParameter)
        Backend = struct("UITable", "UITable", "JavaScript", "JavaScript")
    end

    methods (TestMethodSetup)
        function applyGraphicsLeakFixture(testCase)
            testCase.applyFixture(fixtures.GraphicsLeakFixture());
        end
    end

    methods (Test)
        function tAutoResizeMenuPresence(testCase, Backend)
            t = test.unit.gwidgets.Table.tContextMenuParity.createTable(testCase, Backend);

            state = testCase.menuState(t, 1, 1);

            testCase.verifyEqual(nnz(state.Texts == "Auto-resize columns"), 1)

            tNoResize = test.unit.gwidgets.Table.tContextMenuParity.createTable(testCase, Backend);
            tNoResize.HasAutoResizeColumns = false;
            state = testCase.menuState(tNoResize, 1, 1);

            testCase.verifyFalse(any(state.Texts == "Auto-resize columns"))
        end

        function tDraggingMenuTogglesState(testCase, Backend)
            t = test.unit.gwidgets.Table.tContextMenuParity.createTable(testCase, Backend);
            t.HasToggleDragging = true;

            state = testCase.menuState(t, 1, 1);
            testCase.verifyTrue(any(state.Texts == "Enable row dragging"))

            testCase.selectMenuPath(t, "Enable row dragging", 1, 1);

            testCase.verifyTrue(t.Drag.Enabled)
            state = testCase.menuState(t, 1, 1);
            testCase.verifyTrue(any(state.Texts == "Disable row dragging"))
        end

        function tDisplayOrientationMenuTogglesOrientation(testCase, Backend)
            t = test.unit.gwidgets.Table.tContextMenuParity.createTable(testCase, Backend);

            state = testCase.menuState(t, 1, 1);
            testCase.verifyFalse(any(state.Texts == "Transpose table"))

            t.HasChangeDisplayOrientation = true;
            state = testCase.menuState(t, 1, 1);
            testCase.verifyTrue(any(state.Texts == "Transpose table"))

            testCase.selectMenuPath(t, "Transpose table", 1, 1);

            testCase.verifyEqual(t.DisplayOrientation, "Transposed")
            state = testCase.menuState(t, 1, 1);
            testCase.verifyTrue(any(state.Texts == "Untranspose table"))

            testCase.selectMenuPath(t, "Untranspose table", 1, 1);

            testCase.verifyEqual(t.DisplayOrientation, "Normal")
        end

        function tGroupHeaderTooltipMenuTogglesState(testCase, Backend)
            t = test.unit.gwidgets.Table.tContextMenuParity.createTable(testCase, Backend);

            state = testCase.menuState(t, 1, 1);
            testCase.verifyFalse(any(state.Texts == "Hide group header tooltips"))
            testCase.verifyFalse(any(state.Texts == "Show group header tooltips"))

            t.HasToggleGroupHeaderTooltips = true;
            state = testCase.menuState(t, 1, 1);
            testCase.verifyTrue(any(state.Texts == "Hide group header tooltips"))

            testCase.selectMenuPath(t, "Hide group header tooltips", 1, 1);

            testCase.verifyFalse(t.ShowGroupHeaderTooltips)
            state = testCase.menuState(t, 1, 1);
            testCase.verifyTrue(any(state.Texts == "Show group header tooltips"))

            testCase.selectMenuPath(t, "Show group header tooltips", 1, 1);

            testCase.verifyTrue(t.ShowGroupHeaderTooltips)
        end

        function tTableMetricsMenuTogglesState(testCase, Backend)
            t = test.unit.gwidgets.Table.tContextMenuParity.createTable(testCase, Backend);

            state = testCase.menuState(t, 1, 1);
            testCase.verifyFalse(any(state.Texts == "Show table metrics"))
            testCase.verifyFalse(any(state.Texts == "Hide table metrics"))

            t.HasToggleTableMetrics = true;
            state = testCase.menuState(t, 1, 1);
            testCase.verifyTrue(any(state.Texts == "Show table metrics"))

            testCase.selectMenuPath(t, "Show table metrics", 1, 1);

            testCase.verifyTrue(t.ShowMetrics)
            state = testCase.menuState(t, 1, 1);
            testCase.verifyTrue(any(state.Texts == "Hide table metrics"))

            testCase.selectMenuPath(t, "Hide table metrics", 1, 1);

            testCase.verifyFalse(t.ShowMetrics)
        end

        function tGroupingMenuActions(testCase, Backend)
            t = test.unit.gwidgets.Table.tContextMenuParity.createTable( ...
                testCase, Backend, test.WithExampleTables.stringData());
            t.GroupingVariable = ["Var1", "Var2"];
            t.HasChangeGroupingVariable = true;

            state = testCase.menuState(t, 1, 1);

            testCase.verifyTrue(any(state.Paths == "Grouping > Set > All"))
            testCase.verifyTrue(any(state.Paths == "Grouping > Remove > Var1"))
            testCase.verifyTrue(any(state.Paths == "Grouping > Use nested groups"))

            testCase.selectMenuPath(t, "Grouping > Use nested groups", 1, 1);

            testCase.verifyEqual(t.GroupingMode, "Nested")

            testCase.selectMenuPath(t, "Grouping > Remove > Var1", 1, 1);

            testCase.verifyEqual(t.GroupingVariable, "Var2")

            testCase.selectMenuPath(t, "Grouping > Remove > All", 1, 1);

            testCase.verifyEmpty(t.GroupingVariable)
        end

        function tSelectionModeMenuChangesType(testCase, Backend)
            t = test.unit.gwidgets.Table.tContextMenuParity.createTable(testCase, Backend);
            t.SupportedSelectionTypes = ["cell", "row", "column"];

            state = testCase.menuState(t, 1, 1);

            testCase.verifyTrue(any(state.Paths == "Selection Mode > Row"))

            testCase.selectMenuPath(t, "Selection Mode > Row", 1, 1);

            testCase.verifyEqual(string(t.SelectionType), "row")
        end

        function tHeaderSortMenuSortsColumn(testCase, Backend)
            data = table([3; 1; 2], ["c"; "a"; "b"], VariableNames=["Value", "Label"]);
            t = test.unit.gwidgets.Table.tContextMenuParity.createTable(testCase, Backend, data);
            t.ColumnSortable = true;
            t.HasColumnSorting = true;

            state = testCase.menuState(t, 0, 1);
            testCase.verifyTrue(any(state.Paths == "Sort > Descending"))

            testCase.selectMenuPath(t, "Sort > Descending", 0, 1);

            testCase.verifyEqual(t.Sort.By, "Value")
            testCase.verifyEqual(t.Sort.Direction, "Descend")
            testCase.verifyEqual(t.DisplayData.Value, [3; 2; 1])
        end

        function tTransposedRowSortMenuSortsVariable(testCase, Backend)
            data = table([3; 1; 2], ["b"; "c"; "a"], VariableNames=["ID", "Group"]);
            t = test.unit.gwidgets.Table.tContextMenuParity.createTable(testCase, Backend, data);
            t.ColumnSortable = true;
            t.HasColumnSorting = true;
            t.DisplayOrientation = "Transposed";

            groupRow = find(string(t.DisplayData.Variable) == "Group", 1);
            testCase.assertNotEmpty(groupRow)

            state = testCase.menuState(t, groupRow, 1);
            testCase.verifyTrue(any(state.Paths == "Sort > Ascending"))

            testCase.selectMenuPath(t, "Sort > Ascending", groupRow, 1);

            idRow = find(string(t.DisplayData.Variable) == "ID", 1);
            testCase.assertNotEmpty(idRow)
            displayedIDs = t.DisplayData{idRow, 2:end};
            if iscell(displayedIDs)
                displayedIDs = cell2mat(displayedIDs);
            end
            displayedIDs = str2double(string(displayedIDs));
            testCase.verifyEqual(t.Sort.By, "Group")
            testCase.verifyEqual(t.Sort.Direction, "Ascend")
            testCase.verifyEqual(displayedIDs, [2 3 1])
        end

        function tCustomSubmenuInvokesLeafCallback(testCase, Backend)
            t = test.unit.gwidgets.Table.tContextMenuParity.createTable(testCase, Backend);
            menuFig = uifigure(Visible="off");
            testCase.addTeardown(@()delete(menuFig));
            callbackState = struct("Called", false, "SourceText", "", "DisplayRow", NaN, "DisplayColumn", NaN);
            exportMenu = uimenu(menuFig, Text="Export");
            uimenu(exportMenu, Text="CSV", MenuSelectedFcn=@captureCallback);
            t.addContextMenuItem(exportMenu);

            state = testCase.menuState(t, 2, 3);
            testCase.verifyTrue(any(state.Paths == "Export > CSV"))

            testCase.selectMenuPath(t, "Export > CSV", 2, 3);

            testCase.verifyTrue(callbackState.Called)
            testCase.verifyEqual(callbackState.SourceText, "CSV")
            testCase.verifyEqual(callbackState.DisplayRow, 2)
            testCase.verifyEqual(callbackState.DisplayColumn, 3)

            function captureCallback(src, eventData)
                callbackState.Called = true;
                callbackState.SourceText = string(src.Text);
                callbackState.DisplayRow = double(eventData.InteractionInformation.DisplayRow);
                callbackState.DisplayColumn = double(eventData.InteractionInformation.DisplayColumn);
            end
        end

        function tDisabledCustomSubmenuLeafDoesNotInvokeCallback(testCase, Backend)
            t = test.unit.gwidgets.Table.tContextMenuParity.createTable(testCase, Backend);
            menuFig = uifigure(Visible="off");
            testCase.addTeardown(@()delete(menuFig));
            callbackState = struct("Called", false);
            exportMenu = uimenu(menuFig, Text="Export");
            uimenu(exportMenu, Text="JSON", Enable="off", MenuSelectedFcn=@captureCallback);
            t.addContextMenuItem(exportMenu);

            state = testCase.menuState(t, 2, 3);
            disabledItem = state.Paths == "Export > JSON";
            testCase.assertTrue(any(disabledItem))
            testCase.verifyFalse(state.Enabled(disabledItem))

            testCase.selectDisabledMenuPath(t, "Export > JSON", 2, 3);

            testCase.verifyFalse(callbackState.Called)

            function captureCallback(~, ~)
                callbackState.Called = true;
            end
        end
    end

    methods
        function state = menuState(testCase, t, row, col)
            arguments
                testCase (1,1) test.unit.gwidgets.Table.tContextMenuParity
                t (1,1) gwidgets.Table
                row (1,1) double
                col (1,1) double
            end

            switch t.Backend
                case "JavaScript"
                    snapshot = t.UITable.Graphics.Backend.probeBrowser( ...
                        "OpenContextMenu", struct("row", row, "col", col));
                    state = struct( ...
                        "Texts", testCase.rowString(snapshot.contextMenuTexts), ...
                        "Paths", testCase.rowString(snapshot.contextMenuPaths), ...
                        "Enabled", reshape(logical(snapshot.contextMenuEnabled), 1, []));
                otherwise
                    [texts, paths, enabled] = testCase.collectMenuState(t.ContextMenu, "");
                    state = struct("Texts", texts, "Paths", paths, "Enabled", enabled);
            end
        end

        function selectMenuPath(testCase, t, path, row, col)
            arguments
                testCase (1,1) test.unit.gwidgets.Table.tContextMenuParity
                t (1,1) gwidgets.Table
                path (1,1) string
                row (1,1) double
                col (1,1) double
            end

            switch t.Backend
                case "JavaScript"
                    t.UITable.Graphics.Backend.probeBrowser( ...
                        "SelectContextMenuItem", struct("row", row, "col", col, "path", path));
                otherwise
                    item = testCase.uiMenuItemByPath(t.ContextMenu, path);
                    eventData = struct("InteractionInformation", struct( ...
                        "DisplayRow", row, ...
                        "DisplayColumn", col));
                    item.MenuSelectedFcn(item, eventData);
            end
        end

        function selectDisabledMenuPath(testCase, t, path, row, col)
            arguments
                testCase (1,1) test.unit.gwidgets.Table.tContextMenuParity
                t (1,1) gwidgets.Table
                path (1,1) string
                row (1,1) double
                col (1,1) double
            end

            switch t.Backend
                case "JavaScript"
                    testCase.verifyError( ...
                        @()t.UITable.Graphics.Backend.probeBrowser( ...
                            "SelectContextMenuItem", struct("row", row, "col", col, "path", path)), ...
                        "GraphicsWidgets:Table:ProbeError")
                otherwise
                    item = testCase.uiMenuItemByPath(t.ContextMenu, path);
                    testCase.verifyEqual(string(item.Enable), "off")
            end
        end

        function [texts, paths, enabled] = collectMenuState(testCase, parent, prefix)
            arguments
                testCase (1,1) test.unit.gwidgets.Table.tContextMenuParity
                parent
                prefix (1,1) string
            end

            nItems = testCase.countMenuItems(parent);
            texts = strings(1, nItems);
            paths = strings(1, nItems);
            enabled = false(1, nItems);
            [texts, paths, enabled] = testCase.fillMenuState(parent, prefix, texts, paths, enabled, 1);
        end

        function nItems = countMenuItems(testCase, parent)
            arguments
                testCase (1,1) test.unit.gwidgets.Table.tContextMenuParity
                parent
            end

            children = parent.Children;
            nItems = 0;
            for iChild = 1:numel(children)
                child = children(iChild);
                if ~isprop(child, "Text")
                    continue
                end

                nItems = nItems + 1 + testCase.countMenuItems(child);
            end
        end

        function [texts, paths, enabled, nextIndex] = fillMenuState( ...
                testCase, parent, prefix, texts, paths, enabled, nextIndex)
            arguments
                testCase (1,1) test.unit.gwidgets.Table.tContextMenuParity
                parent
                prefix (1,1) string
                texts (1,:) string
                paths (1,:) string
                enabled (1,:) logical
                nextIndex (1,1) double
            end

            children = parent.Children;
            for iChild = 1:numel(children)
                child = children(iChild);
                if ~isprop(child, "Text")
                    continue
                end

                text = string(child.Text);
                path = text;
                if prefix ~= ""
                    path = prefix + " > " + text;
                end

                texts(nextIndex) = text;
                paths(nextIndex) = path;
                enabled(nextIndex) = string(child.Enable) ~= "off";
                nextIndex = nextIndex + 1;
                [texts, paths, enabled, nextIndex] = testCase.fillMenuState( ...
                    child, path, texts, paths, enabled, nextIndex);
            end
        end

        function item = uiMenuItemByPath(~, parent, path)
            arguments
                ~
                parent
                path (1,1) string
            end

            parts = split(path, " > ");
            item = parent;
            for iPart = 1:numel(parts)
                children = item.Children;
                childText = strings(1, numel(children));
                for iChild = 1:numel(children)
                    childText(iChild) = string(children(iChild).Text);
                end
                idx = find(childText == parts(iPart), 1);
                if isempty(idx)
                    error("GraphicsWidgets:Table:TestMenuItem", ...
                        "Could not find context menu item '%s'.", path);
                end
                item = children(idx);
            end
        end

        function value = rowString(~, value)
            arguments
                ~
                value
            end

            value = reshape(string(value), 1, []);
        end
    end

    methods (Static, Access = private)
        function t = createTable(testCase, backend, data)
            arguments
                testCase (1,1) matlab.unittest.TestCase
                backend (1,1) string
                data (:,:) table = test.WithExampleTables.multivariableData()
            end

            fig = uifigure(Visible="off");
            testCase.addTeardown(@()delete(fig));
            t = gwidgets.Table(Parent=fig, Backend=backend, Data=data);
            testCase.addTeardown(@()delete(t));
        end
    end
end
