classdef CellInteractionData < event.EventData
   
    properties
        Indices (:,2)
        DisplayIndices (:,2)
    end

    methods

        function this = CellInteractionData(indices, displayIndices)
            this.Indices = indices;
            this.DisplayIndices = displayIndices;
        end

    end

end