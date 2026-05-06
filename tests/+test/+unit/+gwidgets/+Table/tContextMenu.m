classdef tContextMenu < test.WithFigureFixture & test.WithExampleTables
    % Regression tests for context-menu construction.

    methods (Test)

        function tAutoResizeColumnsMenuAppearsOnce(testCase)
            % Regression: a previous version registered the "Auto-resize
            % columns" item twice (with different Tag values), producing
            % a duplicate entry in the context menu.
            fh = testCase.figureFixture("Type", "uifigure");
            t = gwidgets.Table(Parent=fh, ...
                Data=testCase.stringData(), ...
                HasAutoResizeColumns=true);

            items = findall(t.ContextMenu, "Text", "Auto-resize columns");
            testCase.verifyNumElements(items, 1)
        end

        function tAutoResizeMenuAbsentWhenDisabled(testCase)
            fh = testCase.figureFixture("Type", "uifigure");
            t = gwidgets.Table(Parent=fh, ...
                Data=testCase.stringData(), ...
                HasAutoResizeColumns=false);

            items = findall(t.ContextMenu, "Text", "Auto-resize columns");
            testCase.verifyEmpty(items)
        end

    end

end
