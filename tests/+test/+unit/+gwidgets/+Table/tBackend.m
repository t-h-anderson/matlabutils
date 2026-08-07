classdef tBackend < matlab.unittest.TestCase
    % Tests for swappable table rendering backends.

    methods (TestMethodSetup)
        function applyGraphicsLeakFixture(testCase)
            testCase.applyFixture(fixtures.GraphicsLeakFixture());
        end
    end

    methods (Test)
        function tDefaultBackendUsesUITable(testCase)
            t = gwidgets.Table();

            testCase.verifyEqual(t.Backend, "UITable")
            testCase.verifyEqual(t.Render, "UITable")
            testCase.verifyInstanceOf(t.UITable.Graphics.Backend, ...
                "gwidgets.internal.table.backend.UITableBackend")
            testCase.verifyInstanceOf(t.DisplayTable, "matlab.ui.control.Table")
        end

        function tJavaScriptBackendUsesHTMLComponent(testCase)
            fig = uifigure(Visible="off");
            testCase.addTeardown(@()delete(fig));
            data = table((1:3)', ["a"; "b"; "c"], VariableNames=["Value", "Label"]);

            t = gwidgets.Table(Parent=fig, Backend="JavaScript", Data=data);

            testCase.verifyEqual(t.Backend, "JavaScript")
            testCase.verifyEqual(t.Render, "JavaScript")
            testCase.verifyInstanceOf(t.UITable.Graphics.Backend, ...
                "gwidgets.internal.table.backend.JSTableBackend")
            testCase.verifyInstanceOf(t.DisplayTable, "matlab.ui.control.HTML")
            testCase.verifyEqual(t.DisplayData, data)
        end

        function tRenderAliasUsesJavaScriptRenderer(testCase)
            fig = uifigure(Visible="off");
            testCase.addTeardown(@()delete(fig));
            data = table((1:3)', ["a"; "b"; "c"], VariableNames=["Value", "Label"]);

            t = gwidgets.Table(Parent=fig, Render="JavaScript", Data=data);

            testCase.verifyEqual(t.Render, "JavaScript")
            testCase.verifyEqual(t.Backend, "JavaScript")
            testCase.verifyInstanceOf(t.UITable.Graphics.Backend, ...
                "gwidgets.internal.table.backend.JSTableBackend")
        end

        function tRenderAliasRejectsBackendConflict(testCase)
            testCase.verifyError( ...
                @()gwidgets.Table(Backend="UITable", Render="JavaScript"), ...
                "GraphicsWidgets:Table:RenderConflict")
        end

        function tPrimaryBackendOccupiesDisplayRowNotBridgeRow(testCase)
            fig = uifigure(Visible="off");
            testCase.addTeardown(@()delete(fig));

            t = gwidgets.Table(Parent=fig, Data=table((1:3)', VariableNames="Value"));
            backend = t.UITable.Graphics.Backend;
            bridgeGrid = t.UITable.Graphics.Grid;
            drawnow();

            testCase.verifyEqual(backend.Component.Layout.Row, 3)
            testCase.verifyEqual(backend.Component.Layout.Column, 1)
            testCase.verifyNumElements(bridgeGrid.RowHeight, 4)
            testCase.verifyEqual(bridgeGrid.RowHeight{4}, 2)
        end

        function tUITableBridgeRegistersLocalTooltipDismissalHandlers(testCase)
            import matlab.unittest.constraints.ContainsSubstring

            html = string(fileread(test.unit.gwidgets.Table.tBackend.bridgeHtmlPath()));

            testCase.verifyThat(html, ContainsSubstring('function clearHoverTooltip'))
            testCase.verifyThat(html, ContainsSubstring('sendHover(0, 0);'))
            testCase.verifyThat(html, ContainsSubstring('function isRealHoverLeave'))
            testCase.verifyThat(html, ContainsSubstring('if (!relatedTarget) return true;'))
            testCase.verifyThat(html, ContainsSubstring('hoverRootTarget.addEventListener("pointerleave"'))
            testCase.verifyThat(html, ContainsSubstring('hoverRootTarget.addEventListener("mouseleave"'))
            testCase.verifyThat(html, ContainsSubstring('hoverRootTarget.addEventListener("mouseout"'))
            testCase.verifyThat(html, ContainsSubstring('pd.addEventListener("mouseout", hoverDocumentOutListener'))
            testCase.verifyThat(html, ContainsSubstring('window.addEventListener("blur"'))
            testCase.verifyThat(html, ContainsSubstring('pd.addEventListener("visibilitychange"'))
            mouseMoveBlock = extractBetween(html, ...
                "function onTableMouseMove(evt) {", ...
                "function onTableMouseUp(evt)");
            testCase.verifyLessThan( ...
                strfind(mouseMoveBlock, "syncHoverRootListener(root);"), ...
                strfind(mouseMoveBlock, "handleGroupSpanTooltipMove(evt)"))
        end

        function tJavaScriptBackendDoesNotClearUITableBridgeTooltip(testCase)
            backendSource = string(fileread( ...
                test.unit.gwidgets.Table.tBackend.jsBackendPath()));
            bridgeSource = string(fileread( ...
                test.unit.gwidgets.Table.tBackend.bridgeControllerPath()));

            testCase.verifyFalse(contains(backendSource, "clearTooltip"))
            testCase.verifyFalse(contains(bridgeSource, "function clearTooltip"))
        end

        function tUITableBridgeCellHoverZeroZeroSendsEmptyTooltip(testCase)
            import matlab.unittest.constraints.ContainsSubstring

            bridgeSource = string(fileread( ...
                test.unit.gwidgets.Table.tBackend.bridgeControllerPath()));

            testCase.verifyThat(bridgeSource, ContainsSubstring("if row == 0 && col == 0"))
            testCase.verifyThat(bridgeSource, ContainsSubstring( ...
                'this.send("SetTooltip", struct("blocks", {cell(1,0)}));'))
        end

        function tTransposedUITableUsesReadableDefaultGroupHeaderWidths(testCase)
            fig = uifigure(Visible="off");
            testCase.addTeardown(@()delete(fig));

            data = table( ...
                ["A"; "A"; "B"; "B"; "C"; "C"], ...
                (1:6)', ...
                [10; 20; 30; 40; 50; 60], ...
                VariableNames=["Group", "Value", "Other"]);
            t = gwidgets.Table(Parent=fig, Backend="UITable", Data=data);
            t.GroupingVariable = "Group";
            t.openAllGroups();
            t.DisplayOrientation = "Transposed";
            drawnow();

            widths = t.UITable.Graphics.Backend.ColumnWidth;
            groupColumns = t.UITable.Data.VisibleGroupHeaderRowIdx + 1;

            testCase.verifyGreaterThanOrEqual(widths{1}, 64)
            for iColumn = 1:numel(groupColumns)
                testCase.verifyGreaterThanOrEqual(widths{groupColumns(iColumn)}, 64)
            end
            dataColumns = setdiff(2:numel(widths), groupColumns);
            testCase.verifyNotEmpty(dataColumns)
            testCase.verifyGreaterThanOrEqual(widths{dataColumns(1)}, 64)
        end

        function tJavaScriptSelectionEventMapsRows(testCase)
            fig = uifigure(Visible="off");
            testCase.addTeardown(@()delete(fig));
            data = table((1:4)', VariableNames="Value");
            t = gwidgets.Table(Parent=fig, Backend="JavaScript", Data=data);
            backend = t.UITable.Graphics.Backend;

            t.SelectionType = "row";
            backend.handleBrowserEvent(struct( ...
                "event", "SelectionChanged", ...
                "indices", [2 1; 3 1]));

            testCase.verifyEqual(t.DisplaySelection, [2 3])
            testCase.verifyEqual(backend.Selection, [2 3])
        end

        function tJavaScriptEditEventCoercesNumericData(testCase)
            fig = uifigure(Visible="off");
            testCase.addTeardown(@()delete(fig));
            data = table([1; 2; 3], VariableNames="Value");
            t = gwidgets.Table(Parent=fig, Backend="JavaScript", Data=data);
            backend = t.UITable.Graphics.Backend;
            editEvent = [];
            t.CellEditCallback = @(~, evt)captureEdit(evt);

            backend.handleBrowserEvent(struct( ...
                "event", "CellEdited", ...
                "row", 2, ...
                "col", 1, ...
                "value", "42"));

            testCase.verifyEqual(t.Data.Value(2), 42)
            testCase.verifyEqual(editEvent.DisplayIndices, [2 1])
            testCase.verifyEqual(editEvent.PreviousData, 2)
            testCase.verifyEqual(editEvent.NewData, 42)

            function captureEdit(evt)
                editEvent = evt;
            end
        end

        function tJavaScriptSortEventUsesDisplayVariable(testCase)
            fig = uifigure(Visible="off");
            testCase.addTeardown(@()delete(fig));
            data = table([3; 1; 2], VariableNames="Value");
            t = gwidgets.Table(Parent=fig, Backend="JavaScript", Data=data);
            backend = t.UITable.Graphics.Backend;
            t.ColumnSortable = true;

            backend.handleBrowserEvent(struct( ...
                "event", "DisplayDataChanged", ...
                "interaction", "sort", ...
                "variable", "Value"));

            testCase.verifyEqual(t.Sort.By, "Value")
            testCase.verifyEqual(t.Sort.Direction, "Ascend")
            testCase.verifyEqual(t.DisplayData.Value, [1; 2; 3])
        end
    end

    methods (Static, Access = private)
        function path = bridgeHtmlPath()
            path = fullfile(test.unit.gwidgets.Table.tBackend.sourcePackagePath(), ...
                "+internal", "table_bridge.html");
        end

        function path = jsBackendPath()
            path = fullfile(test.unit.gwidgets.Table.tBackend.sourcePackagePath(), ...
                "+internal", "+table", "+backend", "JSTableBackend.m");
        end

        function path = bridgeControllerPath()
            path = fullfile(test.unit.gwidgets.Table.tBackend.sourcePackagePath(), ...
                "+internal", "+table", "BridgeController.m");
        end

        function path = sourcePackagePath()
            testFolder = fileparts(mfilename("fullpath"));
            unitFolder = fileparts(fileparts(fileparts(fileparts(testFolder))));
            projectFolder = fileparts(unitFolder);
            path = fullfile(projectFolder, "src", "+gwidgets");
        end
    end
end
