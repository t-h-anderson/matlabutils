classdef MATLABFunctionBlock
    %MATLABFUNCTIONBLOCK Utilities for MATLAB Function blocks.

    methods (Static)
        function tf = isBlock(blockPath)
            % Test whether a loaded block is a MATLAB Function block.
            arguments
                blockPath (1,1) string
            end

            [cachedValue, found] = mlut.sl.internal.MATLABFunctionBlockCache.get( ...
                "isBlock", blockPath);
            if found
                tf = cachedValue;
                return
            end

            tf = false;
            try
                tf = string(get_param(char(blockPath), "SFBlockType")) == "MATLAB Function";
            catch
                % Non-Stateflow Simulink blocks do not expose SFBlockType.
            end
            mlut.sl.internal.MATLABFunctionBlockCache.set("isBlock", blockPath, tf);
        end

        function script = script(blockPath)
            % Read the MATLAB source from a loaded MATLAB Function block.
            arguments
                blockPath (1,1) string
            end

            [cachedScript, found] = mlut.sl.internal.MATLABFunctionBlockCache.get( ...
                "script", blockPath);
            if found
                script = cachedScript;
                return
            end

            script = "";
            try
                cfg = get_param(char(blockPath), "MATLABFunctionConfiguration");
                script = string(cfg.FunctionScript);
            catch
                % Non-MATLAB Function blocks do not expose this configuration.
            end
            mlut.sl.internal.MATLABFunctionBlockCache.set("script", blockPath, script);
        end

        function fieldMap = fieldMap(blockPath)
            % Map simple MATLAB Function output fields to input fields.
            arguments
                blockPath (1,1) string
            end

            [cachedMap, found] = mlut.sl.internal.MATLABFunctionBlockCache.get( ...
                "fieldMap", blockPath);
            if found
                fieldMap = cachedMap;
                return
            end

            script = mlut.sl.MATLABFunctionBlock.script(blockPath);
            fieldMap = mlut.sl.MATLABFunctionBlock.fieldMapDictionary(script);
            mlut.sl.internal.MATLABFunctionBlockCache.set( ...
                "fieldMap", blockPath, fieldMap);
        end

        function fieldMap = fieldMapDictionary(script)
            % Field map from simple MATLAB Function code.
            arguments
                script (1,1) string
            end

            fieldMap = mlut.sl.MATLABFunctionBlock.fieldMapDictionaryImpl( ...
                script, string.empty(1,0));
        end
    end

    methods (Static, Access = private)
        function fieldMap = fieldMapDictionaryImpl(script, helperStack)
            % Parse direct field assignments and simple helper calls.
            arguments
                script (1,1) string
                helperStack (1,:) string
            end

            fieldMap = dictionary(string.empty, string.empty);
            lines = splitlines(script);
            for lineIdx = 1:numel(lines)
                lineText = strtrim(lines(lineIdx));
                if lineText == "" || startsWith(lineText, "%")
                    continue
                end

                tokens = regexp(lineText, ...
                    "^\w+\.(\w+(?:\.\w+)*)\s*=\s*\w+\.(\w+(?:\.\w+)*)\s*;?$", ...
                    "tokens", "once");
                if ~isempty(tokens)
                    fieldMap(string(tokens{1})) = string(tokens{2});
                    continue
                end

                helperCall = regexp(lineText, ...
                    "^\w+\s*=\s*(\w+)\(\w+\)\s*;?$", ...
                    "tokens", "once");
                if isempty(helperCall)
                    continue
                end

                helperMap = mlut.sl.MATLABFunctionBlock.parseHelperFunction( ...
                    string(helperCall{1}), helperStack);
                helperKeys = keys(helperMap);
                for helperIdx = 1:numel(helperKeys)
                    fieldMap(helperKeys(helperIdx)) = helperMap(helperKeys(helperIdx));
                end
            end
        end

        function fieldMap = parseHelperFunction(functionName, helperStack)
            % Load and parse a helper function while avoiding helper cycles.
            arguments
                functionName (1,1) string
                helperStack (1,:) string
            end

            fieldMap = dictionary(string.empty, string.empty);
            if any(helperStack == functionName)
                return
            end

            helperPath = string(which(functionName));
            if helperPath == ""
                return
            end

            helperKey = [functionName, helperPath];
            [cachedMap, found] = mlut.sl.internal.MATLABFunctionBlockCache.get( ...
                "helper", helperKey);
            if found
                fieldMap = cachedMap;
                return
            end

            try
                script = string(fileread(helperPath));
            catch
                mlut.sl.internal.MATLABFunctionBlockCache.set( ...
                    "helper", helperKey, fieldMap);
                return
            end

            fieldMap = mlut.sl.MATLABFunctionBlock.fieldMapDictionaryImpl( ...
                script, [helperStack, functionName]);
            mlut.sl.internal.MATLABFunctionBlockCache.set( ...
                "helper", helperKey, fieldMap);
        end
    end
end
