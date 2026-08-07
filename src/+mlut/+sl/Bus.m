classdef Bus
    %BUS Utilities for Simulink.Bus definitions.

    methods (Static)
        function fields = enumerateFields(busName, dd)
            %ENUMERATEFIELDS Leaf field names for a Simulink.Bus in a data dictionary.

            arguments
                busName (1,1) string
                dd (1,1) Simulink.data.Dictionary
            end

            cacheKey = mlut.sl.Bus.fieldCacheKey("enumerate", busName, dd);
            [fields, found] = mlut.sl.internal.BusFieldCache.get(cacheKey);
            if found
                return
            end

            fields = mlut.sl.Bus.enumerateFieldsImpl( ...
                busName, dd, "", string.empty(1,0));
            mlut.sl.internal.BusFieldCache.set(cacheKey, fields);
        end

        function fields = topLevelFields(busName, dd)
            %TOPLEVELFIELDS Direct element names for a Simulink.Bus in a data dictionary.

            arguments
                busName (1,1) string
                dd (1,1) Simulink.data.Dictionary
            end

            cacheKey = mlut.sl.Bus.fieldCacheKey("top", busName, dd);
            [fields, found] = mlut.sl.internal.BusFieldCache.get(cacheKey);
            if found
                return
            end

            bus = mlut.sl.Bus.resolveDefinition(busName, dd);
            fields = mlut.sl.Bus.elementNames(bus);
            mlut.sl.internal.BusFieldCache.set(cacheKey, fields);
        end

        function fields = topLevelFieldsForModel(busName, modelName)
            %TOPLEVELFIELDSFORMODEL Direct bus element names from a model's dictionary.

            arguments
                busName (1,1) string
                modelName (1,1) string
            end

            cacheKey = mlut.sl.Bus.modelFieldCacheKey("top-model", busName, modelName);
            [fields, found] = mlut.sl.internal.BusFieldCache.get(cacheKey);
            if found
                return
            end

            bus = mlut.sl.DataDictionary.busObjectForModel( ...
                modelName, busName, Optional=true);
            fields = mlut.sl.Bus.elementNames(bus);
            mlut.sl.internal.BusFieldCache.set(cacheKey, fields);
        end

        function [elementTable, busTable] = elementsFromDictionary(dictName, busName, nvp)
            %ELEMENTSFROMDICTIONARY Flatten bus elements from a Simulink data dictionary.

            arguments
                dictName (1,1) string
                busName (1,1) string
                nvp.IncludeImported (1,1) logical = false
                nvp.Optional (1,1) logical = false
            end

            inputBusName = busName;
            busName = mlut.sl.Bus.objectName(inputBusName);
            if busName == ""
                busName = strip(inputBusName);
            end

            busObj = mlut.sl.DataDictionary.busObject( ...
                dictName, busName, Optional=nvp.Optional);
            if isempty(busObj)
                elementTable = mlut.sl.Bus.emptyElementTable();
                busTable = mlut.sl.Bus.emptyBusObjectTable();
                return
            end

            busObjects = dictionary(string.empty(1,0), cell.empty(1,0));
            busObjects(busName) = {busObj};
            [rows, busObjects] = mlut.sl.Bus.collectElements( ...
                dictName, "", busObj, string.empty(1,0), busObjects, busName, ...
                IncludeImported=nvp.IncludeImported, ...
                Optional=nvp.Optional);

            elementTable = mlut.sl.Bus.rowsToElementTable(rows);
            busTable = mlut.sl.Bus.busObjectsToTable(busObjects);
        end

        function name = objectName(dataType)
            %OBJECTNAME Extract the bus object name from a Simulink data type string.

            arguments
                dataType (1,1) string
            end

            name = "";
            dataType = strip(dataType);
            if startsWith(dataType, "Bus:")
                name = strip(extractAfter(dataType, "Bus:"));
            end
        end

        function tf = isBusType(dataType)
            %ISBUSTYPE True when a Simulink data type names a bus object.

            arguments
                dataType (1,1) string
            end

            tf = mlut.sl.Bus.objectName(dataType) ~= "";
        end

        function dataType = dataTypeString(busName)
            %DATATYPESTRING Format a bus object name for OutDataTypeStr.

            arguments
                busName (1,1) string
            end

            dataType = "Bus: " + strip(busName);
        end
    end

    methods (Static, Access = private)
        function fields = enumerateFieldsImpl(busName, dd, prefix, ancestry)
            arguments
                busName (1,1) string
                dd (1,1) Simulink.data.Dictionary
                prefix (1,1) string
                ancestry (1,:) string
            end

            bus = mlut.sl.Bus.resolveDefinition(busName, dd);
            if isempty(bus)
                fields = string.empty(1,0);
                return
            end
            if any(ancestry == busName)
                error("mlut:sl:cyclicBusDefinition", ...
                    "Bus '%s' references itself recursively.", busName);
            end

            ancestry = [ancestry, busName];
            chunks = cell(1,0);
            for k = 1:numel(bus.Elements)
                elem = bus.Elements(k);
                elemName = string(elem.Name);
                fullName = mlut.sl.Bus.qualifyField(prefix, elemName);
                nestedBus = mlut.sl.Bus.nestedBusName(elem.DataType);
                if nestedBus == ""
                    chunks{end+1} = fullName; %#ok<AGROW>
                    continue
                end

                nestedFields = mlut.sl.Bus.enumerateFieldsImpl( ...
                    nestedBus, dd, fullName, ancestry);
                if isempty(nestedFields)
                    error("mlut:sl:missingNestedBus", ...
                        "Bus '%s' references nested bus '%s' via element '%s'.", ...
                        busName, nestedBus, fullName);
                end
                chunks{end+1} = nestedFields; %#ok<AGROW>
            end
            if isempty(chunks)
                fields = string.empty(1,0);
                return
            end

            fields = [chunks{:}];
        end

        function [rows, busObjects] = collectElements( ...
                dictName, nestedBusName, busObj, elementPath, busObjects, ancestry, nvp)
            arguments
                dictName (1,1) string
                nestedBusName (1,1) string
                busObj (1,1) Simulink.Bus
                elementPath (1,:) string
                busObjects (1,1) dictionary
                ancestry (1,:) string
                nvp.IncludeImported (1,1) logical = false
                nvp.Optional (1,1) logical = false
            end

            chunks = cell(1,0);
            elements = busObj.Elements;
            for elementIndex = 1:numel(elements)
                element = elements(elementIndex);
                elementName = string(element.Name);
                nextElementPath = [elementPath, elementName];
                row = struct( ...
                    NestedBusName=nestedBusName, ...
                    ElementName=elementName, ...
                    ElementBusPath=strjoin(nextElementPath, "/"), ...
                    DataType=string(element.DataType), ...
                    Dimensions=string(mat2str(element.Dimensions)));
                chunks{end+1} = row; %#ok<AGROW>

                childBusName = mlut.sl.Bus.objectName(element.DataType);
                if childBusName == ""
                    continue
                end
                if any(ancestry == childBusName)
                    error("mlut:sl:cyclicBusDefinition", ...
                        "Bus '%s' references itself recursively.", childBusName);
                end

                childBusObj = mlut.sl.DataDictionary.busObject( ...
                    dictName, childBusName, ...
                    Optional=nvp.Optional);
                if isempty(childBusObj)
                    continue
                end
                if ~nvp.IncludeImported && strcmp(childBusObj.DataScope, "Imported")
                    continue
                end

                busObjects(childBusName) = {childBusObj};
                [childRows, busObjects] = mlut.sl.Bus.collectElements( ...
                    dictName, childBusName, childBusObj, nextElementPath, busObjects, ...
                    [ancestry, childBusName], ...
                    IncludeImported=nvp.IncludeImported, ...
                    Optional=nvp.Optional);
                if ~isempty(childRows)
                    chunks{end+1} = childRows; %#ok<AGROW>
                end
            end

            if isempty(chunks)
                rows = struct.empty(1,0);
            else
                rows = [chunks{:}];
            end
        end

        function elementTable = rowsToElementTable(rows)
            if isempty(rows)
                elementTable = mlut.sl.Bus.emptyElementTable();
                return
            end

            elementTable = struct2table(rows);
        end

        function elementTable = emptyElementTable()
            nestedBusName = strings(0,1);
            elementName = strings(0,1);
            elementBusPath = strings(0,1);
            dataType = strings(0,1);
            dimensions = strings(0,1);
            elementTable = table( ...
                nestedBusName, elementName, elementBusPath, dataType, dimensions, ...
                VariableNames=["NestedBusName", "ElementName", "ElementBusPath", "DataType", "Dimensions"]);
        end

        function busTable = busObjectsToTable(busObjects)
            busNames = reshape(string(keys(busObjects)), [], 1);
            busObject = reshape(values(busObjects), [], 1);
            busTable = table(busNames, busObject, VariableNames=["BusName", "BusObject"]);
        end

        function busTable = emptyBusObjectTable()
            busName = strings(0,1);
            busObject = cell(0,1);
            busTable = table(busName, busObject, VariableNames=["BusName", "BusObject"]);
        end

        function bus = resolveDefinition(busName, dd)
            arguments
                busName (1,1) string
                dd (1,1) Simulink.data.Dictionary
            end

            cacheKey = mlut.sl.Bus.fieldCacheKey("definition", busName, dd);
            [bus, found] = mlut.sl.internal.BusDefinitionCache.get(cacheKey);
            if found
                return
            end

            try
                section = getSection(dd, "Design Data");
                entry = getEntry(section, char(busName));
                bus = getValue(entry);
            catch
                % Callers distinguish "no bus definition" from malformed
                % nested bus references after the top-level lookup returns.
                bus = [];
                mlut.sl.internal.BusDefinitionCache.set(cacheKey, bus);
                return
            end

            if ~isa(bus, "Simulink.Bus")
                bus = [];
            end
            mlut.sl.internal.BusDefinitionCache.set(cacheKey, bus);
        end

        function fields = elementNames(bus)
            arguments
                bus Simulink.Bus {mustBeScalarOrEmpty}
            end

            if isempty(bus)
                fields = string.empty(1,0);
                return
            end

            fields = strings(1, numel(bus.Elements));
            for k = 1:numel(bus.Elements)
                fields(k) = string(bus.Elements(k).Name);
            end
        end

        function name = nestedBusName(dataType)
            arguments
                dataType (1,1) string
            end

            name = mlut.sl.Bus.objectName(dataType);
        end

        function fullName = qualifyField(prefix, name)
            arguments
                prefix (1,1) string
                name (1,1) string
            end

            if prefix == ""
                fullName = name;
            else
                fullName = prefix + "." + name;
            end
        end

        function cacheKey = fieldCacheKey(kind, busName, dd)
            arguments
                kind (1,1) string
                busName (1,1) string
                dd (1,1) Simulink.data.Dictionary
            end

            dictKey = mlut.sl.Bus.dictionaryKey(dd);
            if dictKey == ""
                cacheKey = "";
                return
            end

            normalBusName = mlut.sl.Bus.objectName(busName);
            if normalBusName == ""
                normalBusName = strip(busName);
            end
            cacheKey = kind + "|" + dictKey + "|" + normalBusName;
        end

        function cacheKey = modelFieldCacheKey(kind, busName, modelName)
            arguments
                kind (1,1) string
                busName (1,1) string
                modelName (1,1) string
            end

            modelKey = modelName;
            if bdIsLoaded(modelName)
                try
                    fileName = string(get_param(char(modelName), "FileName"));
                    if fileName ~= ""
                        modelKey = fileName;
                    end
                catch
                end
            end

            normalBusName = mlut.sl.Bus.objectName(busName);
            if normalBusName == ""
                normalBusName = strip(busName);
            end
            cacheKey = kind + "|" + modelKey + "|" + normalBusName;
        end

        function dictKey = dictionaryKey(dd)
            arguments
                dd (1,1) Simulink.data.Dictionary
            end

            dictKey = "";
            try
                dictKey = string(dd.filepath);
            catch
                try
                    dictKey = string(dd.filepath());
                catch
                    return
                end
            end
            dictKey = strip(reshape(dictKey, 1, []));
            if isempty(dictKey) || ismissing(dictKey(1))
                dictKey = "";
            else
                dictKey = dictKey(1);
            end
        end

    end
end
