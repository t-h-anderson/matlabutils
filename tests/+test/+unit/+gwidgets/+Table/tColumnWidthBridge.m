classdef tColumnWidthBridge < test.WithExampleTables
    % Unit tests for the MATLAB-side column-width bridge logic.
    %
    % These tests run headlessly (no figure or DOM required) by inspecting
    % the three backing stores.
    %
    % Column width model
    % ------------------
    %   Every column has a type ("Pixel" or "Relative") stored in
    %   DataColumnWidthTypes_.  Two parallel stores always reflect both views:
    %
    %     PixelDataColumnWidths_    – actual pixel value; NaN for Relative until
    %                                 the bridge resolves the container width.
    %     RelativeDataColumnWidths_ – "Nx" weight; missing for Pixel columns
    %                                 until the bridge reports the first drag.
    %
    %   "auto" and "fit" are normalised to "1x" Relative.
    %   The GCD of all resolved pixel widths is used to express relative weights
    %   as small integers (e.g. [200, 110, 220] px → GCD=10 → ["20x","11x","22x"]).
    %
    % Echo suppression (comparison-based)
    % ------------------------------------
    %   The bridge never sends SetWidths; MATLAB drives all layout via
    %   DisplayTable.ColumnWidth.  On receiving ColumnWidthChanged, MATLAB
    %   calls didBridgeWidthsChange to compare the incoming pixel widths against
    %   PixelDataColumnWidths_.  A match (within 1 px) means MATLAB's own CSS
    %   settling — ignored.  A difference means a genuine user drag or resize.

    % ------------------------------------------------------------------ %
    %  normalizeColumnWidths static helper
    % ------------------------------------------------------------------ %
    methods (Test)

        function tNormalizeNumericArray(testCase)
            result = gwidgets.Table.normalizeColumnWidths([100 200 150]);
            testCase.verifyEqual(result, {100, 200, 150})
        end

        function tNormalizeScalarNumeric(testCase)
            result = gwidgets.Table.normalizeColumnWidths(75);
            testCase.verifyEqual(result, {75})
        end

        function tNormalizeStringArray(testCase)
            result = gwidgets.Table.normalizeColumnWidths(["1x", "2x"]);
            testCase.verifyEqual(result, {"1x", "2x"})
        end

        function tNormalizeCharScalar(testCase)
            result = gwidgets.Table.normalizeColumnWidths("1x");
            testCase.verifyEqual(result, {"1x"})
        end

        function tNormalizeCellPassThrough(testCase)
            % "auto" and "fit" are converted to "1x" during normalisation.
            input  = {100, "auto", "2x"};
            result = gwidgets.Table.normalizeColumnWidths(input);
            testCase.verifyEqual(result, {100, "1x", "2x"})
        end

        function tNormalizeAutoToRelative(testCase)
            result = gwidgets.Table.normalizeColumnWidths("auto");
            testCase.verifyEqual(result, {"1x"})
        end

        function tNormalizeFitToRelative(testCase)
            result = gwidgets.Table.normalizeColumnWidths("fit");
            testCase.verifyEqual(result, {"1x"})
        end

        function tNormalizeEmptyReturnsEmpty(testCase)
            testCase.verifyEqual(gwidgets.Table.normalizeColumnWidths([]),  {})
            testCase.verifyEqual(gwidgets.Table.normalizeColumnWidths(""),  {})
            testCase.verifyEqual(gwidgets.Table.normalizeColumnWidths({""}),  {})
            testCase.verifyEqual(gwidgets.Table.normalizeColumnWidths(''),  {})
            testCase.verifyEqual(gwidgets.Table.normalizeColumnWidths({''}),  {})
            testCase.verifyEqual(gwidgets.Table.normalizeColumnWidths({}),  {})
        end

    end

    % ------------------------------------------------------------------ %
    %  gcdPixelWidths static helper
    % ------------------------------------------------------------------ %
    methods (Test)

        function tGcdSimple(testCase)
            testCase.verifyEqual(gwidgets.Table.gcdPixelWidths([200, 110, 220]), 10)
        end

        function tGcdAllSame(testCase)
            testCase.verifyEqual(gwidgets.Table.gcdPixelWidths([100, 100, 100]), 100)
        end

        function tGcdCoprimes(testCase)
            testCase.verifyEqual(gwidgets.Table.gcdPixelWidths([3, 5, 7]), 1)
        end

        function tGcdIgnoresNaN(testCase)
            % NaN entries (unresolved Relative columns) are skipped
            testCase.verifyEqual(gwidgets.Table.gcdPixelWidths([200, NaN, 100]), 100)
        end

        function tGcdAllNanReturnsOne(testCase)
            testCase.verifyEqual(gwidgets.Table.gcdPixelWidths([NaN, NaN]), 1)
        end

    end

    % ------------------------------------------------------------------ %
    %  Initial state and type assignment
    % ------------------------------------------------------------------ %
    methods (Test)

        function tDefaultStateIsAllRelative(testCase)
            % An unset table returns "1x" for every column.
            t = gwidgets.Table(Data=testCase.multivariableData());  % 4 cols
            testCase.verifyEqual(t.DataColumnWidthTypes,   repelem("Relative", 1, 4))
            testCase.verifyEqual(t.ColumnWidth,            {"1x","1x","1x","1x"})
            testCase.verifyEqual(t.DataColumnWidth,        {"1x","1x","1x","1x"})
        end

        function tSetPixelColumnsUpdatesTypes(testCase)
            t = gwidgets.Table(Data=testCase.stringData());  % 2 cols
            t.DataColumnWidth = {100, 200};
            testCase.verifyEqual(t.DataColumnWidthTypes,    ["Pixel","Pixel"])
            testCase.verifyEqual(t.PixelDataColumnWidths,   [100, 200])
            testCase.verifyEqual(t.DataColumnWidth,         {100, 200})
        end

        function tSetMixedColumnTypes(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());  % 4 cols
            t.DataColumnWidth = {100, "1x", "2x", "3x"};
            testCase.verifyEqual(t.DataColumnWidthTypes,   ["Pixel","Relative","Relative","Relative"])
            testCase.verifyEqual(t.PixelDataColumnWidths,  [100, NaN, NaN, NaN])
            testCase.verifyEqual(t.DataColumnWidth,        {100, "1x", "2x", "3x"})
        end

        function tAutoAndFitTreatedAsRelative(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());  % 4 cols
            t.DataColumnWidth = {"auto", "fit", "1x", 100};
            testCase.verifyEqual(t.DataColumnWidthTypes,   ["Relative","Relative","Relative","Pixel"])
            testCase.verifyEqual(t.DataColumnWidth,        {"1x","1x","1x",100})
        end

        function tEmptySetResetsToAllRelative(testCase)
            t = gwidgets.Table(Data=testCase.stringData());  % 2 cols
            t.DataColumnWidth = {100, 200};
            t.DataColumnWidth = {};
            testCase.verifyEqual(t.DataColumnWidthTypes,  ["Relative","Relative"])
            testCase.verifyEqual(t.DataColumnWidth,       {"1x","1x"})
        end

    end

    % ------------------------------------------------------------------ %
    %  ColumnWidth (visible-only) vs DataColumnWidth
    % ------------------------------------------------------------------ %
    methods (Test)

        function tColumnWidthReturnsVisibleSubset(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());  % 4 cols
            t.DataColumnWidth = {100, "1x", 200, "2x"};
            t.HiddenColumnNames = "Categorical";  % hide col 2

            testCase.verifyEqual(t.ColumnWidth,     {100, 200, "2x"})
            testCase.verifyEqual(t.DataColumnWidth, {100, "1x", 200, "2x"})
        end

        function tSetColumnWidthPreservesHiddenWidths(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());  % 4 cols
            t.DataColumnWidth = {100, 200, 150, 80};
            t.HiddenColumnNames = "Categorical";  % hide col 2 (200px)

            t.ColumnWidth = {120, 150, 80};  % set visible cols only

            testCase.verifyEqual(t.DataColumnWidth{1}, 120, "Visible col 1 updated")
            testCase.verifyEqual(t.DataColumnWidth{2}, 200, "Hidden col 2 preserved")
            testCase.verifyEqual(t.DataColumnWidth{3}, 150, "Visible col 3 updated")
            testCase.verifyEqual(t.DataColumnWidth{4}, 80,  "Visible col 4 updated")
        end

        function tColumnWidthTypesReturnsVisibleSubset(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());  % 4 cols
            t.DataColumnWidth = {100, "1x", 200, "2x"};
            t.HiddenColumnNames = "Categorical";  % hide col 2

            testCase.verifyEqual(t.ColumnWidthTypes, ["Pixel","Pixel","Relative"])
        end

    end

    % ------------------------------------------------------------------ %
    %  Store update from bridge (simulateBridgeDrag)
    % ------------------------------------------------------------------ %
    methods (Test)

        function tDragUpdatesBothStores(testCase)
            % After a drag, both PixelDataColumnWidths_ and
            % RelativeDataColumnWidths_ must be updated from the received
            % positive pixel widths using GCD normalisation.
            t = gwidgets.Table(Data=testCase.stringData());  % 2 cols
            t.simulateBridgeDrag([200, 100]);

            testCase.verifyEqual(t.PixelColumnWidths,    [200, 100])
            testCase.verifyEqual(t.RelativeColumnWidths, ["2x", "1x"])
        end

        function tDragGcdNormalisesWeights(testCase)
            % GCD([200, 110, 220]) = 10, so weights are [20x, 11x, 22x].
            t = gwidgets.Table(Data=testCase.multivariableData());  % 4 cols
            t.DataColumnWidth = {200, "1x", "2x", "3x"};
            t.simulateBridgeDrag([200, 110, 220, 110]);

            testCase.verifyEqual(t.PixelColumnWidths,    [200, 110, 220, 110])
            testCase.verifyEqual(t.RelativeColumnWidths, ["20x","11x","22x","11x"])
        end

        function tDragDoesNotChangeColumnTypes(testCase)
            % Drag must never promote/demote a column between Pixel and Relative.
            t = gwidgets.Table(Data=testCase.multivariableData());  % 4 cols
            t.DataColumnWidth = {100, "1x", "2x", "3x"};

            typesBefore = t.DataColumnWidthTypes;
            t.simulateBridgeDrag([120, 80, 160, 40]);

            testCase.verifyEqual(t.DataColumnWidthTypes, typesBefore, ...
                "Types must be unchanged after a drag")
        end

        function tDragPixelWidthsReflectedInColumnWidth(testCase)
            % After a drag the public ColumnWidth getter must read from the
            % correct store based on type: Pixel → pixel value, Relative → weight.
            t = gwidgets.Table(Data=testCase.multivariableData());  % 4 cols
            t.DataColumnWidth = {100, "1x", "2x", "3x"};
            t.simulateBridgeDrag([120, 80, 160, 40]);

            % Col 1 is Pixel → returns the new pixel value
            testCase.verifyEqual(t.ColumnWidth{1}, 120)
            % Cols 2-4 are Relative → returns updated relative weight
            testCase.verifyEqual(t.ColumnWidth{2}, "2x")   % 80/40 = 2
            testCase.verifyEqual(t.ColumnWidth{3}, "4x")   % 160/40 = 4
            testCase.verifyEqual(t.ColumnWidth{4}, "1x")   % 40/40 = 1
        end

    end

    % ------------------------------------------------------------------ %
    %  Echo suppression — didBridgeWidthsChange
    % ------------------------------------------------------------------ %
    methods (Test)

        function tEchoSuppressedWhenWidthsMatch(testCase)
            % If stored pixel widths match the incoming values (within 1 px)
            % didBridgeWidthsChange must return false so the event is ignored.
            t = gwidgets.Table(Data=testCase.stringData());  % 2 cols
            t.simulateBridgeDrag([200, 100]);  % stores: px=[200,100]
            testCase.verifyFalse(t.didBridgeWidthsChange([200, 100]))
            testCase.verifyFalse(t.didBridgeWidthsChange([200, 101]))  % within 1 px
            delete(t);
        end

        function tEchoNotSuppressedWhenWidthsDiffer(testCase)
            t = gwidgets.Table(Data=testCase.stringData());  % 2 cols
            t.simulateBridgeDrag([200, 100]);
            testCase.verifyTrue(t.didBridgeWidthsChange([200, 102]))  % > 1 px
            testCase.verifyTrue(t.didBridgeWidthsChange([150, 100]))
            delete(t);
        end

        function tEchoNotSuppressedWhenStoredNaN(testCase)
            % Relative columns start with NaN pixel store — any reported width
            % must count as changed so the first event is always processed.
            t = gwidgets.Table(Data=testCase.stringData());  % 2 cols
            % default state: all Relative, PixelDataColumnWidths_ = [NaN, NaN]
            testCase.verifyTrue(t.didBridgeWidthsChange([200, 100]))
            delete(t);
        end

        function tEchoSuppressedOnCountMismatch(testCase)
            % Count mismatch (bridge mid-reattach) must return false, not error.
            t = gwidgets.Table(Data=testCase.stringData());  % 2 cols
            t.simulateBridgeDrag([200, 100]);
            testCase.verifyFalse(t.didBridgeWidthsChange([200, 100, 50]))  % 3 widths for 2 cols
            delete(t);
        end

    end

    % ------------------------------------------------------------------ %
    %  DefaultColumnWidths reset
    % ------------------------------------------------------------------ %
    methods (Test)

        function tColumnWidthEmptyResetsToDefault(testCase)
            t = gwidgets.Table(Data=testCase.stringData());  % 2 cols
            t.DefaultColumnWidths = {150, 250};
            t.DataColumnWidth = {100, 200};

            t.ColumnWidth = {};  % reset

            testCase.verifyEqual(t.ColumnWidth, {150, 250})
            testCase.verifyEqual(t.DataColumnWidthTypes, ["Pixel","Pixel"])
        end

        function tColumnWidthEmptyWithNoDefaultResetsToRelative(testCase)
            t = gwidgets.Table(Data=testCase.stringData());  % 2 cols
            t.DataColumnWidth = {100, 200};

            t.ColumnWidth = {};

            testCase.verifyEqual(t.DataColumnWidthTypes, ["Relative","Relative"])
            testCase.verifyEqual(t.ColumnWidth, {"1x","1x"})
        end

    end

    % ------------------------------------------------------------------ %
    %  DataColumnMinWidth / DataColumnMaxWidth constraints
    % ------------------------------------------------------------------ %
    methods (Test)

        function tMinWidthClampsDragBelow(testCase)
            t = gwidgets.Table(Data=testCase.stringData());  % 2 cols
            t.DataColumnMinWidth = 80;
            t.simulateBridgeDrag([50, 120]);

            testCase.verifyEqual(t.PixelColumnWidths, [80, 120])
        end

        function tMaxWidthClampsDragAbove(testCase)
            t = gwidgets.Table(Data=testCase.stringData());  % 2 cols
            t.DataColumnMaxWidth = 200;
            t.simulateBridgeDrag([150, 300]);

            testCase.verifyEqual(t.PixelColumnWidths, [150, 200])
        end

        function tWidthInBoundsNotClamped(testCase)
            t = gwidgets.Table(Data=testCase.stringData());  % 2 cols
            t.DataColumnMinWidth = 50;
            t.DataColumnMaxWidth = 300;
            t.simulateBridgeDrag([100, 200]);

            testCase.verifyEqual(t.PixelColumnWidths, [100, 200])
        end

        function tMinWidthClampsPixelSet(testCase)
            t = gwidgets.Table(Data=testCase.stringData());  % 2 cols
            t.DataColumnMinWidth = 100;
            t.DataColumnWidth = {40, 200};

            testCase.verifyEqual(t.PixelColumnWidths, [100, 200])
        end

        function tMaxWidthClampsPixelSet(testCase)
            t = gwidgets.Table(Data=testCase.stringData());  % 2 cols
            t.DataColumnMaxWidth = 150;
            t.DataColumnWidth = {100, 400};

            testCase.verifyEqual(t.PixelColumnWidths, [100, 150])
        end

        function tRelativeSetNotClamped(testCase)
            % Relative ("Nx") widths have no pixel value — programmatic set is unclamped.
            t = gwidgets.Table(Data=testCase.stringData());  % 2 cols
            t.DataColumnMinWidth = 500;
            t.DataColumnWidth = {"1x", "2x"};

            testCase.verifyEqual(t.DataColumnWidthTypes, ["Relative", "Relative"])
        end

        function tMinExceedsMaxErrors(testCase)
            t = gwidgets.Table(Data=testCase.stringData());
            t.DataColumnMaxWidth = 200;

            testCase.verifyError(@() set(t, "DataColumnMinWidth", 300), ...
                "GraphicsWidgets:Table:InvalidMinColumnWidth");
        end

        function tNegativeMinErrors(testCase)
            t = gwidgets.Table(Data=testCase.stringData());

            testCase.verifyError(@() set(t, "DataColumnMinWidth", -10), ...
                "GraphicsWidgets:Table:InvalidMinColumnWidth");
        end

        function tPerColumnMinClampsOnlyViolatingColumn(testCase)
            % Min only on col 2; col 1 drag below is NOT clamped
            t = gwidgets.Table(Data=testCase.stringData());  % 2 cols
            t.DataColumnMinWidth = [NaN, 100];
            t.simulateBridgeDrag([50, 50]);

            testCase.verifyEqual(t.PixelColumnWidths, [50, 100])
        end

        function tPerColumnMaxClampsOnlyViolatingColumn(testCase)
            % Max only on col 2; col 1 drag above is NOT clamped
            t = gwidgets.Table(Data=testCase.stringData());  % 2 cols
            t.DataColumnMaxWidth = [NaN, 200];
            t.simulateBridgeDrag([300, 300]);

            testCase.verifyEqual(t.PixelColumnWidths, [300, 200])
        end

        function tScalarMinExpandsToBothColumns(testCase)
            t = gwidgets.Table(Data=testCase.stringData());  % 2 cols
            t.DataColumnMinWidth = 80;
            t.simulateBridgeDrag([50, 50]);

            testCase.verifyEqual(t.PixelColumnWidths, [80, 80])
        end


    end

end
