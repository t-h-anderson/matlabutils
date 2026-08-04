classdef tUtilities < matlab.unittest.TestCase

    methods (Test)

        function tSignalsToBusCreatesNestedBusStructure(testCase)
            [modelName, ~, outerBus, signalInput] = testCase.createWrapperModel();
            add_block("built-in/Outport", modelName + "/BusOut");

            mlut.sl.wrapper.signalsToBus(signalInput, modelName, "Src", "BusOut/1", "Creator");

            testCase.verifyEqual(string(get_param(modelName + "/Creator", "BlockType")), "BusCreator")
            testCase.verifyEqual(string(get_param(modelName + "/Src_Value", "BlockType")), "Inport")
            testCase.verifyEqual(string(get_param(modelName + "/Creator_2", "BlockType")), "BusCreator")
            testCase.verifyEqual(string(get_param(modelName + "/Src_Inner_Mode", "BlockType")), "Inport")
            testCase.verifyEqual(string(get_param(modelName + "/ConvertSrc_Inner_Mode", "BlockType")), "DataTypeConversion")
            testCase.verifyEqual(string(get_param(modelName + "/Creator", "OutDataTypeStr")), "Bus: OuterBus")
            testCase.verifyEqual(string(get_param(modelName + "/Creator_2", "OutDataTypeStr")), "Bus: InnerBus")
        end

        function tVectorToBusCreatesSelectorsAndReshapeFreeLeafs(testCase)
            [modelName, ~, ~, signalInput] = testCase.createWrapperModel();
            add_block("built-in/Outport", modelName + "/BusOut");

            [ports, idx, idxRange] = mlut.sl.wrapper.vectorToBus( ...
                signalInput, modelName, "VectorIn", "BusOut/1", "VectorCreator", 0, true);

            testCase.verifyEqual(idx, 3)
            testCase.verifyEqual(numel(idxRange), 3)
            testCase.verifyEqual(numel(ports), 3)
            testCase.verifyEqual(string(get_param(modelName + "/VectorIn", "BlockType")), "Inport")
            testCase.verifyEqual(string(get_param(modelName + "/VectorCreator", "BlockType")), "BusCreator")
            selectors = find_system(modelName, "SearchDepth", 1, "BlockType", "Selector");
            testCase.verifyNumElements(selectors, 3)
            testCase.verifyEqual(string(get_param(modelName + "/VectorIn_Inner_Mode_toInt", "BlockType")), "DataTypeConversion")
        end

        function tBusToSignalsCreatesNestedSelectorsAndOutports(testCase)
            [modelName, ~, outerBus] = testCase.createWrapperModel();
            add_block("built-in/Inport", modelName + "/BusIn");

            mlut.sl.wrapper.busToSignals(outerBus, modelName, "BusIn/1", "Out", "Selector");

            testCase.verifyEqual(string(get_param(modelName + "/Selector", "BlockType")), "BusSelector")
            testCase.verifyEqual(string(get_param(modelName + "/Out_Value", "BlockType")), "Outport")
            testCase.verifyEqual(string(get_param(modelName + "/Selector_2", "BlockType")), "BusSelector")
            testCase.verifyEqual(string(get_param(modelName + "/Out_Inner_InnerValue", "BlockType")), "Outport")
            testCase.verifyEqual(string(get_param(modelName + "/ConvertOut_Inner_Mode", "BlockType")), "DataTypeConversion")
        end

        function tBusToVectorCreatesConcatenatedOutput(testCase)
            [modelName, ~, outerBus] = testCase.createWrapperModel();
            add_block("built-in/Inport", modelName + "/BusIn");

            mlut.sl.wrapper.busToVector(outerBus, modelName, "BusIn/1", "VectorOut", "Selector", true);

            testCase.verifyEqual(string(get_param(modelName + "/Selector", "BlockType")), "BusSelector")
            testCase.verifyEqual(string(get_param(modelName + "/VectorOut", "BlockType")), "Outport")
            testCase.verifyEqual(string(get_param(modelName + "/VectorOut_Value", "BlockType")), "DataTypeConversion")
            testCase.verifyEqual(string(get_param(modelName + "/VectorOut_Inner_InnerValue", "BlockType")), "DataTypeConversion")
            testCase.verifyEqual(string(get_param(modelName + "/ToVector", "BlockType")), "Concatenate")
        end

    end

    methods (Access = private)

        function [modelName, modelPath, outerBus, signalInput] = createWrapperModel(testCase)
            folder = fixtures.SimulinkTestHelper.makeTempFolder(testCase);
            modelName = "mlutWrapper" + erase(mlut.uniqueID(), "-");
            modelPath = fixtures.SimulinkTestHelper.createSavedModel(testCase, folder, modelName);

            enumClassName = "mlutTestEnum" + erase(mlut.uniqueID(), "-");
            fixtures.SimulinkTestHelper.writeEnumClass(testCase, folder, enumClassName);

            load_system(modelPath);
            [innerBus, outerBus, signalInput] = fixtures.SimulinkTestHelper.createNestedBusFixture(enumClassName);
            fixtures.SimulinkTestHelper.assignBusesToBaseWorkspace(testCase, innerBus, outerBus);
        end

    end

end
