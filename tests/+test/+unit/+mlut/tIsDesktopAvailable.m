classdef tIsDesktopAvailable < matlab.unittest.TestCase

    methods (Test)
        function tReturnsLogicalScalar(testCase)
            testCase.verifySize(mlut.isDesktopAvailable(), [1, 1]);
            testCase.verifyClass(mlut.isDesktopAvailable(), "logical");
        end
    end
end
