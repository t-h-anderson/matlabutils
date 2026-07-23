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
                        "Paths", testCase.rowString(snapshot.contextMenuPaths));
                otherwise
                    [texts, paths] = testCase.collectMenuState(t.ContextMenu, "");
                    state = struct("Texts", texts, "Paths", paths);
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

        function [texts, paths] = collectMenuState(testCase, parent, prefix)
            arguments
                testCase (1,1) test.unit.gwidgets.Table.tContextMenuParity
                parent
                prefix (1,1) string
            end

            nItems = testCase.countMenuItems(parent);
            texts = strings(1, nItems);
            paths = strings(1, nItems);
            [texts, paths] = testCase.fillMenuState(parent, prefix, texts, paths, 1);
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

        function [texts, paths, nextIndex] = fillMenuState(testCase, parent, prefix, texts, paths, nextIndex)
            arguments
                testCase (1,1) test.unit.gwidgets.Table.tContextMenuParity
                parent
                prefix (1,1) string
                texts (1,:) string
                paths (1,:) string
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
                nextIndex = nextIndex + 1;
                [texts, paths, nextIndex] = testCase.fillMenuState( ...
                    child, path, texts, paths, nextIndex);
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
