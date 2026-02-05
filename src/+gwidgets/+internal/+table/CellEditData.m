classdef CellEditData < event.EventData
   
    properties
        Indices
        DisplayIndices
        PreviousData
        EditData
        NewData
    end

    methods

        function this = CellEditData(e, indices)
            arguments
                e matlab.ui.eventdata.CellEditData
                indices
            end

            this.Indices = indices;
            this.DisplayIndices = e.DisplayIndices;
            this.PreviousData = e.PreviousData;
            this.EditData = e.EditData;
            this.NewData = e.NewData;
        end

    end

end