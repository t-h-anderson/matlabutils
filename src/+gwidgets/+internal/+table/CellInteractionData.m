classdef CellInteractionData < event.EventData
   
    properties
        % Row/column selections are vectors; cell selections are N-by-2.
        Indices (:,:)
        DisplayIndices (:,:)
    end

    methods

        function this = CellInteractionData(indices, displayIndices)
            this.Indices = indices;
            this.DisplayIndices = displayIndices;
        end

    end

end
