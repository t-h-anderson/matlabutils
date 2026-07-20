classdef tSelection < test.WithExampleTables
    % Test selecting rows, columns and cells in headless tables.

    methods (Test)

        function tNoSelection(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());

            testCase.verifyEqual(t.SelectionType, 'cell');
            testCase.verifyEqual(t.Selection, double.empty(0,2))
            testCase.verifyEqual(t.DisplaySelection, double.empty(0,2))
        end

        function tSelectSingleCell(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());

            t.Selection = [2 2];

            testCase.verifyEqual(t.Selection, [2 2])
            testCase.verifyEqual(t.DisplaySelection, [2 2])
        end

        function tSelectSingleCellFromDisplay(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());

            t.DisplaySelection = [2 2];

            testCase.verifyEqual(t.Selection, [2 2])
            testCase.verifyEqual(t.DisplaySelection, [2 2])
        end

        function tTransposedCellSelectionMapsToData(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData(), DisplayOrientation="Transposed");

            t.Selection = [2 4];

            testCase.verifyEqual(t.Selection, [2 4])
            testCase.verifyEqual(t.DisplaySelection, [4 3])

            t.DisplaySelection = [4 1; 4 3];

            testCase.verifyEqual(t.Selection, [2 4])
            testCase.verifyEqual(t.DisplaySelection, [4 1; 4 3])
        end

        function tTransposedDisplayEditMapsToData(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData(), DisplayOrientation="Transposed");

            t.UITable.Data.editDisplayCell([4 3], "z", t.UITable.Selection);

            testCase.verifyEqual(t.Data.String(2), "z")
        end

        function tDisplaySelectionMapsThroughAliases(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());
            t.ColumnNames = ["Number", "Category", "Boolean", "Text"];

            t.DisplaySelection = [2 3];

            testCase.verifyEqual(t.Selection, [2 3])
            testCase.verifyEqual(t.DisplaySelection, [2 3])
        end

        function tSelectSingleRow(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());
            t.SelectionType = "row";

            testCase.verifyEqual(t.Selection, double.empty(1,0))
            testCase.verifyEqual(t.DisplaySelection, double.empty(1,0))

            t.Selection = 3;

            testCase.verifyEqual(t.Selection, 3)
            testCase.verifyEqual(t.DisplaySelection, 3)
        end

        function tSelectSingleRowFromDisplay(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());
            t.SelectionType = "row";

            t.DisplaySelection = 3;

            testCase.verifyEqual(t.Selection, 3)
            testCase.verifyEqual(t.DisplaySelection, 3)
        end

        function tSelectSingleColumn(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());
            t.SelectionType = "column";

            testCase.verifyEqual(t.Selection, double.empty(1,0))
            testCase.verifyEqual(t.DisplaySelection, double.empty(1,0))

            t.Selection = 2;

            testCase.verifyEqual(t.Selection, 2)
            testCase.verifyEqual(t.DisplaySelection, 2)
        end

        function tSelectSingleColumnFromDisplay(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());
            t.SelectionType = "column";

            t.DisplaySelection = 2;

            testCase.verifyEqual(t.Selection, 2)
            testCase.verifyEqual(t.DisplaySelection, 2)
        end

        function tColumnVectorSelection(testCase)
            % Specifying row/column selection as a row/column vector
            % shouldn't make any difference.
            t = gwidgets.Table(Data=testCase.multivariableData());
            t.SelectionType = "column";

            t.Selection = [2 3];
            testCase.verifyEqual(t.Selection, [2 3])
            testCase.verifyEqual(t.DisplaySelection, [2 3])

            t.Selection = [1 2]';
            testCase.verifyEqual(t.Selection, [1 2])
            testCase.verifyEqual(t.DisplaySelection, [1 2])
            
            t.DisplaySelection = [2 3 4]';
            testCase.verifyEqual(t.Selection, [2 3 4])
            testCase.verifyEqual(t.DisplaySelection, [2 3 4])
        end

        function tRowVectorSelection(testCase)
            % Specifying row/column selection as a row/column vector
            % shouldn't make any difference.
            t = gwidgets.Table(Data=testCase.multivariableData());
            t.SelectionType = "row";

            t.Selection = [2 3];
            testCase.verifyEqual(t.Selection, [2 3])
            testCase.verifyEqual(t.DisplaySelection, [2 3])

            t.Selection = [1 2]';
            testCase.verifyEqual(t.Selection, [1 2])
            testCase.verifyEqual(t.DisplaySelection, [1 2])
            
            t.DisplaySelection = [2 3 4]';
            testCase.verifyEqual(t.Selection, [2 3 4])
            testCase.verifyEqual(t.DisplaySelection, [2 3 4])
        end

        function tInvalidCellSelection(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());

            fcn = @() t.set("Selection", [100 100]);
            testCase.verifyError(fcn, "GraphicsWidgets:Table:SelectionOutsideLimits")

            testCase.verifyEqual(t.Selection, double.empty(0,2))
            testCase.verifyEqual(t.DisplaySelection, double.empty(0,2))

            t.Selection = repelem(1, 20, 2);
            testCase.verifyEqual(t.Selection, [1,1])
            testCase.verifyEqual(t.DisplaySelection, [1,1])
        end

        function tInvalidRowAndColumnSelection(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());
            t.SelectionType = "row";

            fcn = @() t.set("Selection", [1 1; 2 2]);
            testCase.verifyError(fcn, "GraphicsWidgets:Table:UnsupportedSelectionSize")

            t.SelectionType = "column";

            fcn = @() t.set("Selection", [1 1; 2 2]);
            testCase.verifyError(fcn, "GraphicsWidgets:Table:UnsupportedSelectionSize")
        end

        function tCellMultiselect(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());
            testCase.verifyEqual(t.Multiselect, matlab.lang.OnOffSwitchState.on)

            t.Selection = [2 2; 5 1];

            testCase.verifyEqual(t.Selection, [2 2; 5 1])
            testCase.verifyEqual(t.DisplaySelection, [2 2; 5 1])
        end

        function tCellMultiselectFromDisplay(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());

            t.DisplaySelection = [2 2; 5 1];

            testCase.verifyEqual(t.Selection, [2 2; 5 1])
            testCase.verifyEqual(t.DisplaySelection, [2 2; 5 1])
        end

        function tDisableMultiselect(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());

            selection = [2 2; 5 1];

            % Can multi select when turned on
            t.Multiselect = "on";
            t.Selection = selection;
            testCase.verifyEqual(t.Selection, selection);

            % Changing multiselect clears the selection
            t.Multiselect = "off";
            testCase.verifyEqual(t.Selection, double.empty(0,2))

            % Can select one cell
            t.Selection = selection(1,:);
            testCase.verifyEqual(t.Selection, selection(1,:));

            fcn = @() t.set("Selection", selection);
            testCase.verifyError(fcn, "GraphicsWidgets:Table:InvalidSingleSelection")

            % Failed selection leaves previous value
            testCase.verifyEqual(t.Selection, selection(1,:))
            testCase.verifyEqual(t.DisplaySelection, selection(1,:))


        end

        function tRowMultiselect(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());
            t.SelectionType = "row";

            t.Selection = [3; 4; 5];

            testCase.verifyEqual(t.Selection, [3 4 5])
            testCase.verifyEqual(t.DisplaySelection, [3 4 5])
        end

        function tRowMultiselectFromDisplay(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());
            t.SelectionType = "row";

            t.DisplaySelection = [1 2 3];

            testCase.verifyEqual(t.Selection, [1,2,3])
            testCase.verifyEqual(t.DisplaySelection, [1 2 3])
        end

        function tColumnMultiselect(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());
            t.SelectionType = "column";

            t.Selection = [2 3 4];

            testCase.verifyEqual(t.Selection, [2 3 4])
            testCase.verifyEqual(t.DisplaySelection, [2 3 4])
        end

        function tColumnMultiselectFromDisplay(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());
            t.SelectionType = "column";

            t.DisplaySelection = [2 3 4];

            testCase.verifyEqual(t.Selection, [2 3 4])
            testCase.verifyEqual(t.DisplaySelection, [2 3 4])
        end

        function tSwitchSelectionType(testCase)
            % Switch selection between cell, row, column when a selection
            % had already been made.
            t = gwidgets.Table(Data=testCase.multivariableData());
            t.Selection = [2 2];

            t.SelectionType = "row";

            testCase.verifyEqual(t.Selection, double.empty(1,0))
            testCase.verifyEqual(t.DisplaySelection, double.empty(1,0))

            t.Selection = 4;

            t.SelectionType = "column";
            
            testCase.verifyEqual(t.Selection, double.empty(1,0))
            testCase.verifyEqual(t.DisplaySelection, double.empty(1,0))
        end

        function tDisableMultiselectAfterSelection(testCase)
            % Disable multiselect after a multi-selection has already been
            % made.
            t = gwidgets.Table(Data=testCase.multivariableData());

            t.Selection = [2 2; 5 1];
            t.Multiselect = "off";

            testCase.verifyEqual(t.Selection, double.empty(0,2))
            testCase.verifyEqual(t.DisplaySelection, double.empty(0,2))
        end

        function tSelectionOnEmptyTable(testCase)
            t = gwidgets.Table(Data=table.empty(0,2));

            fcn = @() t.set("Selection", [1 1]);
            testCase.verifyError(fcn, "GraphicsWidgets:Table:SelectionOutsideLimits");

            testCase.verifyEqual(t.Selection, double.empty(0,2))
            testCase.verifyEqual(t.DisplaySelection, double.empty(0,2))
        end

        function tCellSelectionAcceptsTransposedPair(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());

            t.Selection = [2; 3];

            testCase.verifyEqual(t.Selection, [2 3])
            testCase.verifyEqual(t.DisplaySelection, [2 3])
        end

        function tSelectionRejectsNonnumericAndUndefinedValues(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());

            testCase.verifyError(@() t.set("Selection", "bad"), ...
                "GraphicsWidgets:Table:UnsupportedSelectionSize")
            testCase.verifyError(@() t.set("Selection", [NaN 1]), ...
                "GraphicsWidgets:Table:UnsupportedSelection")
            testCase.verifyError(@() t.set("Selection", [Inf 1]), ...
                "GraphicsWidgets:Table:UnsupportedSelection")
            testCase.verifyError(@() t.set("Selection", [0 1]), ...
                "GraphicsWidgets:Table:UnsupportedSelection")
        end

        function tStaticDisplayToDataMapsRowsColumnsAndMissingRows(testCase)
            state = test.unit.gwidgets.Table.tSelection.mappingState();

            cellIdx = gwidgets.internal.table.SelectionController.displayToDataStatic([1 1; 2 2], "cell", state);
            rowIdx = gwidgets.internal.table.SelectionController.displayToDataStatic([1 3], "row", state);
            columnIdx = gwidgets.internal.table.SelectionController.displayToDataStatic([1 2], "column", state);

            testCase.verifyEqual(cellIdx, [1 1])
            testCase.verifyEqual(rowIdx, [1 3])
            testCase.verifyEqual(columnIdx, [1 2])
        end

        function tStaticDataToDisplayMapsRowsColumnsAndHiddenColumns(testCase)
            state = test.unit.gwidgets.Table.tSelection.mappingState();

            cellIdx = gwidgets.internal.table.SelectionController.dataToDisplayStatic([1 1; 3 2], "cell", state);
            rowIdx = gwidgets.internal.table.SelectionController.dataToDisplayStatic([1 3], "row", state);
            columnIdx = gwidgets.internal.table.SelectionController.dataToDisplayStatic([1 3], "column", state);

            testCase.verifyEqual(cellIdx, [1 1; 3 2])
            testCase.verifyEqual(rowIdx, [1 3])
            testCase.verifyEqual(columnIdx, 1)
        end

        function tStaticDataToDisplayHandlesEmptyFoldedMap(testCase)
            state = test.unit.gwidgets.Table.tSelection.mappingState();
            state.FoldedDataToVisibleMap = [];

            cellIdx = gwidgets.internal.table.SelectionController.dataToDisplayStatic([1 1], "cell", state);
            rowIdx = gwidgets.internal.table.SelectionController.dataToDisplayStatic(1, "row", state);
            columnIdx = gwidgets.internal.table.SelectionController.dataToDisplayStatic(2, "column", state);

            testCase.verifyEqual(cellIdx, zeros(0,2))
            testCase.verifyEqual(rowIdx, zeros(1,0))
            testCase.verifyEqual(columnIdx, 2)
        end

        function tStaticDisplayToDataDropsUnknownColumns(testCase)
            state = test.unit.gwidgets.Table.tSelection.mappingState();
            state.VisibleColumnNames = ["A", "Ghost"];
            state.VisibleDataColumnNames = ["A", "Ghost"];

            columnIdx = gwidgets.internal.table.SelectionController.displayToDataStatic(2, "column", state);

            testCase.verifyEqual(columnIdx, zeros(1,0))
        end

        function tStaticDataToDisplayTableSelection(testCase)
            state = test.unit.gwidgets.Table.tSelection.mappingState();

            testCase.verifyError( ...
                @()gwidgets.internal.table.SelectionController.dataToDisplayStatic([1 3], "table", state), ...
                "GraphicsWidgets:Table:SelectionOutOfRange")
        end

        function tStaticDataToDisplayRejectsOutOfRangeSelections(testCase)
            state = test.unit.gwidgets.Table.tSelection.mappingState();

            testCase.verifyError( ...
                @()gwidgets.internal.table.SelectionController.dataToDisplayStatic(4, "row", state), ...
                "GraphicsWidgets:Table:SelectionOutOfRange")
            testCase.verifyError( ...
                @()gwidgets.internal.table.SelectionController.dataToDisplayStatic(4, "column", state), ...
                "GraphicsWidgets:Table:SelectionOutOfRange")
        end

        function tChangeSupportedSelectionTypes(testCase)
            % Change supported selection types after making a selection
            % with the previously supported type.
            t = gwidgets.Table(Data=testCase.multivariableData());
            t.Selection = [2 2];

            t.SupportedSelectionTypes = ["row", "cell"];

            testCase.verifyEqual(t.Selection, [2 2]);
            testCase.verifyEqual(t.DisplaySelection, [2 2]);

            t.SupportedSelectionTypes = ["row", "column"];
            testCase.verifyEqual(t.SelectionType, 'row')
            testCase.verifyEqual(t.Selection, double.empty(1,0));
            testCase.verifyEqual(t.DisplaySelection, double.empty(1,0));

            t.Selection = 2;

            t.SupportedSelectionTypes = "cell";
            testCase.verifyEqual(t.SelectionType, 'cell')
            testCase.verifyEqual(t.Selection, double.empty(0,2));
            testCase.verifyEqual(t.DisplaySelection, double.empty(0,2));
        end

        function tEditDataAfterSelecting(testCase)
            data = testCase.multivariableData();
            t = gwidgets.Table(Data=data);
            t.Selection = [2 2];

            newdata = [data; data];
            newdata.Properties.VariableNames{1} = 'Number';
            newdata.Logical = repelem(false, 10, 1);

            testCase.verifyEqual(t.Selection, [2 2])
            testCase.verifyEqual(t.DisplaySelection, [2 2])
        end

    end

    methods (Static, Access = private)
        function state = mappingState()
            state = struct( ...
                "FoldedVisibleToDataMap", [1 NaN 3], ...
                "FoldedDataToVisibleMap", [1 NaN 3], ...
                "FilteredDataToVisibleMap", [1 2 3], ...
                "VisibleColumnNames", ["A", "Group", "B"], ...
                "VisibleDataColumnNames", ["A", "Group", "B"], ...
                "DataColumnNames", ["A", "B", "Hidden"], ...
                "GroupingVariable", "Group", ...
                "DataWidth", 3);
        end
    end

end
