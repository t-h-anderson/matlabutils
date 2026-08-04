classdef SimulinkTestHelper

    methods (Static)

        function folder = makeTempFolder(testCase)
            folder = string(tempname);
            mkdir(folder);
            testCase.addTeardown(@() fixtures.SimulinkTestHelper.deleteFolder(folder));
        end

        function modelPath = createSavedModel(testCase, folder, modelName)
            modelPath = fullfile(folder, modelName + ".slx");
            new_system(modelName);
            save_system(modelName, modelPath);
            close_system(modelName, 0);
            testCase.addTeardown(@() fixtures.SimulinkTestHelper.closeModel(modelName));
        end

        function writeEnumClass(testCase, folder, className)
            filePath = fullfile(folder, className + ".m");
            fid = fopen(filePath, "w");
            cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>
            fprintf(fid, "classdef %s < Simulink.IntEnumType\n", className);
            fprintf(fid, "    enumeration\n");
            fprintf(fid, "        Off(0)\n");
            fprintf(fid, "        On(1)\n");
            fprintf(fid, "    end\n");
            fprintf(fid, "end\n");

            addpath(folder);
            testCase.addTeardown(@() rmpath(folder));
        end

        function [innerBus, outerBus, signalInput] = createNestedBusFixture(enumClassName)
            if nargin < 1
                enumClassName = "";
            end

            modeType = "double";
            if strlength(enumClassName) > 0
                modeType = "Enum: " + enumClassName;
            end

            innerBus = Simulink.Bus;
            innerBus.Description = "InnerBus";
            innerBus.Elements = [
                fixtures.SimulinkTestHelper.createBusElement("InnerValue", "double")
                fixtures.SimulinkTestHelper.createBusElement("Mode", modeType)
            ];

            outerBus = Simulink.Bus;
            outerBus.Description = "OuterBus";
            outerBus.Elements = [
                fixtures.SimulinkTestHelper.createBusElement("Value", "double")
                fixtures.SimulinkTestHelper.createBusElement("Inner", "Bus: InnerBus")
            ];

            emptyChild = struct("BusObject", "", "SignalName", "", "Children", struct.empty(1, 0));
            innerInput = struct( ...
                "BusObject", "InnerBus", ...
                "SignalName", "InnerSig", ...
                "Children", repmat(emptyChild, 1, numel(innerBus.Elements)));

            signalInput = struct( ...
                "BusObject", "OuterBus", ...
                "SignalName", "OuterSig", ...
                "Children", [emptyChild, innerInput]);
        end

        function assignBusesToModel(modelName, varargin)
            workspace = get_param(modelName, "ModelWorkspace");
            for i = 1:numel(varargin)
                bus = varargin{i};
                assignin(workspace, bus.Description, bus);
            end
        end

        function assignBusesToBaseWorkspace(testCase, varargin)
            names = strings(1, numel(varargin));
            for i = 1:numel(varargin)
                bus = varargin{i};
                names(i) = string(bus.Description);
                assignin("base", char(names(i)), bus);
            end
            clearCommand = "clear " + strjoin(names, " ");
            testCase.addTeardown(@() evalin("base", clearCommand));
        end

        function value = createDictionaryEntry(dictionaryPath, entryName, entryValue)
            dictionary = Simulink.data.dictionary.create(dictionaryPath);
            cleaner = onCleanup(@() dictionary.close()); %#ok<NASGU>
            designData = dictionary.getSection("Design Data");
            value = Simulink.Parameter;
            value.Value = entryValue;
            addEntry(designData, entryName, value);
            saveChanges(dictionary);
        end

    end

    methods (Static, Access = private)

        function element = createBusElement(name, dataType)
            element = Simulink.BusElement;
            element.Name = char(name);
            element.DataType = char(dataType);
        end

        function closeModel(modelName)
            if bdIsLoaded(modelName)
                close_system(modelName, 0);
            end
        end

        function deleteFolder(folder)
            if isfolder(folder)
                rmdir(folder, "s");
            end
        end

    end

end
