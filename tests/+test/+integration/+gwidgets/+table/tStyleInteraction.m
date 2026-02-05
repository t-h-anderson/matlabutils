classdef tStyleInteraction < test.WithExampleTables
    % Test style interaction with the various tasks (e.g. adding styles
    % before/after folding)

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

            % Remove the filter so this stlye is visible
            t.Filter = "";
            t.openAllGroups();
            testCase.verifyEqual(t.StyleConfigurations.TargetIndex{end-1}, [6,3])
            testCase.verifyEqual(t.StyleConfigurations.Style(end-1), s(end))

            % Sort by categorical
            t.ColumnSortable = [0 1 0 0];
            t.SortByColumn = "Categorical";
            t.SortDirection = "Ascend";

            % No change to display stlyes
            testCase.verifyEqual(t.StyleConfigurations.TargetIndex{1}, [3 3])
            testCase.verifyEqual(t.StyleConfigurations.Style(1), s(2))
            testCase.verifyEqual(t.StyleConfigurations.TargetIndex{end-1}, [6,3])
            testCase.verifyEqual(t.StyleConfigurations.Style(end-1), s(end))

            % Data style moved again
            testCase.verifyEqual(t.StyleConfigurations.TargetIndex{2}, [2 3])
            testCase.verifyEqual(t.StyleConfigurations.Style(2), s(3))

            % Grouping headers not changed
            testCase.verifyEqual(t.StyleConfigurations.TargetIndex{end}, [1 4])
            testCase.verifyEqual(t.StyleConfigurations.Style(end), s(1))
 
        end

    end

end