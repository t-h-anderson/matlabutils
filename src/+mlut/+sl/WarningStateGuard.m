classdef WarningStateGuard < handle
    %WARNINGSTATEGUARD Restore MATLAB warning state on cleanup.

    properties (Access = private)
        SavedState
        IsRestored (1,1) logical = false
    end

    methods
        function obj = WarningStateGuard(nvp)
            arguments
                nvp.State (1,1) string {mustBeMember(nvp.State, ["on", "off", "error"])} = "off"
                nvp.Identifier (1,1) string = "all"
            end

            obj.SavedState = warning(char(nvp.State), char(nvp.Identifier));
        end

        function restore(obj)
            arguments
                obj (1,1) mlut.sl.WarningStateGuard
            end

            if obj.IsRestored
                return
            end

            obj.IsRestored = true;
            warning(obj.SavedState);
        end

        function delete(obj)
            obj.restore();
        end
    end
end
