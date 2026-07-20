classdef tUtilities < matlab.unittest.TestCase

    methods (Test)
        function tUpdateManagerSuppressesAndRemovesByCount(testCase)
            manager = gwidgets.internal.UpdateManager();

            manager.addSuppression("A", Times=2);

            testCase.verifyFalse(manager.doRun("A"))
            testCase.verifyFalse(manager.doRun("A"))
            testCase.verifyTrue(manager.doRun("A"))
        end

        function tUpdateManagerFullySuppressesAndSuppressAll(testCase)
            manager = gwidgets.internal.UpdateManager();

            manager.addSuppression("A");
            manager.addSuppression("B", Times=2);
            manager.setSuppressAll(true);

            testCase.verifyFalse(manager.doRun("A", Remove=0))
            testCase.verifyFalse(manager.doRun("B"))

            manager.setSuppressAll(false);
            manager.removeSuppression("A");

            testCase.verifyTrue(manager.doRun("A"))
            testCase.verifyFalse(manager.doRun("B"))
            testCase.verifyTrue(manager.doRun("B"))
        end

        function tDrawnowToggleAndRunCounts(testCase)
            drawnowState = gwidgets.internal.Drawnow.make(true);

            testCase.verifyFalse(drawnowState.IsEnabled)

            gwidgets.internal.Drawnow.toggleDrawnow(false);
            gwidgets.internal.Drawnow.run();
            gwidgets.internal.Drawnow.toggleDrawnow(true);
            gwidgets.internal.Drawnow.runWithPause();
            gwidgets.internal.Drawnow.toggleDrawnow();

            testCase.verifyEqual(drawnowState.Skipped, 1)
            testCase.verifyEqual(drawnowState.Total, 1)
            testCase.verifyFalse(drawnowState.IsEnabled)
        end

        function tStyleControllerStaticHelpers(testCase)
            style = uistyle(BackgroundColor=[0.1 0.2 0.3]);

            functionStyle = gwidgets.internal.table.StyleController.createStyle(style, "row", @(tbl)1);
            queryStyle = gwidgets.internal.table.StyleController.createStyle(style, "cell", "needle");
            numericStyle = gwidgets.internal.table.StyleController.createStyle(style, "column", 1);
            defaultStyle = gwidgets.internal.table.StyleController.defaultGroupHeaderStyle(style);
            remaining = gwidgets.internal.table.StyleController.removeStyle([functionStyle, queryStyle, numericStyle], 2);

            testCase.verifyEqual(functionStyle.Target, "row")
            testCase.verifyEqual(queryStyle.Target, "cell")
            testCase.verifyEqual(numericStyle.indices(), 1)
            testCase.verifyEqual(defaultStyle.SelectionMode, gwidgets.table.SelectionMode.Display)
            testCase.verifyEqual([remaining.Target], ["row", "column"])
            testCase.verifyEmpty(gwidgets.internal.table.StyleController.removeStyle(remaining))
            testCase.verifyError( ...
                @()gwidgets.internal.table.StyleController.createStyle(style, "row", {1}), ...
                "GraphicsWidgets:Table:StyleTarget")
        end
    end
end
