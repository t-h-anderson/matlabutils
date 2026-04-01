classdef UpdateManager < handle
   
    properties (SetAccess=protected)
        SuppressAll (1,1) logical = false
        FullySuppress (1,:) string
        Suppress (1,:) string
    end

    methods
        function obj = UpdateManager()
        end

        function setSuppressAll(this,state)
            this.SuppressAll = state;
        end

        function addSuppression(this, name, nvp)
            arguments
                this (1,1)
                name (1,:) string
                nvp.Times (1,1) double = NaN
            end
            if ismissing(nvp.Times)
                this.FullySuppress = unique([this.FullySuppress, name]);
            else
                name = repmat(name, 1, nvp.Times);
                this.Suppress = [this.Suppress, name];
            end
        end

        function removeSuppression(this, names, nvp)
            arguments
                this (1,1)
                names (1,:) string
                nvp.Times (1,1) double = NaN
            end

            if ismissing(nvp.Times)
                this.FullySuppress(ismember(this.FullySuppress, names)) = [];
                this.Suppress(ismember(this.Suppress, names)) = [];
            else
                for i = 1:numel(names)
                    name = names(i);
                    idx = ismember(this.Suppress, name);
                    idx = find(idx, nvp.Times);
                    this.Suppress(idx) = [];
                end
            end
        end

        function tf = doRun(this, name, nvp)
            arguments
                this
                name (1,1)
                nvp.Remove (1,1) double = 1
            end

            removeCount = nvp.Remove;

            if this.SuppressAll
                if removeCount ~= 0
                    this.removeSuppression(name, Times=removeCount);
                end
                tf = false;
                return
            end

            tf = ~(ismember(name, this.Suppress) || ismember(name, this.FullySuppress));

            if removeCount ~= 0
                this.removeSuppression(name, Times=removeCount);
            end
        end
    end
end