classdef tColumnWidthBridge < test.WithExampleTables
    % Unit tests for the MATLAB-side column-width bridge logic.
    %
    % These tests run headlessly (no figure or DOM required) by inspecting
    % MATLAB-visible properties.  They cover:
    %
    %   - Echo suppression via seq: programmatic ColumnWidthChanged echoes
    %     must be ignored using the sequence-number round-trip.
    %
    %   - Pixel-column preservation: when the bridge's colAutoFlags are stale
    %     and a pixel column is incorrectly reported as proportional, the
    %     stored pixel width must be preserved and a corrective SetWidths
    %     sent (verified by an incremented LastSentSeq_).
    %
    %   - Proportional-weight update: auto/nx columns correctly update their
    %     weights when reported as negative values by the bridge.

    % ------------------------------------------------------------------ %
    %  Echo-guard (seq-based) tests
    % ------------------------------------------------------------------ %
    methods (Test)

        function tSeqIncrementedOnEachApply(testCase)
            % Every call to applyColumnWidthToDisplay must increment
            % LastSentSeq_ so each SetWidths carries a unique seq.

            t = gwidgets.Table(Data=testCase.multivariableData());
            seq0 = t.getLastSentSeq();

            t.DataColumnWidth = {100, 100, 100, 100};   % first apply
            seq1 = t.getLastSentSeq();

            t.DataColumnWidth = {200, 200, 200, 200};   % second apply
            seq2 = t.getLastSentSeq();

            testCase.verifyGreaterThan(seq1, seq0, "Seq must increment on first apply")
            testCase.verifyGreaterThan(seq2, seq1, "Seq must increment on second apply")
            delete(t);
        end

        function tSeqStaysConstantWhenNothingApplied(testCase)
            % LastSentSeq_ must not change between applyColumnWidthToDisplay
            % calls (e.g. after a simulateBridgeDrag that doesn't trigger
            % applyColumnWidthToDisplay because widths are unchanged).

            t = gwidgets.Table(Data=testCase.stringData());  % 2 cols
            t.DataColumnWidth = {100, 200};
            seq1 = t.getLastSentSeq();

            % Identical drag — echo guard in onColumnWidthChanged bails early.
            t.simulateBridgeDrag([100, 200]);
            seq2 = t.getLastSentSeq();

            testCase.verifyEqual(seq2, seq1, ...
                "Seq must not change when DataColumnWidth_ is unchanged")
            delete(t);
        end

        function tSeqIncrementedWhenTypeChangePrevented(testCase)
            % When the bridge reports a pixel column as proportional (stale
            % colAutoFlags), typeChangePrevented triggers applyColumnWidthToDisplay
            % to send a corrective SetWidths.  LastSentSeq_ must increment.

            t = gwidgets.Table(Data=testCase.stringData());  % 2 cols
            t.DataColumnWidth = {100, 200};
            seqBefore = t.getLastSentSeq();

            % Stale all-proportional notification for all-pixel columns.
            t.simulateBridgeDrag([-97, -103]);

            seqAfter = t.getLastSentSeq();
            testCase.verifyGreaterThan(seqAfter, seqBefore, ...
                "applyColumnWidthToDisplay must increment seq when sending corrective SetWidths")
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
            % Observable effect: applyColumnWidthToDisplay increments
            % LastSentSeq_.  We compare the seq before and after the drag.

            t = gwidgets.Table(Data=testCase.stringData());  % 2 cols
            t.DataColumnWidth = {100, 200};
            seqBefore = t.getLastSentSeq();

            % Stale all-proportional notification for all-pixel columns
            t.simulateBridgeDrag([-97, -103]);

            % Pixel values must be untouched
            testCase.verifyEqual(t.DataColumnWidth{1}, 100, ...
                "Col 1 pixel value must be preserved")
            testCase.verifyEqual(t.DataColumnWidth{2}, 200, ...
                "Col 2 pixel value must be preserved")

            % applyColumnWidthToDisplay must have run: seq incremented.
            testCase.verifyGreaterThan(t.getLastSentSeq(), seqBefore, ...
                "applyColumnWidthToDisplay must increment LastSentSeq_ when sending corrective SetWidths")

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
            t.simulateBridgeDrag([120, -55, -45, -50]);

            testCase.verifyEqual(t.DataColumnWidth{1}, 120, ...
                "Pixel column must update to new pixel value")
            testCase.verifyEqual(t.DataColumnWidth{2}, "55x", ...
                "Auto column must update to proportional weight")
            testCase.verifyEqual(t.DataColumnWidth{3}, "45x")
            testCase.verifyEqual(t.DataColumnWidth{4}, "50x")
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
        %  Echo-guard isequal tests
        % ----------------------------------------------------------- %

        function tEchoGuardSuppressesIdenticalDragNotification(testCase)
            % If onColumnWidthChanged receives widths that produce no change
            % to DataColumnWidth_ (echo from our own SetWidths), the update
            % must be silently dropped and LastSentSeq_ must not change.

            t = gwidgets.Table(Data=testCase.stringData());  % 2 cols
            t.DataColumnWidth = {100, 200};

            % First drag — sets DataColumnWidth_ to {150, 150}
            t.simulateBridgeDrag([150, 150]);
            testCase.verifyEqual(t.DataColumnWidth, {150, 150})

            % Capture seq after the first drag settled
            seqAfterFirst = t.getLastSentSeq();

            % Identical notification again — should be a no-op
            t.simulateBridgeDrag([150, 150]);
            testCase.verifyEqual(t.DataColumnWidth, {150, 150}, ...
                "DataColumnWidth must not change on echo notification")

            % No corrective SetWidths issued: seq must stay the same
            testCase.verifyEqual(t.getLastSentSeq(), seqAfterFirst, ...
                "Echo notification must not trigger applyColumnWidthToDisplay")

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
            testCase.verifyEqual(gwidgets.Table.normalizeColumnWidths({""}),  {})
            testCase.verifyEqual(gwidgets.Table.normalizeColumnWidths(''),  {})
            testCase.verifyEqual(gwidgets.Table.normalizeColumnWidths({''}),  {})
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
