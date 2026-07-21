classdef tContextMenu < test.WithFigureFixture & test.WithExampleTables
    % Regression tests for context-menu construction.

    methods (Test)

        function tAutoResizeColumnsMenuAppearsOnce(testCase)
            % Regression: a previous version registered the "Auto-resize
            % columns" item twice (with different Tag values), producing
            % a duplicate entry in the context menu.
            fh = testCase.figureFixture("Type", "uifigure");
            t = gwidgets.Table(Parent=fh, Data=testCase.stringData());

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

        function tDraggingMenuTogglesDragState(testCase)
            fh = testCase.figureFixture("Type", "uifigure");
            t = gwidgets.Table(Parent=fh, ...
                Data=testCase.stringData(), ...
                HasToggleDragging=true);

            item = findall(t.ContextMenu, "Text", "Enable row dragging");
            item.MenuSelectedFcn(item, []);

            testCase.verifyTrue(t.Drag.Enabled)
            testCase.verifyNumElements(findall(t.ContextMenu, "Text", "Disable row dragging"), 1)
        end

        function tDraggingMenuAbsentWhenDisabled(testCase)
            fh = testCase.figureFixture("Type", "uifigure");
            t = gwidgets.Table(Parent=fh, ...
                Data=testCase.stringData(), ...
                HasToggleDragging=false);

            items = findall(t.ContextMenu, "Text", "Enable row dragging");
            testCase.verifyEmpty(items)
        end

        function tGroupingMenuSupportsMultiGroupActions(testCase)
            fh = testCase.figureFixture("Type", "uifigure");
            t = gwidgets.Table(Parent=fh, ...
                Data=testCase.stringData(), ...
                GroupingVariable=["Var1", "Var2"], ...
                HasChangeGroupingVariable=true);

            setMenu = findall(t.ContextMenu, "Text", "Set");
            addMenu = findall(t.ContextMenu, "Text", "Add");
            removeMenu = findall(t.ContextMenu, "Text", "Remove");

            testCase.verifyNumElements(setMenu, 1)
            testCase.verifyNumElements(addMenu, 1)
            testCase.verifyNumElements(removeMenu, 1)
            testCase.verifyNumElements(findall(setMenu, "Text", "All"), 1)
            testCase.verifyNumElements(findall(addMenu, "Text", "All"), 1)
            testCase.verifyNumElements(findall(removeMenu, "Text", "All"), 1)
            testCase.verifyNumElements(findall(removeMenu, "Text", "Var1"), 1)
            testCase.verifyNumElements(findall(removeMenu, "Text", "Var2"), 1)
            testCase.verifyNumElements(findall(t.ContextMenu, "Text", "Use nested groups"), 1)
        end

        function tGroupingMenuTogglesModeAndRemovesGroup(testCase)
            fh = testCase.figureFixture("Type", "uifigure");
            t = gwidgets.Table(Parent=fh, ...
                Data=testCase.stringData(), ...
                GroupingVariable=["Var1", "Var2"], ...
                HasChangeGroupingVariable=true);

            modeItem = findall(t.ContextMenu, "Text", "Use nested groups");
            modeItem.MenuSelectedFcn(modeItem, []);

            testCase.verifyEqual(t.GroupingMode, "Nested")
            testCase.verifyNumElements(findall(t.ContextMenu, "Text", "Use flat groups"), 1)

            removeMenu = findall(t.ContextMenu, "Text", "Remove");
            removeItem = findall(removeMenu, "Text", "Var1");
            removeItem.MenuSelectedFcn(removeItem, []);

            testCase.verifyEqual(t.GroupingVariable, "Var2")

            removeMenu = findall(t.ContextMenu, "Text", "Remove");
            clearItem = findall(removeMenu, "Text", "All");
            clearItem.MenuSelectedFcn(clearItem, []);

            testCase.verifyEmpty(t.GroupingVariable)
        end

        function tGroupingMenuShowsSelectedColumns(testCase)
            fh = testCase.figureFixture("Type", "uifigure");
            t = gwidgets.Table(Parent=fh, ...
                Data=testCase.stringData(), ...
                HasChangeGroupingVariable=true);

            t.SelectionType = "column";
            t.DisplaySelection = [1 2];

            setMenu = findall(t.ContextMenu, "Text", "Set");
            addMenu = findall(t.ContextMenu, "Text", "Add");

            testCase.verifyNumElements(findall(setMenu, "Text", "Selected (Var1, Var2)"), 1)
            testCase.verifyNumElements(findall(addMenu, "Text", "Selected (Var1, Var2)"), 1)
        end

    end

end
