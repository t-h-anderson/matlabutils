classdef tJavaScriptBackendPerformance < matlab.perftest.TestCase
    % Performance baselines for uihtml-backed table rendering.

    properties (MethodSetupParameter)
        TableShape = struct("Rows100Cols8", struct("Rows", 100, "Columns", 8))
    end

    properties
        Fig
        TableWidget
        Data
    end

    methods (TestMethodSetup)
        function setupTable(testCase, TableShape)
            testCase.applyFixture(fixtures.GraphicsLeakFixture());
            testCase.Data = test.performance.gwidgets.Table.tJavaScriptBackendPerformance.largeData( ...
                TableShape.Rows, TableShape.Columns);
            testCase.Fig = uifigure(Visible="off", Position=[100, 100, 900, 360]);
            testCase.addTeardown(@()delete(testCase.Fig));
            testCase.TableWidget = gwidgets.Table( ...
                Parent=testCase.Fig, ...
                Backend="JavaScript", ...
                Data=testCase.Data);
            testCase.addTeardown(@()delete(testCase.TableWidget));
            testCase.TableWidget.UITable.Graphics.Backend.probeBrowser("Snapshot", Timeout=30);
        end
    end

    methods (Test)
        function tSnapshotRender(testCase)
            backend = testCase.TableWidget.UITable.Graphics.Backend;
            expectedRows = height(testCase.Data);
            expectedColumns = width(testCase.Data);

            testCase.startMeasuring();
            snapshot = backend.probeBrowser("Snapshot", Timeout=30);
            testCase.stopMeasuring();

            testCase.verifyEqual(double(snapshot.rowCount), expectedRows)
            testCase.verifyEqual(double(snapshot.columnCount), expectedColumns)
        end
    end

    methods (Static, Access = private)
        function data = largeData(nRows, nColumns)
            arguments
                nRows (1,1) double {mustBeInteger, mustBePositive}
                nColumns (1,1) double {mustBeInteger, mustBePositive}
            end

            values = cell(1, nColumns);
            names = strings(1, nColumns);
            rowIdx = (1:nRows)';
            for iColumn = 1:nColumns
                names(iColumn) = "Var" + iColumn;
                switch mod(iColumn - 1, 4)
                    case 0
                        values{iColumn} = rowIdx + iColumn;
                    case 1
                        values{iColumn} = "value_" + string(rowIdx) + "_" + iColumn;
                    case 2
                        values{iColumn} = mod(rowIdx + iColumn, 2) == 0;
                    case 3
                        values{iColumn} = categorical("Group" + string(mod(rowIdx + iColumn, 5)));
                    otherwise
                        error("MLUT:Test:UnreachableBranch", "Column type selector produced an unexpected value.");
                end
            end

            data = table(values{:}, VariableNames=names);
        end
    end
end
