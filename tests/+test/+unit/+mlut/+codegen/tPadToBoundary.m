classdef tPadToBoundary < matlab.unittest.TestCase

    methods (Test)

        function tAlignedInputReturnsUnchanged(testCase)
            words = [1 2 3 4];
            testCase.verifyEqual(mlut.codegen.padToBoundary(words, 2), words)
        end

        function tPadsToRequestedBoundary(testCase)
            testCase.verifyEqual(mlut.codegen.padToBoundary([1 2 3], 4), [1 2 3 0])
        end

        function tEmptyInputReturnsEmptyRow(testCase)
            testCase.verifyEqual(mlut.codegen.padToBoundary([], 4), zeros(1, 0))
        end

        function tSupportsLargerBoundary(testCase)
            testCase.verifyEqual(mlut.codegen.padToBoundary([1 2], 8), [1 2 0 0 0 0 0 0])
        end

    end

end
