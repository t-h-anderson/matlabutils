classdef tDrag < test.WithFigureFixture
    % tDrag tests table row and group drag/drop semantics.

    methods (Test)
        function tRowDragMovesRawRows(testCase)
            fig = testCase.figureFixture("Type", "uifigure");
            t = gwidgets.Table(Parent=fig, Data=test.unit.gwidgets.Table.tDrag.simpleData());

            source = t.Drag.selectionAtDisplayRow(2);
            target = t.Drag.selectionAtDisplayRow(4, Placement="after");
            t.Drag.applyDrop(source, target);

            testCase.verifyEqual(t.Data.ID, [1; 3; 4; 2; 5])
        end

        function tSelectedRowsMoveTogether(testCase)
            fig = testCase.figureFixture("Type", "uifigure");
            t = gwidgets.Table(Parent=fig, Data=test.unit.gwidgets.Table.tDrag.simpleData());

            t.SelectionType = "row";
            t.DisplaySelection = [2 3];
            source = t.Drag.selectionAtDisplayRow(2);
            target = t.Drag.selectionAtDisplayRow(5, Placement="before");
            t.Drag.applyDrop(source, target);

            testCase.verifyEqual(t.Data.ID, [1; 4; 2; 3; 5])
        end

        function tSortedViewRejectsDrag(testCase)
            fig = testCase.figureFixture("Type", "uifigure");
            t = gwidgets.Table(Parent=fig, Data=flipud(test.unit.gwidgets.Table.tDrag.simpleData()));
            source = t.Drag.selectionAtDisplayRow(2);
            target = t.Drag.selectionAtDisplayRow(4);

            t.Column.DataSortable = true;
            t.Sort.By = "ID";
            t.Sort.Direction = "Ascend";

            testCase.verifyError(@()t.Drag.applyDrop(source, target), ...
                "GraphicsWidgets:Table:DragSortedView")
        end

        function tCategoricalGroupDragChangesCategoryOrder(testCase)
            fig = testCase.figureFixture("Type", "uifigure");
            t = gwidgets.Table(Parent=fig, Data=test.unit.gwidgets.Table.tDrag.categoricalGroupData());
            t.Group.By = "Group";
            t.Group.openAll();

            source = t.Drag.selectionAtDisplayRow(t.UITable.Data.VisibleGroupHeaderRowIdx(3));
            target = t.Drag.selectionAtDisplayRow(t.UITable.Data.VisibleGroupHeaderRowIdx(1), Placement="before");
            t.Drag.applyDrop(source, target);

            testCase.verifyEqual(string(categories(t.Data.Group)), ["C"; "A"; "B"])
        end

        function tNoncategoricalGroupDragUsesDisplayOrder(testCase)
            fig = testCase.figureFixture("Type", "uifigure");
            t = gwidgets.Table(Parent=fig, Data=test.unit.gwidgets.Table.tDrag.stringGroupData());
            t.Group.By = "Group";
            t.Group.openAll();

            source = t.Drag.selectionAtDisplayRow(t.UITable.Data.VisibleGroupHeaderRowIdx(3));
            target = t.Drag.selectionAtDisplayRow(t.UITable.Data.VisibleGroupHeaderRowIdx(1), Placement="before");
            t.Drag.applyDrop(source, target);

            testCase.verifyEqual(t.DisplayGroups, ["C", "A", "B"])
            testCase.verifyEqual(t.Data.ID, (1:5).')
        end

        function tCrossTableCopyAlignsByName(testCase)
            fig = testCase.figureFixture("Type", "uifigure");
            source = gwidgets.Table(Parent=fig, Data=test.unit.gwidgets.Table.tDrag.sourceData());
            target = gwidgets.Table(Parent=fig, Data=test.unit.gwidgets.Table.tDrag.targetData());

            sourceSelection = source.Drag.selectionAtDisplayRow(2);
            targetSelection = target.Drag.selectionAtDisplayRow(1, Placement="after");
            target.Drag.applyDrop(sourceSelection, targetSelection, Operation="copy");

            testCase.verifyEqual(source.Data.ID, [1; 2])
            testCase.verifyEqual(target.Data.ID, [100; 2])
            testCase.verifyEqual(target.Data.Name, ["old"; "b"])
            testCase.verifyEqual(target.Data.Flag, [true; false])
        end

        function tCrossTableMoveRemovesSourceRows(testCase)
            fig = testCase.figureFixture("Type", "uifigure");
            source = gwidgets.Table(Parent=fig, Data=test.unit.gwidgets.Table.tDrag.sourceData());
            target = gwidgets.Table(Parent=fig, Data=test.unit.gwidgets.Table.tDrag.targetData());

            sourceSelection = source.Drag.selectionAtDisplayRow(1);
            targetSelection = target.Drag.selectionAtDisplayRow(0, Placement="after");
            target.Drag.applyDrop(sourceSelection, targetSelection, Operation="move");

            testCase.verifyEqual(source.Data.ID, 2)
            testCase.verifyEqual(target.Data.ID, [100; 1])
            testCase.verifyEqual(target.Data.Name, ["old"; "a"])
        end

        function tBridgeDropCopyKeyCopiesRows(testCase)
            fig = testCase.figureFixture("Type", "uifigure");
            t = gwidgets.Table(Parent=fig, Data=test.unit.gwidgets.Table.tDrag.simpleData());

            t.Drag.Enabled = true;
            t.Drag.onBridgeDrop(struct( ...
                sourceRow=1, ...
                targetRow=3, ...
                placement="after", ...
                key="control"));

            testCase.verifyEqual(t.Data.ID, [1; 2; 3; 1; 4; 5])
        end

        function tCrossTableCopyFillsCategoricalDefaults(testCase)
            fig = testCase.figureFixture("Type", "uifigure");
            source = gwidgets.Table(Parent=fig, Data=table(1, VariableNames="ID"));
            targetData = table( ...
                100, ...
                categorical("old", ["old", "new"]), ...
                VariableNames=["ID", "Kind"]);
            target = gwidgets.Table(Parent=fig, Data=targetData);

            sourceSelection = source.Drag.selectionAtDisplayRow(1);
            targetSelection = target.Drag.selectionAtDisplayRow(1, Placement="after");
            target.Drag.applyDrop(sourceSelection, targetSelection, Operation="copy");

            testCase.verifyEqual(target.Data.ID, [100; 1])
            testCase.verifyTrue(isundefined(target.Data.Kind(2)))
            testCase.verifyEqual(string(categories(target.Data.Kind)), ["old"; "new"])
        end
    end

    methods (Static, Access = private)
        function data = simpleData()
            data = table((1:5).', ["a"; "b"; "c"; "d"; "e"], VariableNames=["ID", "Name"]);
        end

        function data = categoricalGroupData()
            data = table( ...
                (1:5).', ...
                categorical(["A"; "B"; "C"; "A"; "B"], ["A", "B", "C"]), ...
                VariableNames=["ID", "Group"]);
        end

        function data = stringGroupData()
            data = table((1:5).', ["A"; "B"; "C"; "A"; "B"], VariableNames=["ID", "Group"]);
        end

        function data = sourceData()
            data = table((1:2).', ["a"; "b"], [9; 8], VariableNames=["ID", "Name", "Extra"]);
        end

        function data = targetData()
            data = table(100, "old", true, VariableNames=["ID", "Name", "Flag"]);
        end
    end
end
