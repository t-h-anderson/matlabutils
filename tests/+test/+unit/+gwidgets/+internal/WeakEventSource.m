classdef WeakEventSource < handle
    events
        Changed
    end

    methods
        function fireChanged(this)
            notify(this, "Changed");
        end
    end
end
