classdef tHashColour < matlab.unittest.TestCase

    methods (Test)

        function tReturnsRgbTriple(testCase)
            col = mlut.grfx.hashColour("hello");
            testCase.verifySize(col, [1 3])
        end

        function tComponentsInUnitInterval(testCase)
            % Each component is divided by 999999, so anything outside
            % [0, 1] indicates a regression in the digit-grouping logic.
            col = mlut.grfx.hashColour("hello");
            testCase.verifyGreaterThanOrEqual(col, 0)
            testCase.verifyLessThanOrEqual(col, 1)
        end

        function tDeterministicForSameInput(testCase)
            testCase.verifyEqual( ...
                mlut.grfx.hashColour("alpha"), ...
                mlut.grfx.hashColour("alpha"))
        end

        function tDifferentInputsLikelyDiffer(testCase)
            % Probabilistic, but two short distinct strings hashing to the
            % same RGB triple via this scheme would be a bug worth
            % investigating.
            testCase.verifyNotEqual( ...
                mlut.grfx.hashColour("alpha"), ...
                mlut.grfx.hashColour("beta"))
        end

    end

end
