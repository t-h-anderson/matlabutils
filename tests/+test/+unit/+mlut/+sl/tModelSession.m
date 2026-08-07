classdef tModelSession < matlab.unittest.TestCase

    methods (Test)
        function tClosesModelOpenedBySession(testCase)
            [modelName, modelPath] = createTempModel(testCase);

            modelSession = mlut.sl.ModelSession(modelPath);

            testCase.verifyTrue(bdIsLoaded(char(modelName)));
            testCase.verifyFalse(modelSession.WasLoaded);

            delete(modelSession);

            testCase.verifyFalse(bdIsLoaded(char(modelName)));
        end

        function tPreservesPreviouslyLoadedModel(testCase)
            [modelName, modelPath] = createTempModel(testCase);
            load_system(char(modelPath));

            modelSession = mlut.sl.ModelSession(modelPath);

            testCase.verifyTrue(modelSession.WasLoaded);

            delete(modelSession);

            testCase.verifyTrue(bdIsLoaded(char(modelName)));
        end

        function tNameFromInputAcceptsModelPathBlockPathOrName(testCase)
            [modelName, modelPath] = createTempModel(testCase);

            testCase.verifyEqual(mlut.sl.ModelSession.nameFromInput(modelName), modelName);
            testCase.verifyEqual(mlut.sl.ModelSession.nameFromInput(modelPath), modelName);
            testCase.verifyEqual( ...
                mlut.sl.ModelSession.nameFromInput(modelName + "/Subsystem/Block"), ...
                modelName);
        end
    end
end

function [modelName, modelPath] = createTempModel(testCase)
tmpDir = string(tempname);
mkdir(char(tmpDir));
modelName = "ModelSessionFixture" + string(randi(1e9));
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
