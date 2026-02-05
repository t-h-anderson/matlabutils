classdef tStyling < test.WithExampleTables
    % Test applying table styles to a headless table.

    methods (Test)

        function tDefaultStyle(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());
            testCase.verifyEqual(t.defaultGroupHeaderStyle().Style, t.StyleConfigurations.Style)
        end

        function tAddStyle(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());
            s = uistyle(FontColor="blue");

            nStyles = height(t.StyleConfigurations);

            t.addStyle(s);

            testCase.verifyEqual(height(t.StyleConfigurations), nStyles + 1);
            testCase.verifyEqual(t.StyleConfigurations.Style(1), s)
            testCase.verifyEqual(t.StyleConfigurations.Target(1), categorical("table"))
            testCase.verifyEqual(t.StyleConfigurations.TargetIndex(1), {char.empty(0,0)})

        end

        function tAddStyleToCells(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());
            s = uistyle(FontColor="blue");

            nStyles = height(t.StyleConfigurations);

            t.addStyle(s, "cell", [2 3; 1 2]);

            testCase.verifyEqual(height(t.StyleConfigurations), nStyles + 1);
            testCase.verifyEqual(t.StyleConfigurations.Style(end), t.defaultGroupHeaderStyle().Style)
            testCase.verifyEqual(t.StyleConfigurations.Style(1), s)
            testCase.verifyEqual(t.StyleConfigurations.Target(1), categorical("cell"))
            testCase.verifyEqual(t.StyleConfigurations.TargetIndex(1), {[2 3; 1 2]})
        end

        function tAddStyleToCell(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());
            s = uistyle(FontColor="blue");

            nStyles = height(t.StyleConfigurations);

            t.addStyle(s, "cell", [2,2]);

            % Filter the styled cell
            t.Filter="Numerical>3";
            testCase.verifyEqual(height(t.StyleConfigurations), nStyles + 1);
            testCase.verifyEqual(t.StyleConfigurations.Style(end), t.defaultGroupHeaderStyle().Style)
            testCase.verifyEqual(t.StyleConfigurations.Style(1), s)
            testCase.verifyEqual(t.StyleConfigurations.Target(1), categorical("cell"))
            testCase.verifyEqual(t.StyleConfigurations.TargetIndex(1), {double.empty(0,2)})

            % Filter the row above the styled cell
            t.Filter="Numerical=2";
            testCase.verifyEqual(t.StyleConfigurations.TargetIndex(1), {[1,2]})

            % Hide the column containing the styled cell
            t.HiddenColumnNames = "Numerical";
            testCase.verifyEqual(t.StyleConfigurations.TargetIndex(1), {[1,1]})

            % Hide the column containing the styled cell
            t.HiddenColumnNames = "Categorical";
            testCase.verifyEqual(t.StyleConfigurations.TargetIndex(1), {double.empty(0,2)})
        end

        function tAddStyleToCellWithoutSpecifyingIndex(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());
            s = uistyle(FontColor="blue");

            fcn = @() t.addStyle(s, "cell");
            testCase.verifyError(fcn, "MATLAB:ui:Table:invalidCellTargetIndex")
        end

        function tAddStyleToSingleRow(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());
            s = uistyle(FontColor="blue");

            t.addStyle(s, "row", 2);

            testCase.verifyEqual(t.StyleConfigurations.Target(1), categorical("row"))
            testCase.verifyEqual(t.StyleConfigurations.TargetIndex(1), {2})
        end

        function tAddStyleToRowWithoutSpecifyingIndex(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());
            s = uistyle(FontColor="blue");

            fcn = @() t.addStyle(s, "row");
            testCase.verifyError(fcn, "MATLAB:ui:Table:invalidRowTargetIndex")
        end

        function tAddStyleToSingleColumn(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());
            s = uistyle(FontColor="blue");

            t.addStyle(s, "column", 2);

            testCase.verifyEqual(t.StyleConfigurations.Target(1), categorical("column"))
            testCase.verifyEqual(t.StyleConfigurations.TargetIndex(1), {2})
        end

        function tAddStyleToColumnWithoutSpecifyingIndex(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());
            s = uistyle(FontColor="blue");

            fcn = @() t.addStyle(s, "column");
            testCase.verifyError(fcn, "MATLAB:ui:Table:invalidColumnTargetIndex")
        end

        function tAddMultiplStyles(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());
            s = uistyle(FontColor="blue");

            nStyles = height(t.StyleConfigurations);

            t.addStyle(s, "cell", [2 4]);
            t.addStyle(s, "cell", [1 2]);
            t.addStyle(s, "row", 3);

            testCase.assertSize(t.StyleConfigurations, [nStyles+3, 3])
            testCase.verifyEqual(t.StyleConfigurations.Target(1:end-1), ...
                categorical(["cell", "cell", "row"]'))
        end

        function tRemoveStyle(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());
            s = uistyle(FontColor="blue");

            nStyles = height(t.StyleConfigurations);

            t.addStyle(s, "cell", [2 4; 3 3]);
            t.addStyle(s, "cell", [1 2]);
            t.addStyle(s, "cell", [2 2]);

            t.removeStyle(1); % Remove the first custom style (i.e. not the group header) - [2 4; 3 3]

            testCase.assertSize(t.StyleConfigurations, [nStyles+2, 3])
            testCase.verifyEqual(t.StyleConfigurations.Style(end), t.defaultGroupHeaderStyle().Style)
            testCase.verifyEqual(t.StyleConfigurations.TargetIndex(1), {[1 2]})
            testCase.verifyEqual(t.StyleConfigurations.TargetIndex(2), {[2 2]})

            t.removeStyle(2)
            testCase.assertSize(t.StyleConfigurations, [nStyles+1, 3])
            testCase.verifyEqual(t.StyleConfigurations.Style(end), t.defaultGroupHeaderStyle().Style)
            testCase.verifyEqual(t.StyleConfigurations.TargetIndex(1), {[1 2]})
        end

        function tRemoveAllStyles(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());
            s = uistyle(FontColor="blue");

            nStyles = height(t.StyleConfigurations);
            
            t.StyleConfigurations.Style(1)

            t.addStyle(s, "cell", [2 4; 3 3]);
            t.addStyle(s, "cell", [1 2]);
            t.addStyle(s, "cell", [2 2]);

            t.removeStyle()

            testCase.assertSize(t.StyleConfigurations, [nStyles 3])
            testCase.verifyEqual(t.defaultGroupHeaderStyle().Style, t.StyleConfigurations.Style)
        end

        function tAddStyleToCellOutOfBounds(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());
            s = uistyle(FontColor="blue");

            fcn = @() t.addStyle(s, "cell", [10 10]);
            testCase.verifyError(fcn, "GraphicsWidgets:Table:SelectionOutOfRange")
        end

        function tAddStyleToEmptyTable(testCase)
            t = gwidgets.Table(Data=table.empty(0,2));

            s = uistyle(FontColor="blue");
            t.addStyle(s, "column", 2);
            
            testCase.assertSize(t.StyleConfigurations, [2 3])
            testCase.verifyEqual(t.StyleConfigurations.TargetIndex{1}, 2)
        end

        function tAddCellStyleWithFind(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());
            s = uistyle(FontColor="blue");

            t.addStyle(s, "cell", "Numerical>3;Categorical=a");

            testCase.verifyEqual(t.StyleConfigurations.Target(1), categorical("cell"))
            testCase.verifyEqual(t.StyleConfigurations.TargetIndex{1}, [4 1; 5 1; 1 2; 4 2; 5 2])
        end

        function tAddRowStyleWithFind(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());
            s = uistyle(FontColor="blue");

            t.addStyle(s, "row", "Numerical>3;Categorical=a");

            testCase.verifyEqual(t.StyleConfigurations.Target(1), categorical("row"))
            testCase.verifyEqual(t.StyleConfigurations.TargetIndex{1}, [1 4 5])
        end

        function tAddColumnStyleWithFind(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());
            s = uistyle(FontColor="blue");

            t.addStyle(s, "column", "Numerical;Categorical");

            testCase.verifyEqual(t.StyleConfigurations.Target(1), categorical("column"))
            testCase.verifyEqual(t.StyleConfigurations.TargetIndex{1}, [1 2])
        end

    end

end