classdef KeyPressData < gwidgets.internal.table.CellInteractionData
    % KeyPressData is the callback data for Callback.KeyPress: the current
    % selection, as for the other cell callbacks, plus the pressed key in
    % the form of matlab.ui.eventdata.KeyData.

    properties
        Key (1,1) string = ""
        Character (1,1) string = ""
        Modifier (1,:) string = string.empty(1,0)
    end

    methods

        function this = KeyPressData(indices, displayIndices, key, character, modifier)
            this@gwidgets.internal.table.CellInteractionData(indices, displayIndices);
            this.Key = key;
            this.Character = character;
            this.Modifier = modifier;
        end

    end

end
