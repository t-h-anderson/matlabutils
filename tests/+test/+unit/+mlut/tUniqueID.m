classdef tUniqueID < matlab.unittest.TestCase

    methods (Test)

        function tDefaultReturnsSingleString(testCase)
            id = mlut.uniqueID();
            testCase.verifyClass(id, "string")
            testCase.verifySize(id, [1 1])
            testCase.verifyGreaterThan(strlength(id), 0)
        end

        function tConsecutiveCallsAreDistinct(testCase)
            % Collisions within a session would defeat the whole point.
            a = mlut.uniqueID();
            b = mlut.uniqueID();
            testCase.verifyNotEqual(a, b)
        end

        function tBatchReturnsRequestedCount(testCase)
            ids = mlut.uniqueID(5);
            testCase.verifyEqual(numel(ids), 5)
            testCase.verifyEqual(numel(unique(ids)), 5)
        end

    end

end
