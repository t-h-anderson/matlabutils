classdef TableEventData < event.EventData
    %TABLEEVENTDATA Event payload for gwidgets.Table and gwidgets.UITable.

    properties
        Action string = ""
        Backend string = ""
        DisplayIndices = []
        DataIndices = []
        SelectionType string = ""
        PreviousData = []
        NewData = []
        EditData = []
        Filter string = ""
        PreviousFilter string = ""
        RowFilterIndices = logical.empty(1,0)
        GroupingVariables string = string.empty(1,0)
        PreviousGroupingVariables string = string.empty(1,0)
        Groups string = string.empty(1,0)
        OpenGroups string = string.empty(1,0)
        ClosedGroups string = string.empty(1,0)
        HiddenGroups string = string.empty(1,0)
        SortBy string = string.empty(1,0)
        SortDirection string = ""
        TooltipBlocks cell = cell(1,0)
        TooltipText string = string.empty(1,0)
        SourceSelection struct = struct()
        TargetSelection struct = struct()
        Operation string = ""
        Placement string = ""
        Payload struct = struct()
        Timestamp = datetime.empty(0,0)
    end

    properties (Dependent)
        DisplayRow
        DisplayColumn
        DataRow
        DataColumn
    end

    methods
        function this = TableEventData(nvp)
            arguments
                nvp.Action = ""
                nvp.Backend = ""
                nvp.DisplayIndices = []
                nvp.DataIndices = []
                nvp.SelectionType = ""
                nvp.PreviousData = []
                nvp.NewData = []
                nvp.EditData = []
                nvp.Filter = ""
                nvp.PreviousFilter = ""
                nvp.RowFilterIndices = logical.empty(1,0)
                nvp.GroupingVariables = string.empty(1,0)
                nvp.PreviousGroupingVariables = string.empty(1,0)
                nvp.Groups = string.empty(1,0)
                nvp.OpenGroups = string.empty(1,0)
                nvp.ClosedGroups = string.empty(1,0)
                nvp.HiddenGroups = string.empty(1,0)
                nvp.SortBy = string.empty(1,0)
                nvp.SortDirection = ""
                nvp.TooltipBlocks = cell(1,0)
                nvp.TooltipText = string.empty(1,0)
                nvp.SourceSelection = struct()
                nvp.TargetSelection = struct()
                nvp.Operation = ""
                nvp.Placement = ""
                nvp.Payload = struct()
                nvp.Timestamp = datetime("now")
            end

            names = fieldnames(nvp);
            for iName = 1:numel(names)
                this.(names{iName}) = nvp.(names{iName});
            end
        end

        function rows = get.DisplayRow(this)
            rows = gwidgets.table.TableEventData.indexColumn(this.DisplayIndices, 1);
        end

        function columns = get.DisplayColumn(this)
            columns = gwidgets.table.TableEventData.indexColumn(this.DisplayIndices, 2);
        end

        function rows = get.DataRow(this)
            rows = gwidgets.table.TableEventData.indexColumn(this.DataIndices, 1);
        end

        function columns = get.DataColumn(this)
            columns = gwidgets.table.TableEventData.indexColumn(this.DataIndices, 2);
        end
    end

    methods (Static)
        function text = tooltipTextFromBlocks(blocks)
            blocks = reshape(blocks, 1, []);
            text = strings(1,0);
            for iBlock = 1:numel(blocks)
                block = blocks{iBlock};
                if ~isstruct(block) || ~isfield(block, "lines")
                    continue
                end

                lines = reshape(block.lines, 1, []);
                for iLine = 1:numel(lines)
                    line = lines{iLine};
                    if isstruct(line) && isfield(line, "text")
                        text(end+1) = string(line.text); %#ok<AGROW>
                    end
                end
            end
        end
    end

    methods (Static, Access = private)
        function values = indexColumn(indices, column)
            if isempty(indices) || ~isnumeric(indices)
                values = double.empty(1,0);
                return
            end

            if isvector(indices) && column == 1
                values = reshape(indices, 1, []);
                return
            end

            if size(indices, 2) < column
                values = double.empty(1,0);
            else
                values = reshape(indices(:, column), 1, []);
            end
        end
    end
end
