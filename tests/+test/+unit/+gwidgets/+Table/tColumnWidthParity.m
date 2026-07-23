classdef tColumnWidthParity < test.WithExampleTables
    % Column-width behaviour that both table backends must satisfy.

    properties (TestParameter)
        Backend = struct("UITable", "UITable", "JavaScript", "JavaScript")
    end

    methods (TestMethodSetup)
        function applyGraphicsLeakFixture(testCase)
            testCase.applyFixture(fixtures.GraphicsLeakFixture());
        end
    end

    methods (Test)
        function tDefaultWidthsUseRelativeColumns(testCase, Backend)
            t = test.unit.gwidgets.Table.tColumnWidthParity.createTable(testCase, Backend);

            testCase.verifyEqual(t.ColumnWidth, {"1x", "1x", "1x", "1x"})
            testCase.verifyEqual(t.DataColumnWidth, {"1x", "1x", "1x", "1x"})
            testCase.verifyEqual(t.DataColumnWidthTypes, repelem("Relative", 1, 4))
            testCase.verifyEqual(testCase.backendColumnWidth(t), {"1x", "1x", "1x", "1x"})
        end

        function tMixedDataWidthsReachBackend(testCase, Backend)
            t = test.unit.gwidgets.Table.tColumnWidthParity.createTable(testCase, Backend);

            t.DataColumnWidth = {100, "1x", "2x", 80};

            testCase.verifyEqual(t.DataColumnWidth, {100, "1x", "2x", 80})
            testCase.verifyEqual(t.ColumnWidth, {100, "1x", "2x", 80})
            testCase.verifyEqual(t.DataColumnWidthTypes, ["Pixel", "Relative", "Relative", "Pixel"])
            testCase.verifyEqual(testCase.backendColumnWidth(t), {100, "1x", "2x", 80})
        end

        function tHiddenColumnWidthsArePreserved(testCase, Backend)
            t = test.unit.gwidgets.Table.tColumnWidthParity.createTable(testCase, Backend);
            t.DataColumnWidth = {100, 200, 150, 80};
            t.HiddenColumnNames = "Categorical";

            t.ColumnWidth = {120, 170, 90};

            testCase.verifyEqual(t.DataColumnWidth, {120, 200, 170, 90})
            testCase.verifyEqual(t.ColumnWidth, {120, 170, 90})
            testCase.verifyEqual(testCase.backendColumnWidth(t), {120, 170, 90})
        end

        function tEmptyColumnWidthUsesDefaultWidths(testCase, Backend)
            data = table([1; 2; 3], ["a"; "b"; "c"], VariableNames=["Value", "Label"]);
            t = test.unit.gwidgets.Table.tColumnWidthParity.createTable(testCase, Backend, data);
            t.DefaultColumnWidths = {150, 250};
            t.DataColumnWidth = {100, 200};

            t.ColumnWidth = {};

            testCase.verifyEqual(t.ColumnWidth, {150, 250})
            testCase.verifyEqual(t.DataColumnWidth, {150, 250})
            testCase.verifyEqual(t.DataColumnWidthTypes, ["Pixel", "Pixel"])
            testCase.verifyEqual(testCase.backendColumnWidth(t), {150, 250})
        end

        function tBridgeWidthEventUpdatesVisibleStores(testCase, Backend)
            t = test.unit.gwidgets.Table.tColumnWidthParity.createTable(testCase, Backend);
            t.DataColumnWidth = {100, "1x", "2x", 80};

            testCase.simulateBackendWidthChange(t, [120, 60, 180, 90]);

            testCase.verifyEqual(t.PixelColumnWidths, [120, 60, 180, 90])
            testCase.verifyEqual(t.RelativeColumnWidths, ["4x", "2x", "6x", "3x"])
            testCase.verifyEqual(t.ColumnWidth, {120, "2x", "6x", 90})
            testCase.verifyEqual(testCase.backendColumnWidth(t), {120, "2x", "6x", 90})
        end

        function tBridgeWidthEventMapsHiddenColumns(testCase, Backend)
            t = test.unit.gwidgets.Table.tColumnWidthParity.createTable(testCase, Backend);
            t.DataColumnWidth = {100, 200, 150, 80};
            t.HiddenColumnNames = "Categorical";

            testCase.simulateBackendWidthChange(t, [120, 170, 90]);

            testCase.verifyEqual(t.DataColumnWidth, {120, 200, 170, 90})
            testCase.verifyEqual(t.ColumnWidth, {120, 170, 90})
            testCase.verifyEqual(testCase.backendColumnWidth(t), {120, 170, 90})
        end

        function tGroupedWidthsFollowRenderedDataColumns(testCase, Backend)
            t = test.unit.gwidgets.Table.tColumnWidthParity.createTable(testCase, Backend);
            t.DataColumnWidth = {100, 200, 150, 80};

            t.GroupingVariable = "Categorical";

            testCase.verifyEqual( ...
                string(t.DisplayData.Properties.VariableNames), ...
                ["Numerical", "Logical", "String"])
            testCase.verifyEqual(t.DataColumnWidth, {100, 200, 150, 80})
            testCase.verifyEqual(t.ColumnWidth, {100, 200, 150, 80})
            testCase.verifyEqual(testCase.backendColumnWidth(t), {100, 150, 80})
        end

        function tRenderedPixelWidthsOmitHiddenColumns(testCase, Backend)
            t = test.unit.gwidgets.Table.tColumnWidthParity.createTable(testCase, Backend);
            t.DataColumnWidth = {100, 200, 150, 80};
            t.HiddenColumnNames = "Categorical";

            testCase.verifyEqual(testCase.renderedWidthTokens(t), ["100px", "150px", "80px"])
        end

        function tRenderedRelativeWidthsUseBackendFormat(testCase, Backend)
            t = test.unit.gwidgets.Table.tColumnWidthParity.createTable(testCase, Backend);

            t.DataColumnWidth = {"1x", "2x", "1x", "4x"};

            testCase.verifyEqual( ...
                testCase.renderedWidthTokens(t), ...
                testCase.expectedRenderedWidthTokens(Backend, {"1x", "2x", "1x", "4x"}))
        end
    end

    methods
        function widths = backendColumnWidth(testCase, t)
            arguments
                testCase (1,1) test.unit.gwidgets.Table.tColumnWidthParity %#ok<INUSA>
                t (1,1) gwidgets.Table
            end

            widths = gwidgets.Table.normalizeColumnWidths(t.UITable.Graphics.Backend.ColumnWidth);
        end

        function simulateBackendWidthChange(testCase, t, pixelWidths)
            arguments
                testCase (1,1) test.unit.gwidgets.Table.tColumnWidthParity %#ok<INUSA>
                t (1,1) gwidgets.Table
                pixelWidths (1,:) double
            end

            switch t.Backend
                case "JavaScript"
                    t.UITable.Graphics.Backend.handleBrowserEvent(struct( ...
                        "event", "ColumnWidthChanged", ...
                        "widths", pixelWidths));
                otherwise
                    t.simulateBridgeDrag(pixelWidths);
            end
        end

        function tokens = renderedWidthTokens(testCase, t)
            arguments
                testCase (1,1) test.unit.gwidgets.Table.tColumnWidthParity
                t (1,1) gwidgets.Table
            end

            switch t.Backend
                case "JavaScript"
                    snapshot = t.UITable.Graphics.Backend.probeBrowser("Snapshot");
                    tokens = reshape(string(snapshot.colStyleWidths), 1, []);
                otherwise
                    tokens = testCase.widthTokens(t.DisplayTable.ColumnWidth);
            end
        end

        function tokens = expectedRenderedWidthTokens(testCase, backend, widths)
            arguments
                testCase (1,1) test.unit.gwidgets.Table.tColumnWidthParity
                backend (1,1) string
                widths (1,:) cell
            end

            switch backend
                case "JavaScript"
                    tokens = testCase.cssWidthTokens(widths);
                otherwise
                    tokens = testCase.widthTokens(widths);
            end
        end
    end

    methods (Access = private)
        function tokens = widthTokens(testCase, widths)
            arguments
                testCase (1,1) test.unit.gwidgets.Table.tColumnWidthParity %#ok<INUSA>
                widths
            end

            widths = gwidgets.Table.normalizeColumnWidths(widths);
            tokens = strings(1, numel(widths));
            for iWidth = 1:numel(widths)
                value = widths{iWidth};
                if isnumeric(value) && isscalar(value)
                    tokens(iWidth) = string(value) + "px";
                else
                    tokens(iWidth) = string(value);
                end
            end
        end

        function tokens = cssWidthTokens(testCase, widths)
            arguments
                testCase (1,1) test.unit.gwidgets.Table.tColumnWidthParity
                widths (1,:) cell
            end

            tokens = testCase.widthTokens(widths);
            weights = testCase.relativeWeights(tokens);
            totalWeight = sum(weights);
            for iWidth = 1:numel(tokens)
                if weights(iWidth) > 0 && totalWeight > 0
                    tokens(iWidth) = testCase.percentToken(100*weights(iWidth)/totalWeight);
                end
            end
        end

        function weights = relativeWeights(testCase, tokens)
            arguments
                testCase (1,1) test.unit.gwidgets.Table.tColumnWidthParity %#ok<INUSA>
                tokens (1,:) string
            end

            weights = zeros(1, numel(tokens));
            for iWidth = 1:numel(tokens)
                match = regexp(tokens(iWidth), "^(\d+(?:\.\d+)?)x$", "tokens", "once");
                if ~isempty(match)
                    weights(iWidth) = str2double(match{1});
                end
            end
        end

        function token = percentToken(testCase, value)
            arguments
                testCase (1,1) test.unit.gwidgets.Table.tColumnWidthParity %#ok<INUSA>
                value (1,1) double
            end

            token = string(sprintf("%.6f", value));
            token = string(regexprep(token, "\.?0+$", "")) + "%";
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
            t = gwidgets.Table( ...
                Parent=fig, ...
                Backend=backend, ...
                Data=data);
            testCase.addTeardown(@()delete(t));
        end
    end
end
