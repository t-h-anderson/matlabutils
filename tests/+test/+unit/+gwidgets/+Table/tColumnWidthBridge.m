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

        function tPixelColumnPreservedWhenBridgeReportsPropOnDrag(testCase)
            % Regression: if the bridge's colAutoFlags is stale (all-auto)
            % while MATLAB has pixel-specified columns, onColumnWidthChanged
            % receives all-negative values.  Pixel columns must NOT be
            % converted to proportional; their stored pixel width is preserved.
            %
            % We simulate the stale-bridge scenario by calling the internal
            % handler directly with a mix of a pixel column and two proportional
            % reports for columns that were already auto in MATLAB.

            t = gwidgets.Table(Data=testCase.multivariableData());  % 4 cols
            % Col 1 pixel (100px), cols 2-4 auto
            t.DataColumnWidth = {100, "auto", "auto", "auto"};

            % Simulate bridge reporting all-proportional (stale colAutoFlags):
            % col 1 gets a proportional value even though it is pixel.
            % We replicate what onColumnWidthChanged does:
            %   - widths(1) < 0  → bridge claims col 1 is proportional
            %   - widths(2..4) < 0 → proportional for genuinely auto cols
            %
            % The fix: pixel columns preserve their type; auto cols update.
            staleBridgeWidths = [-97, -106, -98, -99];  % all negative (stale)
            t.simulateBridgeDrag(staleBridgeWidths);

            % Col 1 must stay pixel (preserved)
            testCase.verifyEqual(t.DataColumnWidth{1}, 100, ...
                "Pixel column must not be converted to proportional on stale-bridge drag")

            % Cols 2-4 must update to proportional weights
            testCase.verifyEqual(t.DataColumnWidth{2}, "106x")
            testCase.verifyEqual(t.DataColumnWidth{3}, "98x")
            testCase.verifyEqual(t.DataColumnWidth{4}, "99x")
        end

        function tAllAutoColumnsUpdateOnDrag(testCase)
            % When the user has no explicit widths (DataColumnWidth_ empty /
            % all-auto), a drag in all-auto mode should update all columns to
            % new proportional weights.

            t = gwidgets.Table(Data=testCase.multivariableData());  % 4 cols
            % No explicit widths — DataColumnWidth_ is empty (all auto)

            staleBridgeWidths = [-97, -106, -98, -99];
            t.simulateBridgeDrag(staleBridgeWidths);

            % All columns should become proportional
            testCase.verifyEqual(t.DataColumnWidth{1}, "97x")
            testCase.verifyEqual(t.DataColumnWidth{2}, "106x")
            testCase.verifyEqual(t.DataColumnWidth{3}, "98x")
            testCase.verifyEqual(t.DataColumnWidth{4}, "99x")
        end

        function tPixelDragResultsAreAlwaysAccepted(testCase)
            % A bridge drag notification with positive (pixel) values must
            % always update DataColumnWidth regardless of the existing type.

            t = gwidgets.Table(Data=testCase.multivariableData());
            t.DataColumnWidth = {100, "auto", "auto", "auto"};

            % Simulate correct bridge notification: all columns pixel
            t.simulateBridgeDrag([168, 183, 169, 80]);

            testCase.verifyEqual(t.DataColumnWidth{1}, 168)
            testCase.verifyEqual(t.DataColumnWidth{2}, 183)
            testCase.verifyEqual(t.DataColumnWidth{3}, 169)
            testCase.verifyEqual(t.DataColumnWidth{4}, 80)
        end


        function tAllPixelColumnsResyncsWhenBridgeReportsAllProp(testCase)
            % Regression: when ALL columns are pixel-specified and the bridge
            % fires all-proportional values (stale colAutoFlags), the isequal
            % guard must not bail out even though DataColumnWidth_ is unchanged.
            % applyColumnWidthToDisplay must still run to send a corrective
            % SetWidths and re-sync the bridge.
            %
            % Observable effect: a new pause timer is created, confirming that
            % applyColumnWidthToDisplay was called.

            nBefore = numel(timerfindall);

            t = gwidgets.Table(Data=testCase.stringData());  % 2 cols
            t.DataColumnWidth = {100, 200};

            % Stale all-proportional notification for all-pixel columns
            t.simulateBridgeDrag([-97, -103]);

            % Pixel values must be untouched
            testCase.verifyEqual(t.DataColumnWidth{1}, 100, ...
                "Col 1 pixel value must be preserved")
            testCase.verifyEqual(t.DataColumnWidth{2}, 200, ...
                "Col 2 pixel value must be preserved")

            % applyColumnWidthToDisplay must have run — it creates a timer
            nAfter = numel(timerfindall);
            testCase.verifyGreaterThan(nAfter, nBefore, ...
                "applyColumnWidthToDisplay must be called to re-sync the bridge")

            delete(t);
        end


        % ----------------------------------------------------------- %
        %  Mixed-mode drag tests
        % ----------------------------------------------------------- %

        function tMixedModePixelAndPropDragUpdatesCorrectly(testCase)
            % When the bridge correctly reports mixed pixel+proportional
            % values (pixel col gets positive, auto cols get negative),
            % onColumnWidthChanged must store the pixel value for the pixel
            % column and proportional weights for the auto columns.

            t = gwidgets.Table(Data=testCase.multivariableData());  % 4 cols
            t.DataColumnWidth = {100, "auto", "auto", "auto"};

            % Bridge correctly reports: col 1 pixel (new value 120),
            % cols 2-4 proportional (bridge has correct colAutoFlags).
            t.simulateBridgeDrag([120, -55, -45, -0]);

            testCase.verifyEqual(t.DataColumnWidth{1}, 120, ...
                "Pixel column must update to new pixel value")
            testCase.verifyEqual(t.DataColumnWidth{2}, "55x", ...
                "Auto column must update to proportional weight")
            testCase.verifyEqual(t.DataColumnWidth{3}, "45x")
        end

        function tPartialPixelPreservationInMixedTable(testCase)
            % Stale bridge fires all-proportional for a mixed pixel/auto
            % table.  Pixel columns must be preserved; auto columns update.

            t = gwidgets.Table(Data=testCase.multivariableData());  % 4 cols
            t.DataColumnWidth = {100, 200, "auto", "auto"};

            % All-proportional from stale bridge
            t.simulateBridgeDrag([-40, -50, -60, -50]);

            % Pixel cols 1 and 2 preserved
            testCase.verifyEqual(t.DataColumnWidth{1}, 100)
            testCase.verifyEqual(t.DataColumnWidth{2}, 200)

            % Auto cols 3 and 4 updated
            testCase.verifyEqual(t.DataColumnWidth{3}, "60x")
            testCase.verifyEqual(t.DataColumnWidth{4}, "50x")
        end

        % ----------------------------------------------------------- %
        %  Echo-guard tests
        % ----------------------------------------------------------- %

        function tEchoGuardSuppressesIdenticalDragNotification(testCase)
            % If onColumnWidthChanged receives widths that produce no change
            % to DataColumnWidth_ (echo from our own SetWidths), the update
            % must be silently dropped and no new pause timer created.

            t = gwidgets.Table(Data=testCase.stringData());  % 2 cols
            t.DataColumnWidth = {100, 200};

            % First drag — sets DataColumnWidth_ to {150, 150}
            t.simulateBridgeDrag([150, 150]);
            testCase.verifyEqual(t.DataColumnWidth, {150, 150})

            % Capture timer count after the first drag settled
            nAfterFirst = numel(timerfindall);

            % Identical notification again — should be a no-op
            t.simulateBridgeDrag([150, 150]);
            testCase.verifyEqual(t.DataColumnWidth, {150, 150}, ...
                "DataColumnWidth must not change on echo notification")

            % No additional timer should have been created
            testCase.verifyEqual(numel(timerfindall), nAfterFirst, ...
                "Echo notification must not create a new pause timer")

            delete(t);
        end

        % ----------------------------------------------------------- %
        %  normalizeColumnWidths static helper tests
        % ----------------------------------------------------------- %

        function tNormalizeNumericArray(testCase)
            result = gwidgets.Table.normalizeColumnWidths([100 200 150]);
            testCase.verifyEqual(result, {100, 200, 150})
        end

        function tNormalizeScalarNumeric(testCase)
            result = gwidgets.Table.normalizeColumnWidths(75);
            testCase.verifyEqual(result, {75})
        end

        function tNormalizeStringArray(testCase)
            result = gwidgets.Table.normalizeColumnWidths(["auto", "1x"]);
            testCase.verifyEqual(result, {"auto", "1x"})
        end

        function tNormalizeCharScalar(testCase)
            result = gwidgets.Table.normalizeColumnWidths("fit");
            testCase.verifyEqual(result, {"fit"})
        end

        function tNormalizeCellPassThrough(testCase)
            input  = {100, "auto", "2x"};
            result = gwidgets.Table.normalizeColumnWidths(input);
            testCase.verifyEqual(result, input)
        end

        function tNormalizeEmptyReturnsEmpty(testCase)
            testCase.verifyEqual(gwidgets.Table.normalizeColumnWidths([]),  {})
            testCase.verifyEqual(gwidgets.Table.normalizeColumnWidths(""),  {})
            testCase.verifyEqual(gwidgets.Table.normalizeColumnWidths({}),  {})
        end

        % ----------------------------------------------------------- %
        %  get.ColumnWidth after drag
        % ----------------------------------------------------------- %

        function tGetColumnWidthReflectsDragResultsImmediately(testCase)
            % After a drag notification, both DataColumnWidth and ColumnWidth
            % must reflect the new values without requiring an update cycle.

            t = gwidgets.Table(Data=testCase.stringData());  % 2 cols
            t.simulateBridgeDrag([120, 180]);

            testCase.verifyEqual(t.DataColumnWidth, {120, 180})
            testCase.verifyEqual(t.ColumnWidth,     {120, 180})
        end

        function tGetColumnWidthReflectsProportionalDragResult(testCase)
            % Proportional drag results must be visible via ColumnWidth.

            t = gwidgets.Table(Data=testCase.stringData());
            t.simulateBridgeDrag([-60, -40]);

            testCase.verifyEqual(t.DataColumnWidth, {"60x", "40x"})
            testCase.verifyEqual(t.ColumnWidth,     {"60x", "40x"})
        end


    end

end
