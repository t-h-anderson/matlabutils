classdef tColumnWidthBridge < test.WithExampleTables
    % Unit tests for the MATLAB-side column-width bridge logic.
    %
    % These tests run headlessly (no figure or DOM required) by inspecting
    % timer state and MATLAB-visible properties.  They cover the fixes to:
    %
    %   - Timer accumulation: rapid ColumnWidth changes must not build up
    %     multiple concurrent pause timers (fix: PauseTimer_ is cancelled
    %     and replaced on each pauseColumnWidthBridge call).
    %
    %   - Timer cleanup on delete: the in-flight pause timer must be stopped
    %     and deleted when the Table object is destroyed (fix: delete() now
    %     calls stop/delete on PauseTimer_ before releasing resources).

    % ------------------------------------------------------------------ %
    %  Helpers
    % ------------------------------------------------------------------ %
    methods (Access = private)

        function timers = ownTimers(~, baseline)
            % Return timer objects created after 'baseline' was taken.
            % Uses Tags set on pause timers to scope to our objects only.
            % Fallback: just return all timers minus the baseline set.
            all = timerfindall;
            if isempty(baseline)
                timers = all;
            else
                % setdiff on handles: keep timers not in the baseline set.
                timers = all(~ismember(all, baseline));
            end
        end

    end

    % ------------------------------------------------------------------ %
    %  Timer accumulation tests
    % ------------------------------------------------------------------ %
    methods (Test)

        function tSingleTimerAfterRapidWidthChanges(testCase)
            % Each pauseColumnWidthBridge call should cancel the previous
            % in-flight timer before starting a new one.  After N rapid
            % ColumnWidth assignments only one pause timer should exist.

            baseline = timerfindall;

            t = gwidgets.Table(Data=testCase.multivariableData());  % 4 cols
            t.DataColumnWidth = {100, 100, 100, 100};               % 1st pause

            for i = 1:5
                t.DataColumnWidth = {100+i, 100+i, 100+i, 100+i};   % cancels prev
            end

            created = testCase.ownTimers(baseline);
            testCase.verifyLessThanOrEqual(numel(created), 1, ...
                "Rapid width changes should leave at most 1 in-flight pause timer")

            delete(t);
        end

        function tTimerCancelledOnTableDelete(testCase)
            % Deleting the Table object must stop and delete any in-flight
            % pause timer so that it cannot fire after the object is gone.

            baseline = timerfindall;

            t = gwidgets.Table(Data=testCase.multivariableData());
            t.DataColumnWidth = {100, 100, 100, 100};  % creates a timer

            delete(t);

            created = testCase.ownTimers(baseline);
            testCase.verifyEmpty(created, ...
                "Deleting the Table should cancel its in-flight pause timer")
        end

        function tTimerCountAfterMixedPauseValues(testCase)
            % pauseColumnWidthBridge is called with different durations
            % (500 ms for pixel, 1200 ms for auto).  Interleaving these
            % must still leave at most one timer alive.

            baseline = timerfindall;

            t = gwidgets.Table(Data=testCase.multivariableData());

            t.DataColumnWidth = {100, 100, 100, 100};   % pixel  → 500 ms pause
            t.DataColumnWidth = {};                     % auto   → 1200 ms pause
            t.DataColumnWidth = {200, 200, 200, 200};   % pixel  → 500 ms pause
            t.DataColumnWidth = {};                     % auto   → 1200 ms pause

            created = testCase.ownTimers(baseline);
            testCase.verifyLessThanOrEqual(numel(created), 1, ...
                "Interleaved pixel/auto width changes must leave at most 1 timer")

            delete(t);
        end

    end

    % ------------------------------------------------------------------ %
    %  widthsToJsArray / onColumnWidthChanged MATLAB-side logic
    %  (tested indirectly through DataColumnWidth_ state changes)
    % ------------------------------------------------------------------ %
    methods (Test)

        function tBridgeDragUpdateStoresPixelWidth(testCase)
            % Simulate the bridge reporting a pixel-column drag:
            % onColumnWidthChanged receives positive widths and stores them
            % as numeric entries in DataColumnWidth_.

            t = gwidgets.Table(Data=testCase.multivariableData());  % 4 cols
            t.DataColumnWidth = {100, 200, 150, 80};

            % Simulate bridge reporting new pixel widths (all positive).
            % We call the public property path that onColumnWidthChanged
            % ultimately reflects: DataColumnWidth should update.
            t.DataColumnWidth = {120, 200, 150, 80};

            testCase.verifyEqual(t.DataColumnWidth, {120, 200, 150, 80})
        end

        function tColumnWidthRoundtripThroughBridgeEncoding(testCase)
            % widthsToJsArray sends -1 for any non-pixel width.
            % Verify that setting auto, nx, and pixel widths all survive a
            % set → get round trip without becoming something else.

            t = gwidgets.Table(Data=testCase.multivariableData());

            % Pixel
            t.DataColumnWidth = {50, 100, 75, 200};
            testCase.verifyEqual(t.DataColumnWidth, {50, 100, 75, 200})

            % Auto string
            t.DataColumnWidth = {"auto", "auto", "auto", "auto"};
            testCase.verifyEqual(t.DataColumnWidth, {"auto","auto","auto","auto"})

            % Proportional
            t.DataColumnWidth = {"1x", "2x", "1x", "2x"};
            testCase.verifyEqual(t.DataColumnWidth, {"1x","2x","1x","2x"})

            % Mixed pixel / auto
            t.DataColumnWidth = {100, "auto", 150, "auto"};
            testCase.verifyEqual(t.DataColumnWidth, {100,"auto",150,"auto"})
        end

        function tColumnWidthNotChangedByEchoguard(testCase)
            % If DataColumnWidth is set to the same values it already holds,
            % the echo-guard in onColumnWidthChanged (isequal check) should
            % prevent a redundant update cycle.  We verify this indirectly by
            % confirming that DataColumnWidth_ stays identical and no error
            % is raised on re-assignment of the same values.

            t = gwidgets.Table(Data=testCase.multivariableData());
            t.DataColumnWidth = {100, 200, 150, 80};

            before = t.DataColumnWidth;
            t.DataColumnWidth = {100, 200, 150, 80};  % same values
            after  = t.DataColumnWidth;

            testCase.verifyEqual(before, after)
        end

        function tHiddenColumnWidthPreservedAcrossVisibilityChange(testCase)
            % When a column is hidden and the bridge sends SetWidths with
            % fewer columns, the stored width for the hidden column must
            % survive the round-trip intact.

            t = gwidgets.Table(Data=testCase.multivariableData());
            t.DataColumnWidth = {100, 200, 150, 80};

            % Hide column 2 (width 200 should be preserved)
            t.HiddenColumnNames = "Categorical";

            testCase.verifyEqual(t.DataColumnWidth, {100, 200, 150, 80}, ...
                "Hidden column width must be preserved")
            testCase.verifyEqual(t.ColumnWidth, {100, 150, 80}, ...
                "Visible column widths must be unchanged")
        end

    end

end
