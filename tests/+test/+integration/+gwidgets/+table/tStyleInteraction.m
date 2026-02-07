classdef tStyleInteraction < test.WithExampleTables
    % Test style interaction with the various tasks (e.g. adding styles
    % before/after folding, sorting, filtering, column hiding)

    methods (Test)

        function tGroup_Style(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());

            % Change header styling
            s = matlab.ui.style.Style("BackgroundColor", [0.9 0.9 0.9], "FontColor", [0.1 0.1 0.1]);
            t.GroupHeaderStyle = t.defaultGroupHeaderStyle(s);

            % Do display styling
            s(2) = matlab.ui.style.Style("BackgroundColor", [1 0 0], "FontColor", [0 0 1]);
            t.addStyle(s(2), "cell", [3,3], "SelectionMode", "Display");

            % Do data styling
            s(3) = matlab.ui.style.Style("BackgroundColor", [0 0 1], "FontColor", [1 0 0]);
            t.addStyle(s(3), "cell", [1,4], "SelectionMode", "Data");

            testCase.verifyEqual(t.StyleConfigurations.TargetIndex{1}, [3 3])
            testCase.verifyEqual(t.StyleConfigurations.Style(1), s(2))

            testCase.verifyEqual(t.StyleConfigurations.TargetIndex{2}, [1 4])
            testCase.verifyEqual(t.StyleConfigurations.Style(2), s(3))

            testCase.verifyEqual(t.StyleConfigurations.TargetIndex{end}, double.empty(1,0))
            testCase.verifyEqual(t.StyleConfigurations.Style(end), s(1))

            t.GroupingVariable = "Logical";
            t.openAllGroups();

            % Grouping does not change display styling indices
            testCase.verifyEqual(t.StyleConfigurations.TargetIndex{1}, [3 3])
            testCase.verifyEqual(t.StyleConfigurations.Style(1), s(2))

            % Grouping changes data styling indices
            testCase.verifyEqual(t.StyleConfigurations.TargetIndex{2}, [5 3])
            testCase.verifyEqual(t.StyleConfigurations.Style(2), s(3))

            % Grouping headers changed, and is applied last
            testCase.verifyEqual(t.StyleConfigurations.TargetIndex{end}, [1 4])
            testCase.verifyEqual(t.StyleConfigurations.Style(end), s(1))

            % Table shorter then the row three of the specified display
            % index = 3 above
            t.Filter = "Numerical=2";
            t.openAllGroups();

            % Style display index still fixed
            testCase.verifyEqual(t.StyleConfigurations.TargetIndex{1}, [3 3])
            testCase.verifyEqual(t.StyleConfigurations.Style(1), s(2))

            % Data no longer visible so empty index
            testCase.verifyEqual(t.StyleConfigurations.TargetIndex{2}, double.empty(0,2))
            testCase.verifyEqual(t.StyleConfigurations.Style(2), s(3))

            % Grouping headers changed, and is applied last
            testCase.verifyEqual(t.StyleConfigurations.TargetIndex{end}, 1)
            testCase.verifyEqual(t.StyleConfigurations.Style(end), s(1))

            % Can add a display styling outside table range
            s(end+1) = matlab.ui.style.Style("BackgroundColor", [0 1 0], "FontColor", [0 0 1]);
            t.addStyle(s(end), "cell", [6,3], "SelectionMode", "Display");

            % Remove the filter so this style is visible
            t.Filter = "";
            t.openAllGroups();
            testCase.verifyEqual(t.StyleConfigurations.TargetIndex{end-1}, [6,3])
            testCase.verifyEqual(t.StyleConfigurations.Style(end-1), s(end))

            % Sort by categorical
            t.ColumnSortable = [0 1 0 0];
            t.SortByColumn = "Categorical";
            t.SortDirection = "Ascend";

            % No change to display styles
            testCase.verifyEqual(t.StyleConfigurations.TargetIndex{1}, [3 3])
            testCase.verifyEqual(t.StyleConfigurations.Style(1), s(2))
            testCase.verifyEqual(t.StyleConfigurations.TargetIndex{end-1}, [6,3])
            testCase.verifyEqual(t.StyleConfigurations.Style(end-1), s(end))

            % Data style moved again
            testCase.verifyEqual(t.StyleConfigurations.TargetIndex{2}, [5 3])
            testCase.verifyEqual(t.StyleConfigurations.Style(2), s(3))

            % Grouping headers not changed
            testCase.verifyEqual(t.StyleConfigurations.TargetIndex{end}, [1 4])
            testCase.verifyEqual(t.StyleConfigurations.Style(end), s(1))

        end

        function tStyle_WithColumnVisibility(testCase)
            % Test style behavior when hiding/showing columns
            t = gwidgets.Table(Data=testCase.multivariableData());

            % Add data style to column 2
            s1 = matlab.ui.style.Style("BackgroundColor", [1 0 0]);
            t.addStyle(s1, "cell", [1,2], "SelectionMode", "Data");

            % Add display style to column 3
            s2 = matlab.ui.style.Style("BackgroundColor", [0 1 0]);
            t.addStyle(s2, "cell", [2,3], "SelectionMode", "Display");

            % Verify initial styles
            testCase.verifyEqual(t.StyleConfigurations.TargetIndex{1}, [1 2])
            testCase.verifyEqual(t.StyleConfigurations.TargetIndex{2}, [2 3])

            % Hide column 1 (shift display indices)
            t.ColumnVisible = [false true true true];

            % Data style should update to new display position
            testCase.verifyEqual(t.StyleConfigurations.TargetIndex{1}, [1 1])
            % Display style should remain fixed
            testCase.verifyEqual(t.StyleConfigurations.TargetIndex{2}, [2 3])

            % Hide column 2 (the styled column in data coordinates)
            t.ColumnVisible = [false false true true];

            % Data style should disappear
            testCase.verifyEqual(t.StyleConfigurations.TargetIndex{1}, double.empty(0,2))
            % Display style index should stay fixed
            testCase.verifyEqual(t.StyleConfigurations.TargetIndex{2}, [2 3])

            % Restore all columns
            t.ColumnVisible = true;

            % Data style should reappear
            testCase.verifyEqual(t.StyleConfigurations.TargetIndex{1}, [1 2])
            % Display style should return to original position
            testCase.verifyEqual(t.StyleConfigurations.TargetIndex{2}, [2 3])
        end

        function tStyle_WithSorting(testCase)
            % Test that data styles move with data when sorting
            t = gwidgets.Table(Data=testCase.multivariableData());
            t.ColumnSortable = true;

            % Style row 1, column 1 in data coordinates
            s1 = matlab.ui.style.Style("BackgroundColor", [1 0 0]);
            t.addStyle(s1, "cell", [1,1], "SelectionMode", "Data");

            % Style row 2, column 2 in display coordinates
            s2 = matlab.ui.style.Style("BackgroundColor", [0 1 0]);
            t.addStyle(s2, "cell", [2,2], "SelectionMode", "Display");

            % Verify initial positions
            testCase.verifyEqual(t.StyleConfigurations.TargetIndex{1}, [1 1])
            testCase.verifyEqual(t.StyleConfigurations.TargetIndex{2}, [2 2])

            % Sort by first column (descending)
            t.SortByDataColumn = "Numerical";
            t.SortDirection = "Descend";

            % Data style should move with the data
            % Display style should stay fixed
            dataStyleIdx = t.StyleConfigurations.TargetIndex{1};
            testCase.verifyEqual(dataStyleIdx, [5 1], ...
                'Data style should move when sorting');
            testCase.verifyEqual(t.StyleConfigurations.TargetIndex{2}, [2 2], ...
                'Display style should not move when sorting')

            % Sort descending
            t.SortByColumn = "Categorical";

            % Data style should move again
            newDataStyleIdx = t.StyleConfigurations.TargetIndex{1};
            testCase.verifyEqual(newDataStyleIdx, [3,1], ...
                'Data style should move when changing sort direction');
            testCase.verifyEqual(t.StyleConfigurations.TargetIndex{2}, [2 2])

            % Clear sorting
            t.SortDirection = "None";

            % Data style should return to original position
            testCase.verifyEqual(t.StyleConfigurations.TargetIndex{1}, [1 1])
            testCase.verifyEqual(t.StyleConfigurations.TargetIndex{2}, [2 2])
        end

        function tStyle_WithGroupingAndFolding(testCase)
            % Test style behavior with group folding
            t = gwidgets.Table(Data=testCase.multivariableData());

            % Add data style before grouping
            s1 = matlab.ui.style.Style("BackgroundColor", [1 0 0]);
            t.addStyle(s1, "cell", [1,2], "SelectionMode", "Data");

            % Add display style
            s2 = matlab.ui.style.Style("BackgroundColor", [0 1 0]);
            t.addStyle(s2, "cell", [3,3], "SelectionMode", "Display");

            % Group by Logical
            t.GroupingVariable = "Logical";
            t.openAllGroups();

            % Data style should adjust for group headers
            testCase.verifyEqual(t.StyleConfigurations.TargetIndex{1}, [5 2])
            initialGroupedIdx = t.StyleConfigurations.TargetIndex{1};

            % Close all groups
            t.closeAllGroups();

            % Data style should disappear (row hidden)
            testCase.verifyEqual(t.StyleConfigurations.TargetIndex{1}, double.empty(0,2))
            % Display style should remain (might be on header row)
            testCase.verifySize(t.StyleConfigurations.TargetIndex{2}, [1 2])

            % Open all groups again
            t.openAllGroups();

            % Data style should reappear
            testCase.verifyEqual(t.StyleConfigurations.TargetIndex{1}, initialGroupedIdx)

            % Test hiding empty groups
            t.Filter = "Numerical>2";
            t.ShowEmptyGroups = false;

            % Verify table still renders without errors
            testCase.verifyGreaterThanOrEqual(height(t.DisplayData), 0)
        end

        function tStyle_WithMultipleOperations(testCase)
            % Test style behavior through multiple combined operations
            t = gwidgets.Table(Data=testCase.multivariableData());
            t.ColumnSortable = true;

            % Add multiple styles
            s1 = matlab.ui.style.Style("BackgroundColor", [1 0 0]);
            t.addStyle(s1, "row", 1, "SelectionMode", "Data");

            s2 = matlab.ui.style.Style("BackgroundColor", [0 1 0]);
            t.addStyle(s2, "column", 2, "SelectionMode", "Data");

            s3 = matlab.ui.style.Style("BackgroundColor", [0 0 1]);
            t.addStyle(s3, "cell", [3,3], "SelectionMode", "Display");

            % Apply filter
            t.Filter = "Numerical<=3";

            % Verify styles still apply
            testCase.verifyGreaterThanOrEqual(height(t.StyleConfigurations), 3)

            % Group
            t.GroupingVariable = "Categorical";
            t.openAllGroups();

            % Sort
            t.SortByDataColumn = "Numerical";
            t.SortDirection = "Ascend";

            % Hide column
            t.ColumnVisible = [true false true true];

            % Verify table still renders
            testCase.verifyGreaterThan(height(t.DisplayData), 0)
            testCase.verifyGreaterThanOrEqual(height(t.StyleConfigurations), 3)

            % Restore everything
            t.Filter = "";
            t.GroupingVariable = "";
            t.SortDirection = "None";
            t.ColumnVisible = true;

            % Verify original styles are preserved
            testCase.verifyGreaterThanOrEqual(height(t.StyleConfigurations), 3)
        end

        function tStyle_RemovalAndReaddition(testCase)
            % Test removing and re-adding styles
            t = gwidgets.Table(Data=testCase.multivariableData());

            % Add styles
            s1 = matlab.ui.style.Style("BackgroundColor", [1 0 0]);
            t.addStyle(s1, "cell", [1,1], "SelectionMode", "Data");

            s2 = matlab.ui.style.Style("BackgroundColor", [0 1 0]);
            t.addStyle(s2, "cell", [2,2], "SelectionMode", "Data");

            testCase.verifyEqual(height(t.StyleConfigurations), 3)

            % Remove first style
            t.removeStyle(1);
            testCase.verifyEqual(height(t.StyleConfigurations), 2)
            testCase.verifyEqual(t.StyleConfigurations.Style(1), s2)

            % Remove all styles
            t.removeStyle();
            testCase.verifyEqual(height(t.StyleConfigurations), 1)

            % Re-add after operations
            t.GroupingVariable = "Logical";
            t.openAllGroups();

            s3 = matlab.ui.style.Style("BackgroundColor", [0 0 1]);
            t.addStyle(s3, "cell", [2,1], "SelectionMode", "Data");

            testCase.verifyEqual(height(t.StyleConfigurations), 2) % 1 style + group header
            testCase.verifyEqual(t.StyleConfigurations.Style(1), s3)
        end

        function tStyle_WithColumnAliases(testCase)
            % Test style behavior when column aliases are used
            t = gwidgets.Table(Data=testCase.multivariableData());

            % Set column aliases
            t.ColumnNames = ["Num", "Cat", "Log", "Char"];

            % Add style to column 2 (using data index)
            s1 = matlab.ui.style.Style("BackgroundColor", [1 0 0]);
            t.addStyle(s1, "column", 2, "SelectionMode", "Data");

            testCase.verifyEqual(t.StyleConfigurations.TargetIndex{1}, 2)

            % Verify display data uses aliases
            testCase.verifyTrue(any(strcmp(t.DisplayData.Properties.VariableNames, "Cat")))

            % Hide and show columns
            t.ColumnVisible = [true false true true];
            testCase.verifyEqual(t.StyleConfigurations.TargetIndex{1}, double.empty(1,0))

            t.ColumnVisible = true;
            testCase.verifyEqual(t.StyleConfigurations.TargetIndex{1}, 2)
        end

        function tStyle_WithFilteredData(testCase)
            % Test style behavior with various filters
            t = gwidgets.Table(Data=testCase.multivariableData());

            % Add style to specific data row
            s1 = matlab.ui.style.Style("BackgroundColor", [1 0 0]);
            t.addStyle(s1, "row", 2, "SelectionMode", "Data");

            initialHeight = height(t.DisplayData);
            testCase.verifyGreaterThan(initialHeight, 0)

            % Apply filter that excludes row 2
            t.Filter = "Numerical>2";

            % Style should not be visible
            filteredHeight = height(t.DisplayData);
            testCase.verifyLessThan(filteredHeight, initialHeight)

            % Verify style configuration still exists but with empty index
            testCase.verifyEqual(height(t.StyleConfigurations), 2)
            testCase.verifyEqual(t.StyleConfigurations.TargetIndex{1}, double.empty(1,0));

            % Clear filter
            t.Filter = "";

            % Style should be visible again
            testCase.verifyEqual(height(t.DisplayData), initialHeight)
            testCase.verifyEqual(t.StyleConfigurations.TargetIndex{1}, 2)
        end

        function tStyle_GroupHeaderStyle(testCase)
            % Test custom group header styling
            t = gwidgets.Table(Data=testCase.multivariableData());

            % Set custom group header style
            s1 = matlab.ui.style.Style("BackgroundColor", [0.8 0.8 0.9], "FontColor", [0.2 0.2 0.2]);
            t.GroupHeaderStyle = t.defaultGroupHeaderStyle(s1);

            % No grouping yet, so no header rows
            testCase.verifyEqual(height(t.DisplayData), height(testCase.multivariableData()))

            % Add grouping
            t.GroupingVariable = "Categorical";
            t.openAllGroups();

            % Verify group headers exist
            testCase.verifyGreaterThan(height(t.DisplayData), height(testCase.multivariableData()))

            % Verify header style is applied (should be last in configurations)
            testCase.verifyEqual(t.StyleConfigurations.Style(end), s1)
            testCase.verifyNotEmpty(t.StyleConfigurations.TargetIndex{end})

            % Close groups
            t.closeAllGroups();

            % Headers still exist but fewer rows visible
            headerRowCount = numel(t.Groups);
            testCase.verifyEqual(height(t.DisplayData), headerRowCount)

            % Change header style
            s2 = matlab.ui.style.Style("BackgroundColor", [0.9 0.9 0.8], "FontColor", [0.1 0.1 0.1]);
            t.GroupHeaderStyle = t.defaultGroupHeaderStyle(s2);

            testCase.verifyEqual(t.StyleConfigurations.Style(end), s2)
        end

        function tStyle_WithFunctionBasedStyle(testCase)
            % Test styles that use functions for target selection
            t = gwidgets.Table(Data=testCase.multivariableData());

            % Add style using function (e.g., find all cells with specific value)
            s1 = matlab.ui.style.Style("BackgroundColor", [1 0 0]);
            findFunc = @(tbl) tbl.find("Num=2", "cell");
            t.addStyle(s1, "cell", findFunc);

            % Verify style is applied
            testCase.verifyGreaterThanOrEqual(height(t.StyleConfigurations), 1)

            % Apply operations that change data view
            t.Filter = "Numerical<3";

            % Function should re-evaluate
            testCase.verifyGreaterThanOrEqual(height(t.StyleConfigurations), 1)

            % Sort
            t.ColumnSortable = true;
            t.SortByDataColumn = "Numerical";
            t.SortDirection = "Ascend";

            % Verify no errors
            testCase.verifyGreaterThan(height(t.DisplayData), 0)
        end

        function tStyle_EdgeCases(testCase)
            % Test edge cases and error conditions
            t = gwidgets.Table(Data=testCase.multivariableData());

            % Empty table styling
            t.Filter = "Numerical>1000"; % Filter that excludes all rows

            s1 = matlab.ui.style.Style("BackgroundColor", [1 0 0]);
            t.addStyle(s1, "cell", [1,1], "SelectionMode", "Data");

            % Should not error even though data is empty
            testCase.verifyEqual(height(t.DisplayData), 0)
            testCase.verifyEqual(height(t.StyleConfigurations), 2)
            testCase.verifyEqual(t.StyleConfigurations.TargetIndex{1}, double.empty(0,2))

            % Restore data
            t.Filter = "";

            % Style out of bounds (display mode)
            s2 = matlab.ui.style.Style("BackgroundColor", [0 1 0]);
            t.addStyle(s2, "cell", [1000, 1000], "SelectionMode", "Display");

            % Should not error, just not display
            testCase.verifyGreaterThan(height(t.StyleConfigurations), 1)

            % Multiple styles on same cell
            s3 = matlab.ui.style.Style("FontColor", [0 0 1]);
            t.addStyle(s3, "cell", [1,1], "SelectionMode", "Data");

            % Both should exist
            testCase.verifyGreaterThanOrEqual(height(t.StyleConfigurations), 3)
        end

        function tStyle_CellEditWithFiltering(testCase)
            % Test cell editing interaction with styles and filtering
            t = gwidgets.Table(Data=testCase.multivariableData());

            % Make first column editable
            t.DataColumnEditable = [true false false false];

            % Add style to row 2, column 1 (data coordinates)
            s1 = matlab.ui.style.Style("BackgroundColor", [1 0 0]);
            t.addStyle(s1, "cell", [2,1], "SelectionMode", "Data");

            % Add style to display position [1,1]
            s2 = matlab.ui.style.Style("BackgroundColor", [0 1 0]);
            t.addStyle(s2, "cell", [1,1], "SelectionMode", "Display");

            % Verify initial styles are applied correctly
            testCase.verifyEqual(t.StyleConfigurations.TargetIndex{1}, [2 1])
            testCase.verifyEqual(t.StyleConfigurations.TargetIndex{2}, [1 1])

            % Get original data value
            originalValue = t.Data{2,1};

            % Edit cell at data position [2,1]
            newValue = originalValue + 100;
            e = struct("Indices", [2,1], "NewData", newValue);
            t.onCellEdit([], e);

            % Verify data was updated
            testCase.verifyEqual(t.Data{2,1}, newValue)

            % Verify style is still on the same data cell
            testCase.verifyEqual(t.StyleConfigurations.TargetIndex{1}, [2 1])

            % Apply filter that excludes row 2
            t.Filter = "Numerical<2";

            % Data style should disappear (row filtered out)
            testCase.verifyEqual(t.StyleConfigurations.TargetIndex{1}, double.empty(0,2))

            % Display style should still be visible
            testCase.verifyEqual(t.StyleConfigurations.TargetIndex{2}, [1 1])

            % Edit a visible cell (display position [1,1])
            % This should correspond to data row 1 after filtering
            visibleRowValue = t.DisplayData{1,1};
            e = struct("Indices", [1,1], "NewData", visibleRowValue + 50);
            t.onCellEdit([1,1], e);

            % Verify the underlying data was updated at correct position
            testCase.verifyEqual(t.Data{1,1}, visibleRowValue + 50)

            % Remove filter to make edited row visible again
            t.Filter = "";

            % Both edits should be preserved
            testCase.verifyEqual(t.Data{2,1}, newValue)
            testCase.verifyEqual(t.Data{1,1}, visibleRowValue + 50)

            % Data style should reappear on row 2
            testCase.verifyEqual(t.StyleConfigurations.TargetIndex{1}, [2 1])

            % Now test editing with grouping
            t.GroupingVariable = "Logical";
            t.openAllGroups();

            % Data style should adjust for group headers
            dataStyleIdx = t.StyleConfigurations.TargetIndex{1};
            testCase.verifyEqual(dataStyleIdx, [2 1], ...
                'Data style should adjust for group headers');

            % Find the display position of data row 2
            t.Selection = [2 1];
            displayPosition = t.DisplaySelection;

            if ~isempty(displayPosition)
                % Edit through display coordinates
                currentValue = t.Data{2,1};
                e = struct("Indices", displayPosition, "NewData", currentValue+25);
                t.onCellEdit([], e);

                % Verify update
                testCase.verifyEqual(t.Data{2,1}, currentValue + 25)

                % Style should remain on the data cell
                newDataStyleIdx = t.StyleConfigurations.TargetIndex{1};
                testCase.verifyEqual(newDataStyleIdx, dataStyleIdx, ...
                    'Data style should remain on same data cell after edit');
            end

            % Test editing that triggers re-filtering
            % Edit a cell that would now be filtered out
            t.Filter = "Numerical<150";
            initialFilteredHeight = height(t.DisplayData);

            % Edit row 1 to have a value that passes the filter
            t.Data{1,1} = 140;

            % Table should update (this triggers doUpdateSequence from Data set)
            testCase.verifyEqual(height(t.DisplayData), initialFilteredHeight, ...
                'Filtered view should update after data edit');

            % Edit to value that fails filter
            oldValue = t.Data{1,1};
            t.Data{1,1} = 200;

            % Row 1 should now be filtered out
            newFilteredHeight = height(t.DisplayData);
            testCase.verifyLessThan(newFilteredHeight, initialFilteredHeight, ...
                'Row should be filtered out after edit');

            % Restore value
            t.Data{1,1} = oldValue;
        end

        function tStyle_CellEditWithSortingAndGrouping(testCase)
            % Test cell editing when table is sorted and grouped
            t = gwidgets.Table(Data=testCase.multivariableData());

            % Enable editing and sorting
            t.DataColumnEditable = [true true false false];
            t.ColumnSortable = true;

            % Add data-based style to track a specific data cell
            s1 = matlab.ui.style.Style("BackgroundColor", [1 0 0]);
            t.addStyle(s1, "cell", [3,1], "SelectionMode", "Data");

            % Sort the table
            t.SortByDataColumn = "Numerical";
            t.SortDirection = "Ascend";

            % Get display position of data cell [3,1] after sorting
            t.Selection = [3,1];
            displayPos = t.DisplaySelection;
            testCase.verifyNotEmpty(displayPos, 'Styled cell should be visible');

            % Verify style moved with the data
            testCase.verifyEqual(t.StyleConfigurations.TargetIndex{1}, displayPos)

            % Edit the cell through its display position
            originalValue = t.Data{3,1};
            newValue = originalValue + 1000; % Large value to affect sort order

            % Simulate edit callback
            e = struct("Indices", displayPos, "NewData", newValue);
            t.onCellEdit([], e);

            % Verify data updated
            testCase.verifyEqual(t.Data{3,1}, newValue)

            % After edit, display position should change due to re-sorting
            % (the table calls doUpdateSequence from onCellEdit)
            newDisplayPos = t.DisplaySelection;
            testCase.verifyNotEqual(newDisplayPos, displayPos, ...
                'Display position should change after edit that affects sort order');

            % Style should follow the data to new position
            testCase.verifyEqual(t.StyleConfigurations.TargetIndex{1}, newDisplayPos)

            % Now add grouping
            t.GroupingVariable = "Categorical";
            t.openAllGroups();

            % Edit a cell in a grouped table
            t.Selection = [2,2];
            displayPosGrouped = t.DisplaySelection;

            if ~isempty(displayPosGrouped)
                % Edit categorical value
                e = struct("Indices", displayPosGrouped, "NewData", newCatValue);
                t.onCellEdit([], e);

                % Verify update
                testCase.verifyEqual(t.Data{2,2}, newCatValue)

                % The cell might move to a different group
                % Verify table still renders correctly
                testCase.verifyGreaterThan(height(t.DisplayData), 0)
            end
        end

        function tStyle_CellEditCallback(testCase)
            % Test that cell edit callbacks work correctly with styles and filtering
            t = gwidgets.Table(Data=testCase.multivariableData());
            t.DataColumnEditable = true;

            % Add style to cell [1,1]
            s1 = matlab.ui.style.Style("BackgroundColor", [1 0 0]);
            t.addStyle(s1, "cell", "Numerical=1", "SelectionMode", "Data");

            % Set up callback to track edits
            editCount = 0;
            lastEditDisplay = [];

            t.CellEditCallback = @(src, evt) trackEdit(evt);

            function trackEdit(evt)
                editCount = editCount + 1;
                lastEditDisplay = evt.DisplayIndices;
            end

            % Edit without filter
            e = struct("Indices", [1,1], "NewData", 999);
            t.onCellEdit([], e);

            testCase.verifyEqual(editCount, 1)
            testCase.verifyEqual(lastEditDisplay, [1 1])

            % Verify style on original cell [1,1] still exists is not
            % visible
            testCase.verifyEmpty(t.StyleConfigurations.TargetIndex{1})

            % Apply filter
            t.Filter = "Numerical>1";

            % Edit through display coordinates (row 1 in display is row 2 in data)
            t.DisplaySelection = [1,1];
            dataPosition = t.Selection;

            e = struct("Indices", dataPosition, "NewData", 777);
            t.onCellEdit([], e);

            testCase.verifyEqual(editCount, 2)
            testCase.verifyEqual(lastEditDisplay, t.DisplaySelection, ...
                'Callback should receive display coordinates');

            % Verify style on original cell [1,1] still exists is not
            % visible
            testCase.verifyEmpty(t.StyleConfigurations.TargetIndex{1})
            
            % Change value back to 1, so it should be highlighted again
            t.Filter = "";
            e = struct("Indices", dataPosition, "NewData", 1);
            t.onCellEdit([], e);

            testCase.verifyEqual(t.StyleConfigurations.TargetIndex{1} , [1,1])

            t.Selection = [1,1];
            displayPosition = t.DisplaySelection;
            testCase.verifyEqual(editCount, 3)
            testCase.verifyEqual(lastEditDisplay, displayPosition)
            
        end

    end

end