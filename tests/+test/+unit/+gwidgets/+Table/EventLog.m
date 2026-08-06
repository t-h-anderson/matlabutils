classdef EventLog < handle
    % EventLog captures events during table unit tests.

    properties
        Events (1,:) cell = cell(1,0)
        CancelEvents (1,1) logical = false
        HandleEvents (1,1) logical = false
        ReplacementValue = []
        HasReplacementValue (1,1) logical = false
        ReplacementData = []
        HasReplacementData (1,1) logical = false
        TooltipBlocks cell = cell(1,0)
    end

    properties (Dependent)
        Count
    end

    methods
        function record(this, ~, eventData)
            this.Events{end+1} = eventData;
            if this.CancelEvents
                eventData.Cancel = true;
            end
            if this.HandleEvents
                eventData.Handled = true;
            end
            if this.HasReplacementValue
                eventData.HasReplacementValue = true;
                eventData.ReplacementValue = this.ReplacementValue;
            end
            if this.HasReplacementData
                eventData.HasReplacementData = true;
                eventData.ReplacementData = this.ReplacementData;
            end
            if ~isempty(this.TooltipBlocks)
                eventData.Handled = true;
                eventData.TooltipBlocks = {this.TooltipBlocks};
                eventData.TooltipText = gwidgets.table.TableEventData.tooltipTextFromBlocks(this.TooltipBlocks);
            end
        end

        function eventData = latest(this)
            eventData = this.Events{end};
        end

        function count = get.Count(this)
            count = numel(this.Events);
        end
    end
end
