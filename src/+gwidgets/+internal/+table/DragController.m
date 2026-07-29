classdef DragController < gwidgets.internal.table.TableController
    % DragController owns table row and group drag/drop behavior.

    properties (Dependent)
        Enabled (1,1) logical
        MoveDragKey (1,1) string
        CopyDragKey (1,1) string
        DropSelection (1,1) struct
    end

    properties (Access = private)
        Enabled_ (1,1) logical = false
        MoveDragKey_ (1,1) string = "alt"
        CopyDragKey_ (1,1) string = "control"
        DropSelection_ (1,1) struct = struct( ...
            Type="none", ...
            Table=[], ...
            DisplayRows=double.empty(1,0), ...
            DataRows=double.empty(1,0), ...
            Group="", ...
            Placement="before", ...
            Data=table.empty(0,0))
    end

    methods
        function this = DragController(owner)
            arguments
                owner (1,1) gwidgets.UITable
            end

            this@gwidgets.internal.table.TableController(owner);
        end

        function initialize(this)
            arguments
                this (1,1) gwidgets.internal.table.DragController
            end

            this.syncBridge();
        end

        function val = get.Enabled(this)
            val = this.Enabled_;
        end

        function set.Enabled(this, val)
            arguments
                this (1,1) gwidgets.internal.table.DragController
                val (1,1) logical
            end

            this.Enabled_ = val;
            this.syncBridge();
        end

        function val = get.MoveDragKey(this)
            val = this.MoveDragKey_;
        end

        function set.MoveDragKey(this, val)
            arguments
                this (1,1) gwidgets.internal.table.DragController
                val (1,1) string {mustBeMember(val, ["control", "alt", "shift", ""])}
            end

            this.MoveDragKey_ = val;
            this.syncBridge();
        end

        function val = get.CopyDragKey(this)
            val = this.CopyDragKey_;
        end

        function set.CopyDragKey(this, val)
            arguments
                this (1,1) gwidgets.internal.table.DragController
                val (1,1) string {mustBeMember(val, ["control", "alt", "shift", ""])}
            end

            this.CopyDragKey_ = val;
            this.syncBridge();
        end

        function val = get.DropSelection(this)
            val = this.DropSelection_;
        end

        function selection = selectionAtDisplayRow(this, displayRow, nvp)
            arguments
                this (1,1) gwidgets.internal.table.DragController
                displayRow (1,1) double
                nvp.Placement (1,1) string {mustBeMember(nvp.Placement, ["before", "after"])} = "before"
            end

            owner = this.owner();
            if isempty(owner) || this.isSorted() || displayRow < 1 || displayRow > height(owner.Data.Visible)
                selection = this.emptySelection(nvp.Placement);
                this.DropSelection_ = selection;
                return
            end

            if ismember(displayRow, owner.Data.VisibleGroupHeaderRowIdx)
                selection = this.groupSelection(displayRow, nvp.Placement);
            else
                selection = this.rowSelection(displayRow, nvp.Placement);
            end

            this.DropSelection_ = selection;
        end

        function applyDrop(this, sourceSelection, targetSelection, nvp)
            arguments
                this (1,1) gwidgets.internal.table.DragController
                sourceSelection (1,1) struct
                targetSelection (1,1) struct
                nvp.Operation (1,1) string {mustBeMember(nvp.Operation, ["move", "copy"])} = "move"
            end

            targetOwner = this.owner();
            sourceOwner = gwidgets.internal.table.DragController.selectionOwner(sourceSelection);
            this.validateDrop(sourceSelection, sourceOwner, targetOwner);

            isSameTable = isequal(sourceOwner, targetOwner);
            if isSameTable && nvp.Operation == "move" && sourceSelection.Type == "group"
                targetGroup = this.targetGroup(targetSelection);
                targetOwner.Group.reorder(sourceSelection.Group, targetGroup, targetSelection.Placement);
                return
            end

            if isSameTable && nvp.Operation == "move"
                targetOwner.Data.Table = this.moveRows( ...
                    targetOwner.Data.Table, sourceSelection.DataRows, targetSelection.DataRows, ...
                    targetSelection.Placement);
                return
            end

            this.insertProjectedRows(sourceSelection, targetSelection);
            if nvp.Operation == "move" && ~isSameTable
                sourceOwner.Data.Table(sourceSelection.DataRows, :) = [];
            end
        end

        function onBridgeDragStart(this, data)
            arguments
                this (1,1) gwidgets.internal.table.DragController
                data (1,1) struct
            end

            if ~this.Enabled_
                return
            end
            this.selectionAtDisplayRow(double(data.sourceRow));
        end

        function onBridgeDrop(this, data)
            arguments
                this (1,1) gwidgets.internal.table.DragController
                data (1,1) struct
            end

            if ~this.Enabled_
                return
            end

            operation = this.operationFromKey(string(data.key));
            if operation == ""
                return
            end

            sourceSelection = this.selectionAtDisplayRow(double(data.sourceRow));
            targetSelection = this.selectionAtDisplayRow( ...
                double(data.targetRow), Placement=string(data.placement));
            if sourceSelection.Type == "none" || targetSelection.Type == "none"
                return
            end

            try
                this.applyDrop(sourceSelection, targetSelection, Operation=operation);
            catch ME
                warning("GraphicsWidgets:Table:DragDropFailed", ...
                    "Table drag/drop failed: %s", ME.message);
            end
        end
    end

    methods (Access = private)
        function selection = rowSelection(this, displayRow, placement)
            owner = this.owner();
            displayRows = displayRow;
            if owner.Selection.Type == "row" && ismember(displayRow, owner.Selection.DisplayValue)
                displayRows = owner.Selection.DisplayValue;
            end

            displayRows = reshape(unique(displayRows, "stable"), 1, []);
            displayRows = displayRows(~ismember(displayRows, owner.Data.VisibleGroupHeaderRowIdx));
            dataRows = owner.Data.FoldedVisibleToDataMap(displayRows);
            dataRows = dataRows(~isnan(dataRows));
            if isempty(dataRows)
                selection = this.emptySelection(placement);
                return
            end

            selection = this.selectionStruct("row", displayRows, dataRows, "", placement);
        end

        function selection = groupSelection(this, displayRow, placement)
            owner = this.owner();
            groupDisplayIdx = find(owner.Data.VisibleGroupHeaderRowIdx == displayRow, 1);
            if isempty(groupDisplayIdx) || groupDisplayIdx > numel(owner.Group.DisplayGroups)
                selection = this.emptySelection(placement);
                return
            end

            group = owner.Group.DisplayGroups(groupDisplayIdx);
            groupIdx = find(owner.Group.Groups == group, 1);
            if owner.Group.Mode == "Nested" && groupIdx <= numel(owner.Data.GroupHeaderDataRows)
                dataRows = owner.Data.GroupHeaderDataRows{groupIdx};
            else
                dataRows = find(owner.Data.GroupIdxs == groupIdx);
            end
            selection = this.selectionStruct("group", displayRow, dataRows, group, placement);
        end

        function selection = selectionStruct(this, type, displayRows, dataRows, group, placement)
            owner = this.owner();
            selection = struct( ...
                Type=type, ...
                Table=owner, ...
                DisplayRows=reshape(displayRows, 1, []), ...
                DataRows=reshape(dataRows, 1, []), ...
                Group=group, ...
                Placement=placement, ...
                Data=owner.Data.Table(dataRows, :));
        end

        function selection = emptySelection(this, placement)
            selection = this.DropSelection_;
            selection.Type = "none";
            selection.Table = this.owner();
            selection.DisplayRows = double.empty(1,0);
            selection.DataRows = double.empty(1,0);
            selection.Group = "";
            selection.Placement = placement;
            selection.Data = table.empty(0,0);
        end

        function validateDrop(this, sourceSelection, sourceOwner, targetOwner)
            if isempty(sourceOwner) || isempty(targetOwner) || sourceSelection.Type == "none"
                error("GraphicsWidgets:Table:InvalidDropSelection", ...
                    "Source drop selection must identify table rows or groups.");
            end

            if this.ownerIsSorted(sourceOwner) || this.ownerIsSorted(targetOwner)
                error("GraphicsWidgets:Table:DragSortedView", ...
                    "Dragging is disabled while table sorting is active.");
            end
        end

        function tf = isSorted(this)
            owner = this.owner();
            tf = this.ownerIsSorted(owner);
        end

        function tf = ownerIsSorted(this, owner)
            arguments
                this (1,1) gwidgets.internal.table.DragController %#ok<INUSA>
                owner (1,:) gwidgets.UITable
            end

            tf = ~isempty(owner) && owner.Sort.Direction ~= "None";
        end

        function group = targetGroup(this, selection)
            owner = this.owner();
            group = selection.Group;
            if group ~= "" || isempty(selection.DataRows)
                return
            end

            groupIdx = owner.Data.GroupIdxs(selection.DataRows(1));
            group = owner.Group.Groups(groupIdx);
        end

        function insertProjectedRows(this, sourceSelection, targetSelection)
            owner = this.owner();
            data = owner.Data.Table;
            rows = this.projectRows(sourceSelection.Data, data);
            insertIdx = this.insertionIndex(data, targetSelection);
            owner.Data.Table = [data(1:insertIdx-1, :); rows; data(insertIdx:end, :)];
        end

        function operation = operationFromKey(this, key)
            operation = "";
            if key == this.MoveDragKey_
                operation = "move";
            elseif key == this.CopyDragKey_
                operation = "copy";
            end
        end

        function syncBridge(this)
            owner = this.owner();
            if isempty(owner)
                return
            end

            if this.Enabled_
                owner.Bridge.enableDragging(this.MoveDragKey_, this.CopyDragKey_);
            else
                owner.Bridge.disableDragging();
            end
            owner.Graphics.Backend.refresh();
        end
    end

    methods (Static, Access = private)
        function owner = selectionOwner(selection)
            owner = gwidgets.UITable.empty(1,0);
            if isfield(selection, "Table") && isa(selection.Table, "gwidgets.UITable") && isvalid(selection.Table)
                owner = selection.Table;
            end
        end

        function data = moveRows(data, movingRows, targetRows, placement)
            movingRows = reshape(unique(movingRows, "stable"), 1, []);
            targetRows = reshape(unique(targetRows, "stable"), 1, []);
            if isempty(movingRows) || isempty(targetRows) || any(ismember(targetRows, movingRows))
                return
            end

            movingData = data(movingRows, :);
            keepRows = true(1, height(data));
            keepRows(movingRows) = false;
            reducedData = data(keepRows, :);

            if placement == "before"
                anchor = min(targetRows);
            else
                anchor = max(targetRows) + 1;
            end
            insertIdx = anchor - sum(movingRows < anchor);
            insertIdx = max(1, min(insertIdx, height(reducedData) + 1));

            data = [reducedData(1:insertIdx-1, :); movingData; reducedData(insertIdx:end, :)];
        end

        function insertIdx = insertionIndex(data, selection)
            if isempty(selection.DataRows)
                insertIdx = height(data) + 1;
                return
            end

            if selection.Placement == "before"
                insertIdx = min(selection.DataRows);
            else
                insertIdx = max(selection.DataRows) + 1;
            end
            insertIdx = max(1, min(insertIdx, height(data) + 1));
        end

        function projected = projectRows(sourceRows, targetData)
            nRows = height(sourceRows);
            targetNames = string(targetData.Properties.VariableNames);
            sourceNames = string(sourceRows.Properties.VariableNames);
            variables = cell(1, numel(targetNames));

            for iVar = 1:numel(targetNames)
                varName = targetNames(iVar);
                variables{iVar} = gwidgets.internal.table.DragController.defaultColumn( ...
                    targetData.(varName), nRows);

                if ~ismember(varName, sourceNames)
                    continue
                end

                candidate = sourceRows.(varName);
                if size(candidate, 1) ~= nRows
                    continue
                end

                try
                    testProjection = table(variables{iVar}, VariableNames=varName);
                    testProjection.(varName) = candidate;
                    variables{iVar} = testProjection.(varName);
                catch
                    % Incompatible matching variables keep the target default.
                end
            end

            projected = table(variables{:}, VariableNames=targetNames);
        end

        function value = defaultColumn(example, nRows)
            outSize = [nRows, size(example, 2:max(2, ndims(example)))];

            if isnumeric(example)
                if isfloat(example)
                    value = NaN(outSize, "like", example);
                else
                    value = zeros(outSize, "like", example);
                end
            elseif islogical(example)
                value = false(outSize);
            elseif isstring(example)
                value = strings(outSize);
            elseif iscategorical(example)
                value = categorical(strings(outSize), categories(example), Ordinal=isordinal(example));
            elseif isdatetime(example)
                value = NaT(outSize);
            elseif isduration(example)
                value = seconds(NaN(outSize));
            elseif iscell(example)
                value = cell(outSize);
            elseif isempty(example)
                error("GraphicsWidgets:Table:UnsupportedDefaultValue", ...
                    "Cannot create default values for an empty %s variable.", class(example));
            else
                value = repmat(example(1, :), nRows, 1);
            end
        end
    end
end
