classdef tWarningStateGuard < matlab.unittest.TestCase

    methods (Test)
        function tRestoresWarningState(testCase)
            warningId = "MATLAB:singularMatrix";
            originalState = warning("query", char(warningId));
            cleanup = onCleanup(@() warning(originalState));

            warning("on", char(warningId));
            warningGuard = mlut.sl.WarningStateGuard( ...
                State="off", ...
                Identifier=warningId);

            offState = warning("query", char(warningId));
            testCase.verifyEqual(string(offState.state), "off");

            delete(warningGuard);

            restoredState = warning("query", char(warningId));
            testCase.verifyEqual(string(restoredState.state), "on");

            clear cleanup
        end
    end
end
