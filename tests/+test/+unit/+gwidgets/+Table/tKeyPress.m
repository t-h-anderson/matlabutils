classdef tKeyPress < matlab.unittest.TestCase
    % Keyboard events and callbacks for gwidgets.Table.

    methods (TestMethodSetup)
        function applyGraphicsLeakFixture(testCase)
            testCase.applyFixture(fixtures.GraphicsLeakFixture());
        end
    end

    methods (Test)
        function tKeyPressCallbackSetAtConstruction(testCase)
            log = test.unit.gwidgets.Table.EventLog();
            callback = @(src, evt)log.record(src, evt);
            t = test.unit.gwidgets.Table.tKeyPress.createTable(testCase, ...
                KeyPressCallback=callback);
            t.Selection = [2 1];

            test.unit.gwidgets.Table.tKeyPress.pressUITableKey(t, "delete", char(127), {'control'});

            testCase.verifyEqual(t.KeyPressCallback, callback)
            testCase.verifyEqual(t.Callback.KeyPress, callback)
            testCase.verifyEqual(log.Count, 1)
            callbackData = log.latest();
            testCase.verifyClass(callbackData, "gwidgets.internal.table.KeyPressData")
            testCase.verifyEqual(callbackData.Key, "delete")
            testCase.verifyEqual(callbackData.Character, string(char(127)))
            testCase.verifyEqual(callbackData.Modifier, "control")
            testCase.verifyEqual(callbackData.Indices, [2 1])
            testCase.verifyEqual(callbackData.DisplayIndices, [2 1])
        end

        function tCallbackControllerKeyPressIsInvoked(testCase)
            t = test.unit.gwidgets.Table.tKeyPress.createTable(testCase);
            log = test.unit.gwidgets.Table.EventLog();
            callback = @(src, evt)log.record(src, evt);

            t.Callback.KeyPress = callback;
            test.unit.gwidgets.Table.tKeyPress.pressUITableKey(t, "a", 'a', {});

            testCase.verifyEqual(t.KeyPressCallback, callback)
            testCase.verifyEqual(t.Callback.KeyPressCallback, callback)
            testCase.verifyEqual(log.Count, 1)
            callbackData = log.latest();
            testCase.verifyClass(callbackData, "gwidgets.internal.table.KeyPressData")
            testCase.verifyEqual(callbackData.Key, "a")
            testCase.verifyEqual(callbackData.Character, "a")
            testCase.verifyEqual(callbackData.Modifier, string.empty(1,0))
        end

        function tKeyPressCallbackAliasesAreInterchangeable(testCase)
            t = test.unit.gwidgets.Table.tKeyPress.createTable(testCase);
            first = @(src, evt)disp(evt);
            second = @(src, evt)disp(src);

            t.KeyPressCallback = first;
            testCase.verifyEqual(t.Callback.KeyPress, first)

            t.Callback.KeyPressCallback = second;
            testCase.verifyEqual(t.KeyPressCallback, second)
        end

        function tKeyPressedEventReportsKeyAndSelection(testCase)
            t = test.unit.gwidgets.Table.tKeyPress.createTable(testCase);
            log = test.unit.gwidgets.Table.EventLog();
            testCase.listen(t, "KeyPressed", log);
            t.Column.Sortable = true;
            t.Sort.By = "ID";
            t.Sort.Direction = "Descend";
            t.SelectionType = "row";
            t.Selection = 2;

            test.unit.gwidgets.Table.tKeyPress.pressUITableKey(t, "a", 'A', {'control', 'shift'});

            testCase.verifyEqual(log.Count, 1)
            event = log.latest();
            testCase.verifyEqual(string(event.EventName), "KeyPressed")
            testCase.verifyEqual(event.Action, "keyPress")
            testCase.verifyEqual(event.Backend, "UITable")
            testCase.verifyEqual(event.Key, "a")
            testCase.verifyEqual(event.Character, "A")
            testCase.verifyEqual(event.Modifier, ["control", "shift"])
            testCase.verifyEqual(event.SelectionType, "row")
            testCase.verifyEqual(event.DataIndices, 2)
            testCase.verifyEqual(event.DisplayIndices, 3)
        end

        function tKeyPressedEventWithoutSelection(testCase)
            t = test.unit.gwidgets.Table.tKeyPress.createTable(testCase);
            log = test.unit.gwidgets.Table.EventLog();
            testCase.listen(t, "KeyPressed", log);

            test.unit.gwidgets.Table.tKeyPress.pressUITableKey(t, "uparrow", '', {});

            testCase.verifyEqual(log.Count, 1)
            event = log.latest();
            testCase.verifyEqual(event.Key, "uparrow")
            testCase.verifyEqual(event.Character, "")
            testCase.verifyEmpty(event.DisplayIndices)
            testCase.verifyEmpty(event.DataIndices)
        end

        function tOtherEventsHaveEmptyKeyFields(testCase)
            t = test.unit.gwidgets.Table.tKeyPress.createTable(testCase);
            log = test.unit.gwidgets.Table.EventLog();
            testCase.listen(t, "CellClicked", log);

            t.UITable.Callback.onCellClicked([], struct("InteractionInformation", struct( ...
                "DisplayRow", 1, ...
                "DisplayColumn", 1)));

            event = log.latest();
            testCase.verifyEqual(event.Key, "")
            testCase.verifyEqual(event.Character, "")
            testCase.verifyEqual(event.Modifier, string.empty(1,0))
        end

        function tJavaScriptKeyPressedBrowserEvent(testCase)
            t = test.unit.gwidgets.Table.tKeyPress.createTable(testCase, Backend="JavaScript");
            log = test.unit.gwidgets.Table.EventLog();
            testCase.listen(t, "KeyPressed", log);
            t.Selection = [3 2];

            t.UITable.Graphics.Backend.handleBrowserEvent(struct( ...
                "event", "KeyPressed", ...
                "key", "delete", ...
                "character", char(127), ...
                "modifier", {{'control'; 'alt'}}));

            testCase.verifyEqual(log.Count, 1)
            event = log.latest();
            testCase.verifyEqual(event.Backend, "JavaScript")
            testCase.verifyEqual(event.Key, "delete")
            testCase.verifyEqual(event.Modifier, ["control", "alt"])
            testCase.verifyEqual(event.DataIndices, [3 2])
            testCase.verifyEqual(event.DisplayIndices, [3 2])
        end

        function tJavaScriptKeyDownMapsKeyNames(testCase)
            log = test.unit.gwidgets.Table.EventLog();
            [t, backend] = test.unit.gwidgets.Table.tKeyPress.createJavaScriptTable(testCase, ...
                KeyPressCallback=@(src, evt)log.record(src, evt));
            eventLog = test.unit.gwidgets.Table.EventLog();
            testCase.listen(t, "KeyPressed", eventLog);
            t.Selection = [2 1];

            cases = {
                struct("key", "Delete"), "delete", string.empty(1,0)
                struct("key", "Backspace"), "backspace", string.empty(1,0)
                struct("key", "Enter"), "return", string.empty(1,0)
                struct("key", "Escape"), "escape", string.empty(1,0)
                struct("key", "Tab"), "tab", string.empty(1,0)
                struct("key", "ArrowUp", "ctrlKey", true, "shiftKey", true), "uparrow", ["control", "shift"]
                struct("key", "ArrowDown"), "downarrow", string.empty(1,0)
                struct("key", "ArrowLeft", "altKey", true), "leftarrow", "alt"
                struct("key", "ArrowRight", "metaKey", true), "rightarrow", "command"
                struct("key", "A", "code", "KeyA", "shiftKey", true), "a", "shift"
                struct("key", "!", "code", "Digit1", "shiftKey", true), "1", "shift"
                };
            for iCase = 1:height(cases)
                expectedCount = eventLog.Count + 1;
                backend.probeBrowser("PressKey", cases{iCase, 1});
                test.unit.gwidgets.Table.tKeyPress.waitForCount(eventLog, expectedCount);

                testCase.assertEqual(eventLog.Count, expectedCount, ...
                    "No KeyPressed event for " + cases{iCase, 1}.key)
                event = eventLog.latest();
                testCase.verifyEqual(event.Key, cases{iCase, 2})
                testCase.verifyEqual(event.Modifier, cases{iCase, 3})
                testCase.verifyEqual(event.Backend, "JavaScript")
                testCase.verifyEqual(event.DataIndices, [2 1])
            end

            testCase.verifyEqual(log.Count, eventLog.Count)
            testCase.verifyEqual(log.latest().Character, "!")
        end

        function tJavaScriptKeysInCellEditorAreNotReported(testCase)
            [t, backend] = test.unit.gwidgets.Table.tKeyPress.createJavaScriptTable(testCase);
            log = test.unit.gwidgets.Table.EventLog();
            testCase.listen(t, "KeyPressed", log);
            t.ColumnEditable = [true false];

            backend.probeBrowser("PressKey", struct("key", "x", "code", "KeyX", "row", 1, "col", 1));
            backend.probeBrowser("PressKey", struct("key", "Delete", "row", 2, "col", 1));
            test.unit.gwidgets.Table.tKeyPress.waitForCount(log, 1, Timeout=1);
            testCase.verifyEqual(log.Count, 0)

            backend.probeBrowser("PressKey", struct("key", "Delete", "row", 1, "col", 2));
            test.unit.gwidgets.Table.tKeyPress.waitForCount(log, 1);
            testCase.verifyEqual(log.Count, 1)
            testCase.verifyEqual(log.latest().Key, "delete")
        end
    end

    methods
        function listen(testCase, t, eventName, log)
            listener = addlistener(t, char(eventName), @(src, evt)log.record(src, evt));
            testCase.addTeardown(@()delete(listener));
        end
    end

    methods (Static, Access = private)
        function t = createTable(testCase, nvp)
            arguments
                testCase (1,1) matlab.unittest.TestCase
                nvp.Backend (1,1) string = "UITable"
                nvp.KeyPressCallback function_handle {mustBeScalarOrEmpty} = function_handle.empty(1,0)
            end

            fig = uifigure(Visible="off");
            testCase.addTeardown(@()delete(fig));
            args = {"Parent", fig, ...
                "Backend", nvp.Backend, ...
                "Data", test.unit.gwidgets.Table.tKeyPress.simpleData()};
            if ~isempty(nvp.KeyPressCallback)
                args = [args, {"KeyPressCallback", nvp.KeyPressCallback}];
            end
            t = gwidgets.Table(args{:});
            testCase.addTeardown(@()delete(t));
        end

        function [t, backend] = createJavaScriptTable(testCase, nvp)
            arguments
                testCase (1,1) matlab.unittest.TestCase
                nvp.KeyPressCallback function_handle {mustBeScalarOrEmpty} = function_handle.empty(1,0)
            end

            t = test.unit.gwidgets.Table.tKeyPress.createTable(testCase, ...
                Backend="JavaScript", KeyPressCallback=nvp.KeyPressCallback);
            backend = t.UITable.Graphics.Backend;
        end

        function pressUITableKey(t, key, character, modifier)
            % Drive the uitable KeyPressFcn with KeyData-like event data.
            component = t.DisplayTable;
            eventData = struct( ...
                "Key", char(key), ...
                "Character", character, ...
                "Modifier", {modifier});
            component.KeyPressFcn(component, eventData);
        end

        function waitForCount(log, count, nvp)
            arguments
                log (1,1) test.unit.gwidgets.Table.EventLog
                count (1,1) double
                nvp.Timeout (1,1) double = 5
            end

            startTime = tic;
            while toc(startTime) < nvp.Timeout && log.Count < count
                drawnow()
            end
        end

        function data = simpleData()
            data = table( ...
                (1:4)', ...
                ["A"; "B"; "A"; "B"], ...
                VariableNames=["ID", "Group"]);
        end
    end
end
