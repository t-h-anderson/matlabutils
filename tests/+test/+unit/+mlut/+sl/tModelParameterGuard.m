classdef tModelParameterGuard < matlab.unittest.TestCase

    methods (Test)
        function tRestoresCapturedModelParameter(testCase)
            [modelName, modelPath] = createTempModel(testCase);
            modelSession = mlut.sl.ModelSession(modelPath);
            cleanup = onCleanup(@() delete(modelSession));

            originalStopTime = string(get_param(char(modelName), "StopTime"));
            parameterGuard = mlut.sl.ModelParameterGuard(modelName, "StopTime");

            set_param(char(modelName), "StopTime", "20");

            delete(parameterGuard);

            testCase.verifyEqual(string(get_param(char(modelName), "StopTime")), originalStopTime);

            clear cleanup
        end
    end
end

function [modelName, modelPath] = createTempModel(testCase)
tmpDir = string(tempname);
mkdir(char(tmpDir));
modelName = "ModelParameterGuardFixture" + string(randi(1e9));
modelPath = string(fullfile(tmpDir, modelName + ".slx"));

new_system(char(modelName));
save_system(char(modelName), char(modelPath));
close_system(char(modelName), 0);

testCase.addTeardown(@() closeIfLoaded(modelName));
testCase.addTeardown(@() removeTempFolder(tmpDir));
end

function closeIfLoaded(modelName)
if bdIsLoaded(char(modelName))
    close_system(char(modelName), 0);
end
end

function removeTempFolder(folder)
if isfolder(char(folder))
    rmdir(char(folder), "s");
end
end
