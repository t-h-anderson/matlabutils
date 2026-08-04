classdef tFindParam < matlab.unittest.TestCase

    methods (Test)

        function tResolvesModelWorkspaceParameter(testCase)
            folder = fixtures.SimulinkTestHelper.makeTempFolder(testCase);
            modelName = "mlutFindParamModelWs";
            modelPath = fixtures.SimulinkTestHelper.createSavedModel(testCase, folder, modelName);

            load_system(modelPath);
            add_block("simulink/Math Operations/Gain", modelName + "/Gain");
            set_param(modelName + "/Gain", "Gain", "KModel");
            workspace = get_param(modelName, "ModelWorkspace");
            assignin(workspace, "KModel", 42);
            save_system(modelName);
            close_system(modelName, 0);

            testCase.verifyEqual(mlut.sl.findParam(modelPath, "KModel"), 42)
        end

        function tResolvesDataDictionaryParameter(testCase)
            folder = fixtures.SimulinkTestHelper.makeTempFolder(testCase);
            modelName = "mlutFindParamDictionary";
            modelPath = fixtures.SimulinkTestHelper.createSavedModel(testCase, folder, modelName);
            dictionaryPath = fullfile(folder, "params.sldd");
            fixtures.SimulinkTestHelper.createDictionaryEntry(dictionaryPath, "KDict", 17);

            load_system(modelPath);
            originalFolder = pwd;
            cd(folder);
            testCase.addTeardown(@() cd(originalFolder));
            set_param(modelName, "DataDictionary", "params.sldd");
            add_block("simulink/Math Operations/Gain", modelName + "/Gain");
            set_param(modelName + "/Gain", "Gain", "KDict");
            save_system(modelName);
            close_system(modelName, 0);

            testCase.verifyEqual(mlut.sl.findParam(modelPath, "KDict"), 17)
        end

        function tBaseWorkspaceParameterThrows(testCase)
            folder = fixtures.SimulinkTestHelper.makeTempFolder(testCase);
            modelName = "mlutFindParamBaseWs";
            modelPath = fixtures.SimulinkTestHelper.createSavedModel(testCase, folder, modelName);

            assignin("base", "KBase", 5);
            testCase.addTeardown(@() evalin("base", "clear KBase"));

            load_system(modelPath);
            add_block("simulink/Math Operations/Gain", modelName + "/Gain");
            set_param(modelName + "/Gain", "Gain", "KBase");
            save_system(modelName);
            close_system(modelName, 0);

            testCase.verifyError( ...
                @() mlut.sl.findParam(modelPath, "KBase"), ...
                "mlut:sl:findParam:BaseWorkspaceUnsupported")
        end

    end

end
