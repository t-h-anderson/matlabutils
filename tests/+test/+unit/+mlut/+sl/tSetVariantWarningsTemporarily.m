classdef tSetVariantWarningsTemporarily < matlab.unittest.TestCase

    methods (Test)
        function tRestoresVariantWarningState(testCase)
            warningId = "Simulink:Commands:FindSystemVariantsOptionRemoval";
            originalState = warning("query", char(warningId));
            cleanupObj = onCleanup(@() warning(originalState));

            warning("on", char(warningId));
            cleanupObjs = mlut.sl.setVariantWarningsTemporarily("off");

            offState = warning("query", char(warningId));
            testCase.verifyEqual(string(offState.state), "off");

            for cleanupIndex = 1:numel(cleanupObjs)
                delete(cleanupObjs{cleanupIndex});
            end

            restoredState = warning("query", char(warningId));
            testCase.verifyEqual(string(restoredState.state), "on");

            clear cleanupObj
        end
    end
end
