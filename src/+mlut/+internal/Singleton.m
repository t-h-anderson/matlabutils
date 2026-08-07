classdef (Abstract) Singleton < handle
    %SINGLETON Marker base for singleton-managed utility state.

    methods (Static, Hidden)
        function obj = instanceFor(className, reset, factory, constructOnReset)
            arguments
                className (1,1) string
                reset (1,1) logical
                factory (1,1) function_handle
                constructOnReset (1,1) logical = true
            end

            persistent instances

            if isempty(instances)
                instances = dictionary(string.empty(1,0), cell.empty(1,0));
            end

            if reset
                if isKey(instances, className)
                    instances = remove(instances, className);
                end
                if ~constructOnReset
                    obj = [];
                    return
                end
            end

            if isKey(instances, className)
                cached = instances(className);
                obj = cached{1};
                if ~isempty(obj) && isvalid(obj)
                    return
                end
            end

            obj = factory();
            instances(className) = {obj};
        end
    end

    methods (Abstract, Static)
        obj = make(varargin)
    end
end
