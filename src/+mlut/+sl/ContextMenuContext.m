classdef ContextMenuContext
    %CONTEXTMENUCONTEXT Adapter for Simulink context menu callback data.

    properties (SetAccess = protected)
        CallbackInfo
    end

    methods
        function obj = ContextMenuContext(callbackInfo)
            arguments
                callbackInfo
            end

            obj.CallbackInfo = callbackInfo;
        end

        function target = contextTarget(obj)
            %CONTEXTTARGET Resolve the selected Simulink block/port/line.

            arguments
                obj (1,1) mlut.sl.ContextMenuContext
            end

            target = obj.emptyTarget();

            selectedObj = obj.selectedObject();
            if isempty(selectedObj)
                return
            end

            handle = mlut.sl.ContextMenuContext.objectHandle(selectedObj);
            if isempty(handle) || handle == -1
                return
            end

            target = obj.targetFromHandle(handle);
        end

        function modelName = currentModelName(obj)
            %CURRENTMODELNAME Resolve the active model from callback data.

            arguments
                obj (1,1) mlut.sl.ContextMenuContext
            end

            modelName = "";
            try
                modelName = string(obj.CallbackInfo.model.Name);
                return
            catch
                % Rich and legacy context menu callbacks expose different shapes.
            end

            target = obj.contextTarget();
            if target.BlockPath == ""
                return
            end

            try
                modelName = string(bdroot(char(target.BlockPath)));
            catch
                % A non-block callback target cannot be resolved to a model root.
                modelName = "";
            end
        end

        function modelPath = currentModelPath(obj)
            %CURRENTMODELPATH Resolve the model file from callback data.

            arguments
                obj (1,1) mlut.sl.ContextMenuContext
            end

            modelName = obj.currentModelName();
            if modelName == ""
                modelPath = "";
                return
            end

            try
                modelPath = string(get_param(char(modelName), "FileName"));
            catch
                % Some callback shapes identify objects without an owning model.
                modelPath = "";
            end
        end
    end

    methods (Access = protected)
        function selectedObj = selectedObject(obj)
            arguments
                obj (1,1) mlut.sl.ContextMenuContext
            end

            selectedObj = [];
            try
                selectedObj = obj.CallbackInfo.getSelection();
            catch
                % Some callback contexts expose only uiObject.
            end

            if ~isempty(selectedObj)
                return
            end

            try
                selectedObj = obj.CallbackInfo.uiObject;
            catch
                % Leave selectedObj empty when the context has no selected object.
                selectedObj = [];
            end
        end

        function target = targetFromHandle(obj, handle)
            arguments
                obj (1,1) mlut.sl.ContextMenuContext
                handle
            end

            target = obj.emptyTarget();

            try
                objectType = string(get_param(handle, "Type"));
            catch
                % Invalid or non-Simulink handles are ignored.
                return
            end

            switch objectType
                case "block"
                    target = obj.targetFromBlock(handle);
                case "port"
                    target = obj.targetFromPort(handle);
                case "line"
                    target = obj.targetFromLine(handle);
                otherwise
                    % Other Simulink object types do not map to block-level app targets.
            end
        end

        function target = targetFromBlock(obj, handle)
            arguments
                obj (1,1) mlut.sl.ContextMenuContext
                handle
            end

            target = obj.emptyTarget();
            target.BlockPath = string(getfullname(handle));

            try
                blockType = string(get_param(handle, "BlockType"));
            catch
                % Block-like callback handles can still miss BlockType.
                return
            end

            if blockType == "Inport" || blockType == "Outport"
                target.PortName = string(get_param(handle, "Name"));
                target.PortType = blockType;
            end
        end

        function target = targetFromPort(obj, handle)
            arguments
                obj (1,1) mlut.sl.ContextMenuContext
                handle
            end

            blockPath = string(get_param(handle, "Parent"));
            portNumber = str2double(string(get_param(handle, "PortNumber")));
            portType = lower(string(get_param(handle, "PortType")));

            target = obj.emptyTarget();
            target.BlockPath = blockPath;
            target.PortName = mlut.sl.ContextMenuContext.portNameForBlockPort(blockPath, portType, portNumber);
            target.PortType = obj.simulinkSignalPortType(portType);
        end

        function target = targetFromLine(obj, handle)
            arguments
                obj (1,1) mlut.sl.ContextMenuContext
                handle
            end

            portHandle = -1;
            try
                portHandle = get_param(handle, "SrcPortHandle");
            catch
                % Lines without a source port cannot resolve to a block target.
            end

            if portHandle == -1
                target = obj.emptyTarget();
                return
            end

            target = obj.targetFromPort(portHandle);
        end

    end

    methods (Static, Access = protected)
        function handle = objectHandle(selectedObj)
            arguments
                selectedObj
            end

            handle = [];
            if isempty(selectedObj)
                return
            end

            try
                if numel(selectedObj) > 1
                    selectedObj = selectedObj(1);
                end
                handle = selectedObj.Handle;
                return
            catch
                % Fall back for numeric-handle callback objects.
            end

            try
                handle = double(selectedObj);
            catch
                % Non-Simulink callback objects are ignored.
                handle = [];
            end
        end

        function name = portNameForBlockPort(blockPath, portType, portNumber)
            arguments
                blockPath (1,1) string
                portType (1,1) string
                portNumber (1,1) double
            end

            name = "";
            if portNumber <= 0
                return
            end

            blockType = string(get_param(char(blockPath), "BlockType"));
            if blockType == "ModelReference"
                names = mlut.sl.ContextMenuContext.modelReferencePortNames(blockPath, portType);
                if portNumber <= numel(names)
                    name = names(portNumber);
                end
                return
            end

            if blockType == "Inport" || blockType == "Outport"
                name = string(get_param(char(blockPath), "Name"));
            end
        end

        function names = modelReferencePortNames(blockPath, portType)
            arguments
                blockPath (1,1) string
                portType (1,1) string
            end

            switch portType
                case "inport"
                    paramName = "InputPortNames";
                case "outport"
                    paramName = "OutputPortNames";
                otherwise
                    names = strings(1, 0);
                    return
            end

            names = mlut.sl.Port.nameList( ...
                get_param(char(blockPath), char(paramName)));
        end

        function portType = simulinkSignalPortType(portType)
            arguments
                portType (1,1) string
            end

            switch portType
                case "inport"
                    portType = "Inport";
                case "outport"
                    portType = "Outport";
                otherwise
                    portType = "";
            end
        end

        function target = emptyTarget()
            target = struct( ...
                BlockPath="", ...
                PortName="", ...
                PortType="");
        end
    end
end
