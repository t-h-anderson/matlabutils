classdef TooltipContext
    % TooltipContext is the single argument handed to a tooltip's
    % TextFunction and StyleFunction. All fields are populated on every
    % hover regardless of the tooltip's Target; consult Target if you
    % need to know which target fired the function.
    %
    % Shape of Row and Column follows the tooltip's ContextShape:
    %   "Values" -> vector (errors mid-resolve become `missing` here)
    %   "Table"  -> 1xN table (Row) / Mx1 table (Column)
    %
    % Indices into Data are 1-based; NaN when not applicable (header row,
    % off-cell hover).

    properties
        Value          = missing  % Hovered cell value (DisplayData{r,c})
        Row            = missing  % Row slice — shape per ContextShape
        Column         = missing  % Column slice — shape per ContextShape
        Table                     % Full underlying Data table
        DisplayRow    (1,1) double = NaN
        DisplayColumn (1,1) double = NaN
        DataRow       (1,1) double = NaN
        DataColumn    (1,1) double = NaN
        Target        (1,1) string = ""
    end

end
