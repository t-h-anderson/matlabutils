classdef WeakListenerReceiver < gwidgets.internal.WithWeakListeners
    properties
        Count (1,1) double = 0
    end

    methods (Access = {?gwidgets.internal.WithWeakListeners})
        function onChanged(this, ~, ~)
            this.Count = this.Count + 1;
        end
    end
end
