classdef tDragLinker < matlab.unittest.TestCase
    %TDRAGLINKER Test suite for DragLinker and DragLinkerFactory
    %
    %   Tests only public interfaces - no access to private methods/properties
    %
    %   Run tests with: runtests('test.system.gwidgets.tDragLinker')
    %   View results:   table(runtests('test.system.gwidgets.tDragLinker'))

    properties (TestParameter)
        DragKey = {"control", "alt", "shift", ""}
    end

    properties
        TestFigure
    end

    % ================================================================== %
    methods (TestMethodSetup)
        function createTestFigure(testCase)
            % Create a fresh figure for each test
            testCase.TestFigure = uifigure("Name", "Test Figure", ...
                "Position", [100 100 600 400], ...
                "Visible", "off");  % Hidden for speed
        end
    end

    methods (TestMethodTeardown)
        function closeTestFigure(testCase)
            % Clean up after each test
            if ~isempty(testCase.TestFigure) && isvalid(testCase.TestFigure)
                delete(testCase.TestFigure);
            end
        end
    end

    % ================================================================== %
    % DragLinker Constructor Tests
    % ================================================================== %

    methods (Test)

        function testBasicConstruction(testCase)
            % Test basic DragLinker construction
            btn = uibutton(testCase.TestFigure, "Position", [20 150 100 30]);
            pnl = uipanel(testCase.TestFigure, "Position", [20 20 200 100]);

            callback = @(src,tgt,pt) [];
            dl = gwidgets.DragLinker(btn, pnl, callback);

            testCase.verifyClass(dl, "gwidgets.DragLinker");
            testCase.verifyEqual(dl.Source, btn);
            testCase.verifyEqual(dl.Target, pnl);
            testCase.verifyEqual(dl.Callback, callback);
        end

        function testConstructionWithDragKey(testCase, DragKey)
            % Test construction with different drag keys
            btn = uibutton(testCase.TestFigure);
            pnl = uipanel(testCase.TestFigure);
            callback = @(s,t,p) [];

            dl = gwidgets.DragLinker(btn, pnl, callback, ...
                "DragKey", DragKey, ...
                "UseItemGhost", true);

            testCase.verifyClass(dl, "gwidgets.DragLinker");
            % Cannot verify DragKey directly (private property)
            % But construction should succeed
        end

        function testInvalidDragKeyThrowsError(testCase)
            % Test that invalid drag keys are rejected
            btn = uibutton(testCase.TestFigure);
            pnl = uipanel(testCase.TestFigure);
            callback = @(s,t,p) [];

            testCase.verifyError(...
                @() gwidgets.DragLinker(btn, pnl, callback, "DragKey", "invalid"), ...
                "MATLAB:validators:mustBeMember");
        end

        function testComponentWithoutFigureThrowsError(testCase)
            % Test that components without parent figures are rejected
            btn = uibutton("Parent", []);  % No parent
            pnl = uipanel(testCase.TestFigure);
            callback = @(s,t,p) [];

            testCase.verifyError(...
                @() gwidgets.DragLinker(btn, pnl, callback), ...
                "DragLinker:invalidParent");

            delete(btn);
        end

        function testDelete(testCase)
            % Test that delete works without errors
            btn = uibutton(testCase.TestFigure);
            pnl = uipanel(testCase.TestFigure);
            dl = gwidgets.DragLinker(btn, pnl, @(s,t,p) []);

            testCase.verifyWarningFree(@() delete(dl));
            testCase.verifyFalse(isvalid(dl));
        end

        function testDisplayMethod(testCase)
            % Test that disp() doesn't error
            btn = uibutton(testCase.TestFigure, "Text", "Drag Me");
            pnl = uipanel(testCase.TestFigure, "Title", "Drop Here");
            dl = gwidgets.DragLinker(btn, pnl, @(s,t,p) []);

            testCase.verifyWarningFree(@() disp(dl));
        end

    end

    % ================================================================== %
    % DragLinker Component Support Tests
    % ================================================================== %

    methods (Test)

        function testListBoxAsSource(testCase)
            % Test listbox as drag source
            lst = uilistbox(testCase.TestFigure, ...
                "Items", ["A", "B", "C"], ...
                "Position", [20 150 100 100]);
            pnl = uipanel(testCase.TestFigure, "Position", [150 20 200 100]);

            dl = gwidgets.DragLinker(lst, pnl, @(s,t,p) [], "UseItemGhost", true);

            testCase.verifyClass(dl, "gwidgets.DragLinker");
            testCase.verifyEqual(dl.Source, lst);
            testCase.verifyEqual(dl.Target, pnl);
        end

        function testTreeAsSource(testCase)
            % Test tree as drag source
            tree = uitree(testCase.TestFigure, "Position", [20 150 100 100]);
            uitreenode(tree, "Text", "Node1");
            uitreenode(tree, "Text", "Node2");
            pnl = uipanel(testCase.TestFigure, "Position", [150 20 200 100]);

            dl = gwidgets.DragLinker(tree, pnl, @(s,t,p) [], "UseItemGhost", true);

            testCase.verifyClass(dl, "gwidgets.DragLinker");
            testCase.verifyEqual(dl.Source, tree);
        end

        function testUIAxesAsSource(testCase)
            % Test uiaxes as source
            ax1 = uiaxes(testCase.TestFigure, "Position", [20 150 200 150]);
            ax2 = uiaxes(testCase.TestFigure, "Position", [250 150 200 150]);

            dl = gwidgets.DragLinker(ax1, ax2, @(s,t,p) []);

            testCase.verifyClass(dl, "gwidgets.DragLinker");
            testCase.verifyEqual(dl.Source, ax1);
            testCase.verifyEqual(dl.Target, ax2);
        end

        function testUIPanelAsTarget(testCase)
            % Test uipanel as drop target
            btn = uibutton(testCase.TestFigure, "Position", [20 150 100 30]);
            pnl = uipanel(testCase.TestFigure, "Position", [20 20 200 100]);

            dl = gwidgets.DragLinker(btn, pnl, @(s,t,p) []);

            testCase.verifyEqual(dl.Target, pnl);
        end

    end

    % ================================================================== %
    % DragLinker Public Static Method Tests
    % ================================================================== %

    methods (Test)

        function testGetAbsolutePosition(testCase)
            % Test absolute position calculation
            pnl = uipanel(testCase.TestFigure, "Position", [50 50 200 200]);
            btn = uibutton(pnl, "Position", [20 20 100 30]);

            pos = gwidgets.DragLinker.getAbsolutePosition(btn);

            testCase.verifyEqual(pos(1:2), [70 70], "AbsTol", 0.1);
            testCase.verifyEqual(pos(3:4), [100 30], "AbsTol", 0.1);
        end

        function testGetAbsolutePositionInvalidHandle(testCase)
            % Test that invalid handles return NaN
            btn = uibutton(testCase.TestFigure);
            delete(btn);

            pos = gwidgets.DragLinker.getAbsolutePosition(btn);

            testCase.verifyTrue(all(isnan(pos)));
        end

        function testPointInRect(testCase)
            % Test rectangle hit testing
            rect = [10 10 100 50];

            % Point inside
            testCase.verifyTrue(gwidgets.DragLinker.pointInRect([50 30], rect));

            % Points outside
            testCase.verifyFalse(gwidgets.DragLinker.pointInRect([5 5], rect));
            testCase.verifyFalse(gwidgets.DragLinker.pointInRect([120 30], rect));
            testCase.verifyFalse(gwidgets.DragLinker.pointInRect([50 70], rect));

            % Edge cases (on boundary)
            testCase.verifyTrue(gwidgets.DragLinker.pointInRect([10 10], rect));
            testCase.verifyTrue(gwidgets.DragLinker.pointInRect([110 60], rect));
        end

        function testComponentLabel(testCase)
            % Test component label generation
            btn = uibutton(testCase.TestFigure, "Text", "Click");
            lst = uilistbox(testCase.TestFigure, "Items", ["A", "B"]);
            pnl = uipanel(testCase.TestFigure, "Title", "Panel");
            tree = uitree(testCase.TestFigure);
            ax = uiaxes(testCase.TestFigure);

            testCase.verifySubstring(gwidgets.DragLinker.componentLabel(btn), "uibutton");
            testCase.verifySubstring(gwidgets.DragLinker.componentLabel(lst), "uilistbox");
            testCase.verifySubstring(gwidgets.DragLinker.componentLabel(pnl), "uipanel");
            testCase.verifySubstring(gwidgets.DragLinker.componentLabel(tree), "uitree");
            testCase.verifySubstring(gwidgets.DragLinker.componentLabel(ax), "uiaxes");
        end

        function testFigureAtCursor(testCase)
            % Test figureAtCursor finds visible figures
            % Make test figure visible for this test
            testCase.TestFigure.Visible = "on";
            drawnow;

            figs = gwidgets.DragLinker.figureAtCursor();

            % Should return an array (might be empty if cursor not over figure)
            testCase.verifyClass(figs, "matlab.ui.Figure");

            testCase.TestFigure.Visible = "off";
        end

        function testCursorPositionForFigure(testCase)
            % Test cursor position calculation
            testCase.TestFigure.Visible = "on";
            drawnow;

            pos = gwidgets.DragLinker.cursorPositionForFigure(testCase.TestFigure);

            % Should return a 1x2 position
            testCase.verifySize(pos, [1, 2]);
            testCase.verifyClass(pos, "double");

            testCase.TestFigure.Visible = "off";
        end

    end

    % ================================================================== %
    % DragLinker Event Tests
    % ================================================================== %

    methods (Test)

        function testEventsExist(testCase)
            % Verify that required events are defined
            btn = uibutton(testCase.TestFigure);
            pnl = uipanel(testCase.TestFigure);
            dl = gwidgets.DragLinker(btn, pnl, @(s,t,p) []);

            % Get metaclass info
            mc = metaclass(dl);
            eventNames = {mc.EventList.Name};

            testCase.verifyTrue(ismember("DragStarted", eventNames));
            testCase.verifyTrue(ismember("DragSuccessful", eventNames));
            testCase.verifyTrue(ismember("DragFailed", eventNames));
        end

        function testCanAddEventListeners(testCase)
            % Verify we can add listeners to events
            btn = uibutton(testCase.TestFigure);
            pnl = uipanel(testCase.TestFigure);
            dl = gwidgets.DragLinker(btn, pnl, @(s,t,p) []);

            % Should not error
            testCase.verifyWarningFree(@() ...
                addlistener(dl, 'DragStarted', @(~,~) []));
            testCase.verifyWarningFree(@() ...
                addlistener(dl, 'DragSuccessful', @(~,~) []));
            testCase.verifyWarningFree(@() ...
                addlistener(dl, 'DragFailed', @(~,~) []));
        end

    end

    % ================================================================== %
    % DragLinkerFactory Tests
    % ================================================================== %

    methods (Test)

        function testFactorySingleton(testCase)
            % Test that factory returns same instance
            factory1 = gwidgets.internal.DragLinkerFactory.make();
            factory2 = gwidgets.internal.DragLinkerFactory.make();

            testCase.verifyEqual(factory1, factory2);
        end

        function testFactoryClear(testCase)
            % Test factory clearing creates new instance
            factory1 = gwidgets.internal.DragLinkerFactory.make();
            gwidgets.internal.DragLinkerFactory.make(true);  % Clear
            factory2 = gwidgets.internal.DragLinkerFactory.make();

            testCase.verifyNotEqual(factory1, factory2);
        end

        function testAddSource(testCase)
            % Test adding a source
            gwidgets.internal.DragLinkerFactory.make(true);  % Fresh start

            btn = uibutton(testCase.TestFigure);
            gwidgets.internal.DragLinkerFactory.addSource("TestButton", btn);

            factory = gwidgets.internal.DragLinkerFactory.make();
            testCase.verifyTrue(factory.Sources.isKey("TestButton"));
            testCase.verifyEqual(factory.Sources("TestButton"), btn);
        end

        function testAddDestination(testCase)
            % Test adding a destination
            gwidgets.internal.DragLinkerFactory.make(true);

            pnl = uipanel(testCase.TestFigure);
            gwidgets.internal.DragLinkerFactory.addDestination("TestPanel", pnl);

            factory = gwidgets.internal.DragLinkerFactory.make();
            testCase.verifyTrue(factory.Destinations.isKey("TestPanel"));
            testCase.verifyEqual(factory.Destinations("TestPanel"), pnl);
        end

        function testAddLinkCreatesLinker(testCase)
            % Test that link creates DragLinker when both sides exist
            gwidgets.internal.DragLinkerFactory.make(true);

            btn = uibutton(testCase.TestFigure);
            pnl = uipanel(testCase.TestFigure);

            gwidgets.internal.DragLinkerFactory.addSource("Btn1", btn);
            gwidgets.internal.DragLinkerFactory.addDestination("Pnl1", pnl);
            gwidgets.internal.DragLinkerFactory.addLink("Btn1", "Pnl1");

            factory = gwidgets.internal.DragLinkerFactory.make();
            linkKeys = factory.DragLinkers.keys();

            testCase.verifyNotEmpty(linkKeys);
            testCase.verifyGreaterThanOrEqual(numel(linkKeys), 1);
        end

        function testAddLinkBeforeComponents(testCase)
            % Test that link waits for components
            gwidgets.internal.DragLinkerFactory.make(true);

            % Define link first
            gwidgets.internal.DragLinkerFactory.addLink("Btn1", "Pnl1");

            factory = gwidgets.internal.DragLinkerFactory.make();
            testCase.verifyEmpty(factory.DragLinkers.keys());

            % Now add components
            btn = uibutton(testCase.TestFigure);
            pnl = uipanel(testCase.TestFigure);

            gwidgets.internal.DragLinkerFactory.addSource("Btn1", btn);
            gwidgets.internal.DragLinkerFactory.addDestination("Pnl1", pnl);

            factory = gwidgets.internal.DragLinkerFactory.make();
            testCase.verifyNotEmpty(factory.DragLinkers.keys());
        end

        function testRemoveInvalid(testCase)
            % Test that removeInvalid cleans up deleted components
            gwidgets.internal.DragLinkerFactory.make(true);

            btn = uibutton(testCase.TestFigure);
            gwidgets.internal.DragLinkerFactory.addSource("TempButton", btn);

            factory = gwidgets.internal.DragLinkerFactory.make();
            testCase.verifyTrue(factory.Sources.isKey("TempButton"));

            delete(btn);
            factory.removeInvalid();

            testCase.verifyFalse(factory.Sources.isKey("TempButton"));
        end

        function testClearDragLinkers(testCase)
            % Test clearing all linkers
            gwidgets.internal.DragLinkerFactory.make(true);

            btn = uibutton(testCase.TestFigure);
            pnl = uipanel(testCase.TestFigure);

            gwidgets.internal.DragLinkerFactory.addSource("Btn1", btn);
            gwidgets.internal.DragLinkerFactory.addDestination("Pnl1", pnl);
            gwidgets.internal.DragLinkerFactory.addLink("Btn1", "Pnl1");

            factory = gwidgets.internal.DragLinkerFactory.make();
            testCase.verifyNotEmpty(factory.DragLinkers.keys());

            factory.clearDragLinkers();
            testCase.verifyEmpty(factory.DragLinkers.keys());
        end

        function testMultipleDragKeys(testCase)
            % Test that different drag keys create separate linkers
            gwidgets.internal.DragLinkerFactory.make(true);

            btn = uibutton(testCase.TestFigure);
            pnl = uipanel(testCase.TestFigure);

            gwidgets.internal.DragLinkerFactory.addSource("Btn1", btn);
            gwidgets.internal.DragLinkerFactory.addDestination("Pnl1", pnl);
            gwidgets.internal.DragLinkerFactory.addLink("Btn1", "Pnl1", "DragKey", "control");
            gwidgets.internal.DragLinkerFactory.addLink("Btn1", "Pnl1", "DragKey", "alt");

            factory = gwidgets.internal.DragLinkerFactory.make();
            testCase.verifyEqual(numel(factory.DragLinkers.keys()), 2);
        end

        function testAddReparentLink(testCase)
            % Test drag-to-reparent link creation
            gwidgets.internal.DragLinkerFactory.make(true);

            btn1 = uibutton(testCase.TestFigure, "Position", [20 150 100 30]);
            btn2 = uibutton(testCase.TestFigure, "Position", [150 150 100 30]);

            gwidgets.internal.DragLinkerFactory.addSource("Btn1", btn1);
            gwidgets.internal.DragLinkerFactory.addDestination("Btn2", btn2);
            gwidgets.internal.DragLinkerFactory.addDragToReparentLink("Btn1", "Btn2");

            factory = gwidgets.internal.DragLinkerFactory.make();
            testCase.verifyNotEmpty(factory.DragLinkers.keys());

            % Verify a linker was created
            testCase.verifyGreaterThanOrEqual(numel(factory.DragLinkers.keys()), 1);
        end

    end

    % ================================================================== %
    % Integration Tests
    % ================================================================== %

    methods (Test)

        function testListBoxToListBox(testCase)
            % Integration: factory with listboxes
            gwidgets.internal.DragLinkerFactory.make(true);

            lst1 = uilistbox(testCase.TestFigure, ...
                "Items", ["A", "B", "C"], ...
                "Position", [20 150 100 100]);
            lst2 = uilistbox(testCase.TestFigure, ...
                "Items", {}, ...
                "Position", [150 150 100 100]);

            gwidgets.internal.DragLinkerFactory.addSource("List1", lst1);
            gwidgets.internal.DragLinkerFactory.addDestination("List2", lst2);
            gwidgets.internal.DragLinkerFactory.addLink("List1", "List2", "UseItemGhost", true);

            factory = gwidgets.internal.DragLinkerFactory.make();
            testCase.verifyNotEmpty(factory.DragLinkers.keys());

            % Verify linker was created with correct source/target
            linkerKeys = factory.DragLinkers.keys();
            linker = factory.DragLinkers(linkerKeys(1));
            testCase.verifyEqual(linker.Source, lst1);
            testCase.verifyEqual(linker.Target, lst2);
        end

        function testTreeToTree(testCase)
            % Integration: factory with trees
            gwidgets.internal.DragLinkerFactory.make(true);

            tree1 = uitree(testCase.TestFigure, "Position", [20 150 100 100]);
            tree2 = uitree(testCase.TestFigure, "Position", [150 150 100 100]);

            gwidgets.internal.DragLinkerFactory.addSource("Tree1", tree1);
            gwidgets.internal.DragLinkerFactory.addDestination("Tree2", tree2);
            gwidgets.internal.DragLinkerFactory.addLink("Tree1", "Tree2");

            factory = gwidgets.internal.DragLinkerFactory.make();
            testCase.verifyNotEmpty(factory.DragLinkers.keys());
        end

        function testCrossComponentTypes(testCase)
            % Integration: listbox to tree
            gwidgets.internal.DragLinkerFactory.make(true);

            lst = uilistbox(testCase.TestFigure, ...
                "Items", ["A", "B"], ...
                "Position", [20 150 100 100]);
            tree = uitree(testCase.TestFigure, "Position", [150 150 100 100]);

            gwidgets.internal.DragLinkerFactory.addSource("List1", lst);
            gwidgets.internal.DragLinkerFactory.addDestination("Tree1", tree);
            gwidgets.internal.DragLinkerFactory.addLink("List1", "Tree1");

            factory = gwidgets.internal.DragLinkerFactory.make();
            testCase.verifyNotEmpty(factory.DragLinkers.keys());
        end

    end

end  % classdef
