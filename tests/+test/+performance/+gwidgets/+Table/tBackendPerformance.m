classdef tBackendPerformance < matlab.perftest.TestCase
    % Performance baselines for large gwidgets.Table backend workflows.

    properties (MethodSetupParameter)
        Backend = struct("UITable", "UITable", "JavaScript", "JavaScript")
        TableShape = struct( ...
            "Rows100Cols8", struct("Rows", 100, "Columns", 8), ...
            "Rows500Cols8", struct("Rows", 500, "Columns", 8))
    end

    properties
        Fig
        TableWidget
        InitialData
        UpdatedData
        BackendName (1,1) string
    end

    methods (TestMethodSetup)
        function setupTable(testCase, Backend, TableShape)
            Backend = string(Backend);
            testCase.applyFixture(fixtures.GraphicsLeakFixture());
            testCase.BackendName = Backend;
            testCase.InitialData = test.performance.gwidgets.Table.tBackendPerformance.largeData( ...
                TableShape.Rows, TableShape.Columns, "initial");
            testCase.UpdatedData = test.performance.gwidgets.Table.tBackendPerformance.largeData( ...
                TableShape.Rows, TableShape.Columns, "updated");

            testCase.Fig = uifigure(Visible="off", Position=[100, 100, 900, 360]);
            testCase.addTeardown(@()delete(testCase.Fig));
            testCase.TableWidget = gwidgets.Table( ...
                Parent=testCase.Fig, ...
                Backend=Backend, ...
                Data=testCase.InitialData);
            testCase.addTeardown(@()delete(testCase.TableWidget));
            testCase.settleRenderer();
        end
    end

    methods (Test)
        function tDataUpdateRender(testCase)
            tableWidget = testCase.TableWidget;
            data = testCase.UpdatedData;
            backendName = testCase.BackendName;
            renderedRows = height(data);

            testCase.startMeasuring();
            tableWidget.Data = data;
            if backendName == "JavaScript"
                renderResult = tableWidget.UITable.Graphics.Backend.waitForBrowserRender(Timeout=30);
                renderedRows = double(renderResult.rowCount);
            else
                drawnow();
            end
            testCase.stopMeasuring();

            testCase.verifyEqual(height(tableWidget.Data), height(data))
            testCase.verifyEqual(width(tableWidget.Data), width(data))
            testCase.verifyEqual(renderedRows, height(data))
        end
    end

    methods (Access = private)
        function settleRenderer(testCase)
            drawnow();
            if testCase.BackendName ~= "JavaScript"
                return
            end

            testCase.TableWidget.UITable.Graphics.Backend.waitForBrowserRender(Timeout=30);
        end
    end

    methods (Static, Access = private)
        function data = largeData(nRows, nColumns, label)
            arguments
                nRows (1,1) double {mustBeInteger, mustBePositive}
                nColumns (1,1) double {mustBeInteger, mustBePositive}
                label (1,1) string
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
                        values{iColumn} = label + "_" + string(rowIdx) + "_" + iColumn;
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
