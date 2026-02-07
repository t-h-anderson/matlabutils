classdef tSelectionMapping < test.WithExampleTables
    % Selection mapping under different combinations of tasks.
    
    methods (Test)
        
        function tFilter_Select(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());
            t.Filter = "Numerical>2"; % leaves rows 3, 4, 5
            
            % Test data selection to display selection mapping
            t.SelectionType = "cell";
            t.Selection = [3 1; 5 2]; % Select data rows 3 and 5
            testCase.verifyEqual(t.DisplaySelection, [1 1; 3 2]) % Maps to display rows 1 and 3
            
            % Test display selection to data selection mapping
            t.DisplaySelection = [2 1]; % Select display row 2
            testCase.verifyEqual(t.Selection, [4 1]) % Maps to data row 4
            
            % Test row selection
            t.SelectionType = "row";
            t.Selection = [3 4 5];
            testCase.verifyEqual(t.DisplaySelection, [1 2 3])
            
            t.DisplaySelection = 2;
            testCase.verifyEqual(t.Selection, 4)
            
            % Test column selection (unaffected by row filtering)
            t.SelectionType = "column";
            t.Selection = [1 3];
            testCase.verifyEqual(t.DisplaySelection, [1 3])
            
            % Test selection of filtered-out row returns empty
            t.SelectionType = "cell";
            t.Selection = [1 1]; % Row 1 is filtered out
            testCase.verifyEqual(t.DisplaySelection, zeros(0,2))
        end
        
        function tGroup_Select(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());
            t.GroupingVariable = "Categorical"; % results in 2 groups (a, b)
            t.openAllGroups();
            
            % DisplayData has group headers, so indices shift
            % Group 'a': header at display row 1, data at 2,3,4
            % Group 'b': header at display row 5, data at 6,7
            
            t.SelectionType = "cell";
            t.Selection = [1 1]; % Data row 1
            testCase.verifyEqual(t.DisplaySelection, [2 1]) % Display row 2 (after header)
            
            t.Selection = [2 1; 3 3]; % Data rows 2 and 3
            testCase.verifyEqual(t.DisplaySelection, [6 1; 7 2]) % After both group headers
            
            % Test display to data mapping
            t.DisplaySelection = [4 1]; % Display row 4
            testCase.verifyEqual(t.Selection, [5 1]) % Maps to data row 5
            
            % Test row selection
            t.SelectionType = "row";
            t.Selection = [1 4 5];
            testCase.verifyEqual(t.DisplaySelection, [2 3 4])
            
            % Selecting a group header row should not map to data
            t.DisplaySelection = [1 5]; % Group headers
            testCase.verifyEqual(t.Selection, zeros(1,0)) % No data rows selected
        end
        
        function tSort_Select(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());
            t.SortDirection = "Descend";
            t.ColumnSortable = true;
            t.SortByColumn = "Numerical";
            
            % After sorting: display order is [5,4,3,2,1]
            t.SelectionType = "cell";
            t.Selection = [1 1]; % Data row 1 (lowest numerical value)
            testCase.verifyEqual(t.DisplaySelection, [5 1]) % Now at bottom of display
            
            t.Selection = [5 2]; % Data row 5 (highest numerical value)
            testCase.verifyEqual(t.DisplaySelection, [1 2]) % Now at top of display
            
            % Test multiple selections
            t.Selection = [1 1; 3 1; 5 1];
            testCase.verifyEqual(t.DisplaySelection, [5 1; 3 1; 1 1])
            
            % Test display to data mapping
            t.DisplaySelection = [1 1; 2 1]; % Top two display rows
            testCase.verifyEqual(t.Selection, [5 1; 4 1]) % Maps to data rows 5,4
            
            % Test row selection
            t.SelectionType = "row";
            t.Selection = [2 3 4];
            testCase.verifyEqual(t.DisplaySelection, [4 3 2]) % Reverse order in display
        end
        
        function tFold_Select(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());
            t.GroupingVariable = "String"; % results in 2 groups (x, y)
            t.OpenGroups = "x"; % Only 'x' group is open
            
            % Group 'x' has data rows 2,3,4 (3 items)
            % Group 'y' has data rows 1,5 (2 items) - FOLDED
            
            t.SelectionType = "cell";
            t.Selection = [2 1]; % Data row 2 (in open group 'x')
            testCase.verifyEqual(t.DisplaySelection, [2 1]) % Visible at display row 2
            
            t.Selection = [1 1]; % Data row 1 (in folded group 'y')
            testCase.verifyEqual(t.DisplaySelection, zeros(0,2)) % Not visible
            
            % Multiple selections - some visible, some not
            t.Selection = [2 1; 3 1; 1 1; 5 2];
            testCase.verifyEqual(t.DisplaySelection, [2 1; 3 1]) % Only visible ones
            
            % Open all groups and verify selection becomes visible
            t.Selection = [1 1; 5 1];
            testCase.verifyEqual(t.DisplaySelection, zeros(0,2)) % Both in folded group
            
            t.openAllGroups();
            testCase.verifyEqual(t.DisplaySelection, [6 1; 7 1]) % Now visible
            
            % Test row selection with folding
            t.closeAllGroups();
            t.SelectionType = "row";
            t.Selection = [1 2 3];
            testCase.verifyEqual(t.DisplaySelection, zeros(1,0)) % All folded
            
            t.OpenGroups = "x";
            testCase.verifyEqual(t.DisplaySelection, [2 3]) % Only rows in 'x' group visible
        end
        
        function tEditData_Select(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());
            t.SelectionType = "cell";
            t.Selection = [2 1; 4 2];
            
            % Verify initial selection
            testCase.verifyEqual(t.DisplaySelection, [2 1; 4 2])
            
            % Edit data - selection should persist if indices still valid
            t.Data.Numerical(3) = 100;
            testCase.verifyEqual(t.Selection, [2 1; 4 2]) % Unchanged
            testCase.verifyEqual(t.DisplaySelection, [2 1; 4 2]) % Unchanged
            
            % Add rows - selection should still be valid
            newRow = {6, categorical("c"), true, "z"};
            t.Data = [t.Data; newRow];
            testCase.verifyEqual(t.Selection, [2 1; 4 2]) % Still valid
            
            % With filtering enabled
            t.Filter = "Numerical<5"; % Filters out row with value 100
            t.Selection = [1 1; 2 1]; % Data rows 1,2 (both pass filter)
            testCase.verifyEqual(t.DisplaySelection, [1 1; 2 1])
            
            % Edit filtered row - should trigger update
            t.Data.Numerical(1) = 200; % Now filtered out
            testCase.verifySize(t.DisplaySelection, [1 2]) % Only row 2 remains visible
            
            % With grouping - edit that changes group membership
            t.Filter = "";
            t.GroupingVariable = "String";
            t.openAllGroups();
            t.Selection = [1 1]; % Select data row 1
            
            originalDisplay = t.DisplaySelection;
            t.Data.String(1) = "x"; % Change from 'y' to 'x' group
            % Selection should persist but display location may change
            testCase.verifyEqual(t.Selection, [1 1])
            testCase.verifyNotEqual(t.DisplaySelection, originalDisplay)
        end
        
        function tFilter_Group_Select(testCase)
            % Combined filter and group operations
            t = gwidgets.Table(Data=testCase.multivariableData());
            t.Filter = "Numerical>2"; % leaves rows 3,4,5
            t.GroupingVariable = "Categorical"; % groups into a,b
            t.openAllGroups();
            
            % Group 'a' has filtered rows 4,5
            % Group 'b' has filtered row 3
            
            t.SelectionType = "cell";
            t.Selection = [3 1]; % Filtered row 3
            % Display: Group b header (row 1), then data row 3 (row 2)
            testCase.verifyEqual(t.DisplaySelection, [5 1])
            
            t.Selection = [4 1; 5 3]; % Both in group 'a'
            % Display: Group a header (row 3), then rows 4,5 (rows 4,5)
            testCase.verifyEqual(t.DisplaySelection, [2 1; 3 2])
            
            % Test with folded groups
            t.OpenGroups = "a"; % Fold group 'b'
            t.Selection = [3 1]; % In folded group 'b'
            testCase.verifyEqual(t.DisplaySelection, zeros(0,2))
            
            t.Selection = [4 1]; % In open group 'a'
            testCase.verifySize(t.DisplaySelection, [1 2])
        end
        
        function tSort_Group_Select(testCase)
            % Combined sort and group operations
            t = gwidgets.Table(Data=testCase.multivariableData());
            t.GroupingVariable = "String"; % groups x,y
            t.SortDirection = "Descend";
            t.ColumnSortable = true;
            t.SortByColumn = "Numerical";
            t.openAllGroups();
            
            % Within each group, data should be sorted
            t.SelectionType = "row";
            t.Selection = 2; % Data row 2 (Numerical=2, String=x)
            
            % Verify it's in the correct sorted position within its group
            displayRow = t.DisplaySelection;
            testCase.verifyGreaterThan(displayRow, 0)
            
            testCase.verifyNotEqual(t.DisplaySelection, t.Selection) % Position changed
            testCase.verifyEqual(t.Selection, 2) % Data selection unchanged
            testCase.verifyEqual(t.DisplaySelection, 4) % Data selection unchanged
        end
        
        function tMultiselect_Toggle(testCase)
            % Test selection behavior when toggling multiselect
            t = gwidgets.Table(Data=testCase.multivariableData());
            t.SelectionType = "cell";
            t.Multiselect = "on";
            
            % Select multiple cells
            t.Selection = [1 1; 2 2; 3 1];
            testCase.verifyEqual(t.DisplaySelection, [1 1; 2 2; 3 1])
            
            % Turn off multiselect - should clear selection
            t.Multiselect = "off";
            testCase.verifyEqual(t.Selection, zeros(0,2))
            
            % Single selection only
            t.Selection = [2 1];
            testCase.verifyEqual(t.DisplaySelection, [2 1])
        end
        
        function tSelectionType_Change(testCase)
            % Test selection clearing when selection type changes
            t = gwidgets.Table(Data=testCase.multivariableData());
            
            t.SelectionType = "cell";
            t.Selection = [1 1; 2 2];
            testCase.verifySize(t.Selection, [2 2])
            
            % Change to row selection - should clear
            t.SelectionType = "row";
            testCase.verifyEqual(t.Selection, zeros(1,0))
            
            t.Selection = [1 3 5];
            testCase.verifySize(t.Selection, [1 3])
            
            % Change to column selection - should clear
            t.SelectionType = "column";
            testCase.verifyEqual(t.Selection, zeros(1,0))
        end

        function tSort_VerifyMaps(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());
            t.SortDirection = "Descend";
            t.ColumnSortable = true;
            t.SortByColumn = "Numerical";

            % Verify maps are correct
            for i = 1:5
                visIdx = t.SortedDataToVisibleMap(i);
                if ~isnan(visIdx)
                    testCase.verifyEqual(t.SortedVisibleToDataMap(visIdx), i)
                end
            end
        end
        
    end
end