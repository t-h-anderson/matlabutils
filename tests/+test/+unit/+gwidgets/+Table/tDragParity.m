classdef tDragParity < matlab.unittest.TestCase
    % Drag/drop behaviour that both table backends must satisfy.

    properties (TestParameter)
        Backend = struct("UITable", "UITable", "JavaScript", "JavaScript")
    end

    methods (TestMethodSetup)
        function applyGraphicsLeakFixture(testCase)
            testCase.applyFixture(fixtures.GraphicsLeakFixture());
        end
    end

    methods (Test)
        function tRowDropMovesRows(testCase, Backend)
            t = test.unit.gwidgets.Table.tDragParity.createTable(testCase, Backend);
            t.Drag.Enabled = true;

            testCase.dropRow(t, 2, 4, "after", "alt");

            testCase.verifyEqual(t.Data.ID, [1; 3; 4; 2; 5])
        end

        function tRowDropCopiesRows(testCase, Backend)
            t = test.unit.gwidgets.Table.tDragParity.createTable(testCase, Backend);
            t.Drag.Enabled = true;

            testCase.dropRow(t, 1, 3, "after", "control");

            testCase.verifyEqual(t.Data.ID, [1; 2; 3; 1; 4; 5])
        end

        function tSelectedRowsMoveTogether(testCase, Backend)
            t = test.unit.gwidgets.Table.tDragParity.createTable(testCase, Backend);
            t.Drag.Enabled = true;
            t.SelectionType = "row";
            t.DisplaySelection = [2 3];

            testCase.dropRow(t, 2, 5, "before", "alt");

            testCase.verifyEqual(t.Data.ID, [1; 4; 2; 3; 5])
        end

        function tGroupHeaderDropMovesGroups(testCase, Backend)
            t = test.unit.gwidgets.Table.tDragParity.createTable( ...
                testCase, Backend, test.unit.gwidgets.Table.tDragParity.categoricalGroupData());
            t.Drag.Enabled = true;
            t.Group.By = "Group";
            t.Group.openAll();
            groupHeaderRows = t.UITable.Data.VisibleGroupHeaderRowIdx;

            testCase.dropRow(t, groupHeaderRows(3), groupHeaderRows(1), "before", "alt");

            testCase.verifyEqual(string(categories(t.Data.Group)), ["C"; "A"; "B"])
        end

        function tDisabledDragIgnoresDrop(testCase, Backend)
            t = test.unit.gwidgets.Table.tDragParity.createTable(testCase, Backend);

            testCase.dropRow(t, 2, 4, "after", "alt");

            testCase.verifyEqual(t.Data.ID, (1:5)')
        end
    end

    methods
        function dropRow(testCase, t, sourceRow, targetRow, placement, key)
            arguments
                testCase (1,1) test.unit.gwidgets.Table.tDragParity
                t (1,1) gwidgets.Table
                sourceRow (1,1) double
                targetRow (1,1) double
                placement (1,1) string {mustBeMember(placement, ["before", "after"])}
                key (1,1) string {mustBeMember(key, ["control", "alt", "shift", ""])}
            end

            switch t.Backend
                case "JavaScript"
                    payload = testCase.dragPayload(sourceRow, targetRow, placement, key);
                    t.UITable.Graphics.Backend.probeBrowser("DragRowDrop", payload);
                otherwise
                    t.Drag.onBridgeDrop(struct( ...
                        sourceRow=sourceRow, ...
                        targetRow=targetRow, ...
                        placement=placement, ...
                        key=key));
            end
        end

        function payload = dragPayload(testCase, sourceRow, targetRow, placement, key)
            arguments
                testCase (1,1) test.unit.gwidgets.Table.tDragParity %#ok<INUSA>
                sourceRow (1,1) double
                targetRow (1,1) double
                placement (1,1) string
                key (1,1) string
            end

            payload = struct( ...
                "sourceRow", sourceRow, ...
                "targetRow", targetRow, ...
                "placement", placement, ...
                "key", key, ...
                "dragKey", key);
            switch key
                case "control"
                    payload.ctrlKey = true;
                case "alt"
                    payload.altKey = true;
                case "shift"
                    payload.shiftKey = true;
                otherwise
                    % No modifier key requested.
            end
        end
    end

    methods (Static, Access = private)
        function t = createTable(testCase, backend, data)
            arguments
                testCase (1,1) matlab.unittest.TestCase
                backend (1,1) string
                data (:,:) table = test.unit.gwidgets.Table.tDragParity.simpleData()
            end

            fig = uifigure(Visible="off");
            testCase.addTeardown(@()delete(fig));
            t = gwidgets.Table( ...
                Parent=fig, ...
                Backend=backend, ...
                Data=data);
            testCase.addTeardown(@()delete(t));
        end

        function data = simpleData()
            data = table((1:5)', ["a"; "b"; "c"; "d"; "e"], VariableNames=["ID", "Name"]);
        end

        function data = categoricalGroupData()
            data = table( ...
                (1:5)', ...
                categorical(["A"; "B"; "C"; "A"; "B"], ["A", "B", "C"]), ...
                VariableNames=["ID", "Group"]);
        end
    end
end
