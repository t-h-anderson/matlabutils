classdef tGraphicsLeakFixture < matlab.unittest.TestCase

    methods (Test)
        function tEnumerateFindsNestedGraphics(testCase)
            fig = uifigure(Visible="off");
            testCase.addTeardown(@()test.unit.fixtures.tGraphicsLeakFixture.deleteIfValid(fig));
            button = uibutton(fig);

            handles = fixtures.GraphicsLeakFixture.enumerate();

            testCase.verifyTrue(any(handles == fig))
            testCase.verifyTrue(any(handles == button))
        end

        function tTeardownDeletesLeaks(testCase)
            fixture = fixtures.GraphicsLeakFixture();
            fixture.setup();
            fig = uifigure(Visible="off");
            testCase.addTeardown(@()test.unit.fixtures.tGraphicsLeakFixture.deleteIfValid(fig));

            testCase.verifyError(@()fixture.teardown(), "MLUT:Test:GraphicsLeak")
            testCase.verifyFalse(isvalid(fig))
        end

        function tTeardownFailsOnRemoval(testCase)
            fig = uifigure(Visible="off");
            testCase.addTeardown(@()test.unit.fixtures.tGraphicsLeakFixture.deleteIfValid(fig));
            fixture = fixtures.GraphicsLeakFixture();
            fixture.setup();

            delete(fig);

            testCase.verifyError(@()fixture.teardown(), "MLUT:Test:GraphicsLeak")
        end
    end

    methods (Static, Access = private)
        function deleteIfValid(handle)
            if ~isempty(handle) && isvalid(handle)
                delete(handle)
            end
        end
    end
end
