classdef ModelSession < handle
    %MODELSESSION Own a loaded Simulink model for a scoped operation.

    properties (SetAccess = private)
        ModelName (1,1) string = ""
        ModelHandle = []
        WasLoaded (1,1) logical = false
    end

    properties (Access = private)
        IsClosed (1,1) logical = false
    end

    methods
        function obj = ModelSession(modelOrPath)
            arguments
                modelOrPath (1,1) string
            end

            obj.ModelName = mlut.sl.ModelSession.nameFromInput(modelOrPath);
            obj.WasLoaded = bdIsLoaded(char(obj.ModelName));

            if obj.WasLoaded
                obj.ModelHandle = get_param(char(obj.ModelName), "Handle");
                return
            end

            try
                obj.ModelHandle = load_system(char(modelOrPath));
            catch exception
                if bdIsLoaded(char(obj.ModelName))
                    close_system(char(obj.ModelName), 0);
                end

                rethrow(exception);
            end
        end

        function close(obj, nvp)
            arguments
                obj (1,1) mlut.sl.ModelSession
                nvp.Save (1,1) logical = false
            end

            if obj.IsClosed
                return
            end

            obj.IsClosed = true;

            if ~obj.WasLoaded && obj.ModelName ~= "" && bdIsLoaded(char(obj.ModelName))
                close_system(char(obj.ModelName), nvp.Save);
            end
        end

        function delete(obj)
            obj.close();
        end
    end

    methods (Static)
        function modelName = nameFromInput(modelOrPath)
            arguments
                modelOrPath (1,1) string
            end

            modelOrPath = strip(modelOrPath);
            [~, name, ext] = fileparts(modelOrPath);

            if ext ~= "" || isfile(modelOrPath)
                modelName = string(name);
                return
            end

            rootName = extractBefore(modelOrPath + "/", "/");
            [~, modelName] = fileparts(rootName);
            modelName = string(modelName);
        end
    end
end
