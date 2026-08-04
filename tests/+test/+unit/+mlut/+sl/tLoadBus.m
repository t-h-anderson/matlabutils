classdef tLoadBus < matlab.unittest.TestCase

    methods (Test)

        function tLoadsBusFromModelWorkspace(testCase)
            folder = fixtures.SimulinkTestHelper.makeTempFolder(testCase);
            modelName = "mlutLoadBus";
            modelPath = fixtures.SimulinkTestHelper.createSavedModel(testCase, folder, modelName);

            load_system(modelPath);
            [innerBus, outerBus] = fixtures.SimulinkTestHelper.createNestedBusFixture();
            fixtures.SimulinkTestHelper.assignBusesToModel(modelName, innerBus, outerBus);
            save_system(modelName);
            close_system(modelName, 0);

            bus = mlut.sl.loadBus(modelPath, "Bus: OuterBus");

            testCase.verifyClass(bus, "Simulink.Bus")
            testCase.verifyEqual(string(bus.Description), "OuterBus")
            testCase.verifyEqual(numel(bus.Elements), 2)
        end

        function tMissingBusReturnsEmptyBus(testCase)
            folder = fixtures.SimulinkTestHelper.makeTempFolder(testCase);
            modelName = "mlutMissingBus";
            modelPath = fixtures.SimulinkTestHelper.createSavedModel(testCase, folder, modelName);

            bus = mlut.sl.loadBus(modelPath, "Bus: MissingBus");

            testCase.verifyClass(bus, "Simulink.Bus")
            testCase.verifyEmpty(bus)
        end

    end

end
