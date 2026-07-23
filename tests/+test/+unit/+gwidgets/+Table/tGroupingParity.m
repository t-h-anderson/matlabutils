classdef tGroupingParity < test.WithExampleTables
    % Grouping behaviour that both table backends must satisfy.

    properties (TestParameter)
        Backend = struct("UITable", "UITable", "JavaScript", "JavaScript")
    end

    methods (TestMethodSetup)
        function applyGraphicsLeakFixture(testCase)
            testCase.applyFixture(fixtures.GraphicsLeakFixture());
        end
    end

    methods (Test)
        function tFlatGroupHeadersRenderCollapsed(testCase, Backend)
            t = test.unit.gwidgets.Table.tGroupingParity.createTable( ...
                testCase, Backend, test.WithExampleTables.categoricalData());
            t.GroupingVariable = "Var2";

            renderState = testCase.groupRenderState(t);

            testCase.verifyEqual(renderState.Rows, t.UITable.Data.VisibleGroupHeaderRowIdx)
            testCase.verifyEqual(renderState.Labels, testCase.groupLabels(t))
            testCase.verifyEqual(renderState.Levels, ones(1, numel(renderState.Rows)))
            testCase.verifyEqual(renderState.ColSpans, repelem(width(t.DisplayData), 1, numel(renderState.Rows)))
            testCase.verifyEqual(t.DisplayGroups, ["a", "b", "c"])
            testCase.verifyEmpty(t.OpenGroups)
        end

        function tClickGroupHeaderTogglesOpenState(testCase, Backend)
            t = test.unit.gwidgets.Table.tGroupingParity.createTable( ...
                testCase, Backend, test.WithExampleTables.categoricalData());
            t.GroupingVariable = "Var2";
            firstHeaderRow = t.UITable.Data.VisibleGroupHeaderRowIdx(1);
            firstGroup = t.DisplayGroups(1);

            testCase.clickGroupHeader(t, firstHeaderRow);

            testCase.verifyEqual(t.OpenGroups, firstGroup)
            testCase.verifyGreaterThan(height(t.DisplayData), 3)

            testCase.clickGroupHeader(t, firstHeaderRow);

            testCase.verifyEmpty(t.OpenGroups)
            testCase.verifyEqual(height(t.DisplayData), 3)
        end

        function tNestedGroupHeadersExposeLevels(testCase, Backend)
            t = test.unit.gwidgets.Table.tGroupingParity.createTable(testCase, Backend, testCase.nestedData());
            t.GroupingVariable = ["G1", "G2"];
            t.GroupingMode = "Nested";
            t.OpenGroups = "A";

            renderState = testCase.groupRenderState(t);

            testCase.verifyEqual(renderState.Rows, t.UITable.Data.VisibleGroupHeaderRowIdx)
            testCase.verifyEqual(renderState.Labels, testCase.groupLabels(t))
            testCase.verifyEqual(renderState.Levels, [1 2 2 1])
            testCase.verifyEqual(t.DisplayGroups, ["A", "A|x", "A|y", "B"])
        end

        function tNestedGroupHeaderStylesReachRenderer(testCase, Backend)
            t = test.unit.gwidgets.Table.tGroupingParity.createTable(testCase, Backend, testCase.nestedData());
            t.GroupingVariable = ["G1", "G2"];
            t.GroupingMode = "Nested";
            t.OpenGroups = "A";

            renderState = testCase.groupRenderState(t);

            testCase.verifyTrue(all(contains(renderState.Styles, "background-color")))
            testCase.verifyGreaterThan(numel(unique(renderState.Styles)), 1)
        end
    end

    methods
        function renderState = groupRenderState(testCase, t)
            arguments
                testCase (1,1) test.unit.gwidgets.Table.tGroupingParity
                t (1,1) gwidgets.Table
            end

            switch t.Backend
                case "JavaScript"
                    snapshot = t.UITable.Graphics.Backend.probeBrowser("Snapshot");
                    renderState = struct( ...
                        "Rows", reshape(double(snapshot.groupHeaderRows), 1, []), ...
                        "Labels", reshape(string(snapshot.groupHeaderLabels), 1, []), ...
                        "Levels", reshape(double(snapshot.groupHeaderLevels), 1, []), ...
                        "ColSpans", reshape(double(snapshot.groupHeaderColSpans), 1, []), ...
                        "Styles", reshape(string(snapshot.groupHeaderCssTexts), 1, []));
                otherwise
                    rows = t.UITable.Graphics.Backend.GroupHeaderRows;
                    renderState = struct( ...
                        "Rows", rows, ...
                        "Labels", testCase.groupLabels(t), ...
                        "Levels", t.UITable.Graphics.Backend.GroupHeaderLevels, ...
                        "ColSpans", repelem(width(t.DisplayData), 1, numel(rows)), ...
                        "Styles", testCase.groupStyles(t, rows));
            end
        end

        function clickGroupHeader(testCase, t, row)
            arguments
                testCase (1,1) test.unit.gwidgets.Table.tGroupingParity %#ok<INUSA>
                t (1,1) gwidgets.Table
                row (1,1) double
            end

            switch t.Backend
                case "JavaScript"
                    t.UITable.Graphics.Backend.probeBrowser("ClickCell", struct("row", row, "col", 1));
                otherwise
                    eventData = struct("InteractionInformation", struct( ...
                        "DisplayRow", row, ...
                        "DisplayColumn", 1));
                    t.UITable.Callback.onCellClicked([], eventData);
            end
        end

        function labels = groupLabels(testCase, t)
            arguments
                testCase (1,1) test.unit.gwidgets.Table.tGroupingParity %#ok<INUSA>
                t (1,1) gwidgets.Table
            end

            payload = gwidgets.internal.table.BridgeController.groupHeaderSpanPayload( ...
                t.UITable.Graphics.Backend.Data, ...
                t.UITable.Data.VisibleGroupHeaderRowIdx);
            labels = reshape(string(payload.labels), 1, []);
        end

        function styles = groupStyles(testCase, t, rows)
            arguments
                testCase (1,1) test.unit.gwidgets.Table.tGroupingParity %#ok<INUSA>
                t (1,1) gwidgets.Table
                rows (1,:) double
            end

            styleCss = t.UITable.Style.groupHeaderOverlayCss(rows);
            payload = gwidgets.internal.table.BridgeController.groupHeaderSpanPayload( ...
                t.UITable.Graphics.Backend.Data, rows, styleCss);
            styles = reshape(string(payload.styles), 1, []);
        end
    end

    methods (Static, Access = private)
        function t = createTable(testCase, backend, data)
            arguments
                testCase (1,1) matlab.unittest.TestCase
                backend (1,1) string
                data (:,:) table
            end

            fig = uifigure(Visible="off");
            testCase.addTeardown(@()delete(fig));
            t = gwidgets.Table( ...
                Parent=fig, ...
                Backend=backend, ...
                Data=data);
            testCase.addTeardown(@()delete(t));
        end

        function data = nestedData()
            data = table( ...
                ["B"; "A"; "A"; "B"], ...
                ["x"; "x"; "y"; "x"], ...
                [1; 2; 3; 4], ...
                VariableNames=["G1", "G2", "Value"]);
        end
    end
end
