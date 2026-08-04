classdef tLoadSystem < matlab.unittest.TestCase

    methods (Test)

        function tLoadsModelByPathAndReturnsCleanup(testCase)
            folder = fixtures.SimulinkTestHelper.makeTempFolder(testCase);
            modelName = "mlutLoadByPath";
            modelPath = fixtures.SimulinkTestHelper.createSavedModel(testCase, folder, modelName);

            [mdlh, cleanup] = mlut.sl.loadSystem(modelPath);

            testCase.verifyClass(mdlh, "double")
            testCase.verifyTrue(bdIsLoaded(modelName))
            testCase.verifyClass(cleanup, "onCleanup")

            cleanup = [];
            testCase.verifyFalse(bdIsLoaded(modelName))
        end

        function tLoadsModelByNameWhenOnPath(testCase)
            folder = fixtures.SimulinkTestHelper.makeTempFolder(testCase);
            modelName = "mlutLoadByName";
            fixtures.SimulinkTestHelper.createSavedModel(testCase, folder, modelName);
            addpath(folder);
            testCase.addTeardown(@() rmpath(folder));

            [~, cleanup] = mlut.sl.loadSystem(modelName);

            testCase.verifyTrue(bdIsLoaded(modelName))
            cleanup = [];
            testCase.verifyFalse(bdIsLoaded(modelName))
        end

        function tAlreadyLoadedModelReturnsEmptyCleanup(testCase)
            folder = fixtures.SimulinkTestHelper.makeTempFolder(testCase);
            modelName = "mlutAlreadyLoaded";
            modelPath = fixtures.SimulinkTestHelper.createSavedModel(testCase, folder, modelName);
            load_system(modelPath);

            [~, cleanup] = mlut.sl.loadSystem(modelPath);

            testCase.verifyEmpty(cleanup)
            testCase.verifyTrue(bdIsLoaded(modelName))
        end

    end

end
