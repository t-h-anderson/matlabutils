classdef tEvents < matlab.unittest.TestCase
    % Public listener surface for gwidgets.Table.

    methods (TestMethodSetup)
        function applyGraphicsLeakFixture(testCase)
            testCase.applyFixture(fixtures.GraphicsLeakFixture());
        end
    end

    methods (Test)
        function tOuterTableForwardsCellClickEvent(testCase)
            t = test.unit.gwidgets.Table.tEvents.createTable(testCase);
            log = test.unit.gwidgets.Table.EventLog();
            testCase.listen(t, "CellClicked", log);
            eventData = struct("InteractionInformation", struct( ...
                "DisplayRow", 2, ...
                "DisplayColumn", 1));

            t.UITable.Callback.onCellClicked([], eventData);

            event = log.latest();
            testCase.verifyEqual(log.Count, 1)
            testCase.verifyClass(event, "gwidgets.table.TableEventData")
            testCase.verifyEqual(string(event.EventName), "CellClicked")
            testCase.verifyEqual(event.Action, "click")
            testCase.verifyEqual(event.Backend, "UITable")
            testCase.verifyEqual(event.DisplayIndices, [2 1])
            testCase.verifyEqual(event.DataIndices, [2 1])
        end

        function tSelectionEventDoesNotRequireLegacyCallback(testCase)
            t = test.unit.gwidgets.Table.tEvents.createTable(testCase);
            log = test.unit.gwidgets.Table.EventLog();
            testCase.listen(t, "SelectionChanged", log);
            source = struct("SelectionType", "row");
            eventData = struct("Indices", [2 1; 3 1]);

            t.UITable.Callback.onSelection(source, eventData);

            event = log.latest();
            testCase.verifyEqual(log.Count, 1)
            testCase.verifyEqual(string(event.EventName), "SelectionChanged")
            testCase.verifyEqual(event.SelectionType, "row")
            testCase.verifyEqual(event.DisplayIndices, [2 3])
            testCase.verifyEqual(event.DataIndices, [2 3])
        end

        function tCellEditedEventIncludesPreviousAndNewData(testCase)
            t = test.unit.gwidgets.Table.tEvents.createTable(testCase);
            log = test.unit.gwidgets.Table.EventLog();
            testCase.listen(t, "CellEdited", log);
            editEvent = struct( ...
                "Indices", [2 1], ...
                "PreviousData", 2, ...
                "EditData", 42, ...
                "NewData", 42);

            t.UITable.Callback.onCellEdit([], editEvent);

            event = log.latest();
            testCase.verifyEqual(log.Count, 1)
            testCase.verifyEqual(string(event.EventName), "CellEdited")
            testCase.verifyEqual(event.DisplayIndices, [2 1])
            testCase.verifyEqual(event.DataIndices, [2 1])
            testCase.verifyEqual(event.PreviousData, 2)
            testCase.verifyEqual(event.EditData, 42)
            testCase.verifyEqual(event.NewData, 42)
            testCase.verifyEqual(t.Data.ID(2), 42)
        end

        function tDisplayDataChangedEventDoesNotRequireLegacyCallback(testCase)
            t = test.unit.gwidgets.Table.tEvents.createTable(testCase);
            log = test.unit.gwidgets.Table.EventLog();
            testCase.listen(t, "DisplayDataChanged", log);
            eventData = struct( ...
                "Interaction", "filter", ...
                "InteractionVariable", "Group");

            t.UITable.Callback.onDisplayDataChanged(t.UITable, eventData);

            event = log.latest();
            testCase.verifyEqual(log.Count, 1)
            testCase.verifyEqual(string(event.EventName), "DisplayDataChanged")
            testCase.verifyEqual(event.Action, "filter")
            testCase.verifyEqual(event.Payload.InteractionVariable, "Group")
        end

        function tStateChangeEventsPublishFilterGroupAndSort(testCase)
            t = test.unit.gwidgets.Table.tEvents.createTable(testCase);
            filterLog = test.unit.gwidgets.Table.EventLog();
            groupLog = test.unit.gwidgets.Table.EventLog();
            sortLog = test.unit.gwidgets.Table.EventLog();
            testCase.listen(t, "FilterChanged", filterLog);
            testCase.listen(t, "GroupingChanged", groupLog);
            testCase.listen(t, "SortChanged", sortLog);

            t.Filter = "Group=A";
            t.GroupingVariable = "Group";
            t.ColumnSortable = true;
            t.SortByColumn = "ID";
            t.SortDirection = "Descend";

            filterEvent = filterLog.latest();
            groupEvent = groupLog.latest();
            sortEvent = sortLog.latest();
            testCase.verifyGreaterThanOrEqual(filterLog.Count, 1)
            testCase.verifyGreaterThanOrEqual(groupLog.Count, 1)
            testCase.verifyGreaterThanOrEqual(sortLog.Count, 1)
            testCase.verifyEqual(filterEvent.Filter, "Group=A")
            testCase.verifyEqual(filterEvent.RowFilterIndices, [true false true false])
            testCase.verifyEqual(groupEvent.GroupingVariables, "Group")
            testCase.verifyEqual(sortEvent.SortBy, "ID")
            testCase.verifyEqual(sortEvent.SortDirection, "Descend")
        end

        function tDataAssignmentEmitsTableDataChanged(testCase)
            t = test.unit.gwidgets.Table.tEvents.createTable(testCase);
            log = test.unit.gwidgets.Table.EventLog();
            testCase.listen(t, "TableDataChanged", log);
            data = test.unit.gwidgets.Table.tEvents.simpleData();
            data.ID = data.ID + 10;

            t.Data = data;

            event = log.latest();
            testCase.verifyEqual(log.Count, 1)
            testCase.verifyEqual(string(event.EventName), "TableDataChanged")
            testCase.verifyEqual(event.Action, "set")
            testCase.verifyEqual(event.NewData, data)
            testCase.verifyEqual(event.Payload.Size, size(data))
        end

        function tTooltipEventFromBridgeHover(testCase)
            t = test.unit.gwidgets.Table.tEvents.createTable(testCase);
            log = test.unit.gwidgets.Table.EventLog();
            testCase.listen(t, "TooltipRequested", log);
            t.addTooltip("cell text", "cell", [2 1]);

            t.simulateBridgeHover(2, 1);

            event = log.latest();
            testCase.verifyEqual(log.Count, 1)
            testCase.verifyEqual(string(event.EventName), "TooltipRequested")
            testCase.verifyEqual(event.DisplayIndices, [2 1])
            testCase.verifyEqual(event.DataIndices, [2 1])
            testCase.verifyEqual(event.TooltipText, "cell text")
        end

        function tTooltipEventFromJavaScriptHover(testCase)
            t = test.unit.gwidgets.Table.tEvents.createTable(testCase, "JavaScript");
            log = test.unit.gwidgets.Table.EventLog();
            testCase.listen(t, "TooltipRequested", log);
            t.addTooltip("js cell text", "cell", [1 1]);

            t.UITable.Graphics.Backend.handleBrowserEvent(struct( ...
                "event", "CellHover", ...
                "row", 1, ...
                "col", 1));

            event = log.latest();
            testCase.verifyEqual(log.Count, 1)
            testCase.verifyEqual(string(event.EventName), "TooltipRequested")
            testCase.verifyEqual(event.Backend, "JavaScript")
            testCase.verifyEqual(event.DisplayIndices, [1 1])
            testCase.verifyEqual(event.TooltipText, "js cell text")
        end

        function tDragStartAndDropEvents(testCase)
            t = test.unit.gwidgets.Table.tEvents.createTable(testCase);
            startLog = test.unit.gwidgets.Table.EventLog();
            dropLog = test.unit.gwidgets.Table.EventLog();
            testCase.listen(t, "DragStarted", startLog);
            testCase.listen(t, "DropCompleted", dropLog);
            t.Drag.Enabled = true;
            startData = struct("sourceRow", 2);
            dropData = struct( ...
                "sourceRow", 2, ...
                "targetRow", 4, ...
                "placement", "after", ...
                "key", "alt");

            t.Drag.onBridgeDragStart(startData);
            t.Drag.onBridgeDrop(dropData);

            startEvent = startLog.latest();
            dropEvent = dropLog.latest();
            testCase.verifyEqual(startLog.Count, 1)
            testCase.verifyEqual(dropLog.Count, 1)
            testCase.verifyEqual(startEvent.SourceSelection.DataRows, 2)
            testCase.verifyEqual(dropEvent.Operation, "move")
            testCase.verifyEqual(dropEvent.Placement, "after")
            testCase.verifyEqual(dropEvent.SourceSelection.DataRows, 2)
            testCase.verifyEqual(dropEvent.TargetSelection.DataRows, 4)
            testCase.verifyEqual(t.Data.ID, [1; 3; 4; 2])
        end
    end

    methods
        function listen(testCase, t, eventName, log)
            listener = addlistener(t, char(eventName), @(src, evt)log.record(src, evt));
            testCase.addTeardown(@()delete(listener));
        end
    end

    methods (Static, Access = private)
        function t = createTable(testCase, backend)
            arguments
                testCase (1,1) matlab.unittest.TestCase
                backend (1,1) string = "UITable"
            end

            data = test.unit.gwidgets.Table.tEvents.simpleData();
            fig = uifigure(Visible="off");
            testCase.addTeardown(@()delete(fig));
            t = gwidgets.Table( ...
                Parent=fig, ...
                Backend=backend, ...
                Data=data);
            testCase.addTeardown(@()delete(t));
        end

        function data = simpleData()
            data = table( ...
                (1:4)', ...
                ["A"; "B"; "A"; "B"], ...
                VariableNames=["ID", "Group"]);
        end
    end
end
