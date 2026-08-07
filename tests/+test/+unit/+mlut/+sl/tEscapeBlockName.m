classdef tEscapeBlockName < matlab.unittest.TestCase

    methods (Test)
        function tEscapesSlashForSimulinkBlockNames(testCase)
            testCase.verifyEqual(mlut.sl.escapeBlockName("Subsystem/Signal"), "Subsystem//Signal");
        end
    end
end
