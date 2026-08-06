classdef EventLog < handle
    % EventLog captures events during table unit tests.

    properties
        Events (1,:) cell = cell(1,0)
    end

    properties (Dependent)
        Count
    end

    methods
        function record(this, ~, eventData)
            this.Events{end+1} = eventData;
        end

        function eventData = latest(this)
            eventData = this.Events{end};
        end

        function count = get.Count(this)
            count = numel(this.Events);
        end
    end
end
