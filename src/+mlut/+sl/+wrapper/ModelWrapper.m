classdef ModelWrapper
    properties
        WrapperSuffix = "_wrap"
        Strategies (1,:) mlut.sl.wrapper.strategy.Strategy = mlut.sl.wrapper.strategy.connectInput.DefaultStrategy.empty(1,0)
    end

    properties (Access = protected)
        Model (1,1) string = string(NaN) % Original model name
        MdlRef (1,1) string = string(NaN) % Model reference name
    end

    properties (Access = protected, Dependent)
        WrapperName (1,1) string % Generate the wrapper name
    end

    methods

        function obj = ModelWrapper(nvp)
            arguments
                nvp.Strategies (1,:) mlut.sl.wrapper.strategy.Strategy = mlut.sl.wrapper.strategy.connectInput.DefaultStrategy.empty(1,0)
                nvp.WrapperSuffix (1,1) string = "_wrap"
            end

            obj.Strategies = nvp.Strategies;
            obj.WrapperSuffix = nvp.WrapperSuffix;

        end

        function [wrapperName, cWrap] = wrapModel(obj, model, nvp)
            arguments
                obj
                model (1,1) string
                nvp.AutoArrangeSystem (1,1) logical = false
            end

            obj.Model = model;
            obj.MdlRef = string(NaN);
            [~, cleanUp] = mlut.sl.Model.open(model); %#ok<ASGLU>

            % Create and load the wrapper
            cWrap = obj.createWrapperModel();

            obj.wrapConfig();
            obj.wrapDataDictionary();
            mdlRef = obj.addModelRef();
            obj.wrapInstanceParameters(mdlRef);

            obj.connectInputs();
            obj.connectOutputs();

            wrapperName = obj.WrapperName;

            if nvp.AutoArrangeSystem
                Simulink.BlockDiagram.arrangeSystem(wrapperName);
            end

        end

        function val = get.WrapperName(obj)
            val = obj.Model + obj.WrapperSuffix;
        end

    end

    methods (Access = protected)

        function cWrap = createWrapperModel(obj)
            % Ensure that a fresh wrapper can be created.
            wrapperName = obj.WrapperName;
            mlut.sl.Model.close(wrapperName);
            if exist(wrapperName, 'file')
                disp("Deleting existing wrapper: " + wrapperName)
                w = which(wrapperName);
                if ~isempty(w)
                    delete(w);
                end
            end
            new_system(wrapperName);

            [~, cWrap] = mlut.sl.Model.open(wrapperName);
        end

        function connectInputs(obj)
            model = obj.Model;
            wrapperName = obj.WrapperName;

            inhs = find_system(model, "SearchDepth", 1, "BlockType", "Inport");
            for i = 1:numel(inhs)
                inh = inhs(i);
                obj.Strategies.runIfApplies("connectInput", inh, wrapperName, i);
            end
        end

        function connectOutputs(obj)
            model = obj.Model;
            wrapperName = obj.WrapperName;

            ouths = find_system(model, "SearchDepth", 1, "BlockType", "Outport");

            for i = 1:numel(ouths)
                outh = ouths(i);
                obj.Strategies.runIfApplies("connectOutput", outh, wrapperName, i);
            end
        end

        function wrapInstanceParameters(obj, mdlRef)

            % Update the model reference to set the model parameters
            p = get_param(mdlRef, "InstanceParameters");
            for i = 1:numel(p)
                p(i).Value = '0';
                p(i).Argument = true;
            end
            set_param(mdlRef, "InstanceParameters", p);

            % Set the parameters in the wrapper
            ip = get_param(mdlRef, "InstanceParameters");

            if ~isempty(ip)

                model = obj.Model;
                wrapperName = obj.WrapperName;
                mws = get_param(model, "ModelWorkspace");
                workspaceVariables = mws.whos;
                wws = get_param(wrapperName, "ModelWorkspace");

                ipNames = string({ip.Name});
                for i = 1:numel(workspaceVariables)
                    name = string(workspaceVariables(i).name);
                    var = mws.getVariable(name);
                    wws.assignin(name, var);

                    idx = (ipNames == name);
                    if any(idx)
                        ip(idx).Value = char(parameterValueString(var));
                    end
                end

                set_param(mdlRef, "InstanceParameters", ip);
            end

        end

        function runStrategy(obj, name, varargin)
            for j = 1:numel(obj.Strategies)
                thisCustomisations = obj.Strategies(j);
                thenContinue = thisCustomisations.runIfApplies(name, varargin{:});
                if ~thenContinue
                    break
                end
            end
        end

        function wrapConfig(obj)
            modelName = obj.Model;
            wrapperName = obj.WrapperName;

            % Copy the config set from the model to the wrapper
            config = getActiveConfigSet(modelName);
            if ~isa(config, 'Simulink.ConfigSet')
                % If the config is a reference, break the link so we can customise
                config = config.getRefConfigSet;
            end
            newConfig = copy(config);
            newConfig.Name = "CopiedConfig";
            attachConfigSet(wrapperName, newConfig);
            setActiveConfigSet(wrapperName, newConfig.Name);

            % Update the coder mappings
            %cm = coder.mapping.api.get(wrapperName,'EmbeddedCoderC');
            coder.mapping.utils.create(wrapperName);
        end

        function mdlRef = addModelRef(obj)
            model = obj.Model;
            wrapperName = obj.WrapperName;

            ref = wrapperName + "/mdl";
            mdlRef = add_block("built-in/ModelReference", ref);
            set_param(mdlRef, "ModelNameDialog", model) % Link to the original model
            set_param(mdlRef, "SimulationMode", "Normal") % Ensure we are not in rapid accelerator mode
        end

        function wrapDataDictionary(obj)
            model = obj.Model;
            wrapperName = obj.WrapperName;
            % TODO: Create a new data dictionary with the top level DD as a
            % reference
            dd = get_param(model, "DataDictionary");
            set_param(wrapperName, "DataDictionary", dd);
        end

    end

    methods (Static)

        function obj = create(nvp)
            arguments
                nvp.BusAs (1,1) string {mustBeMember(nvp.BusAs, ["Bus", "Vector", "Signals"])} = "Bus"
            end

            switch nvp.BusAs
                case "Bus"
                    inStrategy = [mlut.sl.wrapper.strategy.connectInput.DefaultStrategy];
                    outStrategy = [mlut.sl.wrapper.strategy.connectOutput.DefaultStrategy];
                case "Vector"
                    inStrategy = [mlut.sl.wrapper.strategy.connectInput.VectorToBusStrategy, mlut.sl.wrapper.strategy.connectInput.DefaultStrategy];
                    outStrategy = [mlut.sl.wrapper.strategy.connectOutput.BusToVectorStrategy, mlut.sl.wrapper.strategy.connectOutput.DefaultStrategy];
                case "Signals"
                    inStrategy = [mlut.sl.wrapper.strategy.connectInput.SignalToBusStrategy, mlut.sl.wrapper.strategy.connectInput.DefaultStrategy];
                    outStrategy = [mlut.sl.wrapper.strategy.connectOutput.BusToSignalStrategy, mlut.sl.wrapper.strategy.connectOutput.DefaultStrategy];
            end

            strategies = [inStrategy, outStrategy];
            obj = mlut.sl.wrapper.ModelWrapper(Strategies=strategies);
        end

    end

end

function value = parameterValueString(parameter)
    if isa(parameter, "Simulink.Parameter")
        rawValue = parameter.Value;
    else
        rawValue = parameter;
    end

    if isstring(rawValue) && isscalar(rawValue)
        value = rawValue;
    elseif ischar(rawValue)
        value = string(rawValue);
    elseif isnumeric(rawValue) || islogical(rawValue)
        value = string(mat2str(rawValue));
    else
        value = string(rawValue);
    end
end
