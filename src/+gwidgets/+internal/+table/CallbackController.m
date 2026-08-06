classdef CallbackController < gwidgets.internal.table.TableController
    % CallbackController stores user callbacks for table interactions.

    properties
        CellSelection (1,:) function_handle {mustBeScalarOrEmpty} = function_handle.empty(1,0)
        CellClicked (1,:) function_handle {mustBeScalarOrEmpty} = function_handle.empty(1,0)
        CellDoubleClick (1,:) function_handle {mustBeScalarOrEmpty} = function_handle.empty(1,0)
        CellEdit (1,:) function_handle {mustBeScalarOrEmpty} = function_handle.empty(1,0)
        DisplayDataChanged (1,:) function_handle {mustBeScalarOrEmpty} = function_handle.empty(1,0)
    end

    properties (Dependent)
        CellSelectionCallback (1,:) function_handle
        CellClickedCallback (1,:) function_handle
        CellDoubleClickCallback (1,:) function_handle
        CellEditCallback (1,:) function_handle
        DisplayDataChangedCallback (1,:) function_handle
    end

    methods
        function this = CallbackController(owner)
            arguments
                owner (1,:) gwidgets.UITable = gwidgets.UITable.empty(1,0)
            end

            this@gwidgets.internal.table.TableController(owner);
        end

        function onCellClicked(this, source, eventData)
            arguments
                this (1,1) gwidgets.internal.table.CallbackController
                source
                eventData
            end

            gwidgets.internal.table.CallbackController.ignoreCallbackSource(source);
            owner = this.owner();
            displayIdx = this.interactionDisplayIndex(eventData);
            if ~isempty(displayIdx)
                rowIdxs = this.groupHeaderRowsFromDisplay(displayIdx);
                owner.Group.toggleOpenStateForRows(rowIdxs, owner.Data.VisibleGroupHeaderRowIdx);
            end

            dataIdx = owner.eventDisplayToData(displayIdx, "cell");
            owner.emitTableEvent("CellClicked", gwidgets.table.TableEventData( ...
                Action="click", ...
                DisplayIndices=displayIdx, ...
                DataIndices=dataIdx, ...
                SelectionType=string(owner.Selection.Type)));

            if isempty(this.CellClicked)
                return
            end

            callbackData = gwidgets.internal.table.CellInteractionData(dataIdx, displayIdx);
            this.CellClicked(owner, callbackData);
        end

        function onCellDoubleClicked(this, source, eventData)
            arguments
                this (1,1) gwidgets.internal.table.CallbackController
                source
                eventData
            end

            gwidgets.internal.table.CallbackController.ignoreCallbackSource(source);
            owner = this.owner();
            displayIdx = this.interactionDisplayIndex(eventData);
            dataIdx = owner.eventDisplayToData(displayIdx, "cell");
            owner.emitTableEvent("CellDoubleClicked", gwidgets.table.TableEventData( ...
                Action="doubleClick", ...
                DisplayIndices=displayIdx, ...
                DataIndices=dataIdx, ...
                SelectionType=string(owner.Selection.Type)));

            if isempty(this.CellDoubleClick)
                return
            end

            callbackData = gwidgets.internal.table.CellInteractionData(dataIdx, displayIdx);
            this.CellDoubleClick(owner, callbackData);
        end

        function onSelection(this, source, eventData)
            arguments
                this (1,1) gwidgets.internal.table.CallbackController
                source
                eventData
            end

            owner = this.owner();
            displayIdx = eventData.Indices;
            [displayIdx, shouldContinue] = owner.Selection.handleDisplaySelection(displayIdx, source.SelectionType);
            if ~shouldContinue
                return
            end

            selectionType = string(source.SelectionType);
            dataIdx = owner.eventDisplayToData(displayIdx, selectionType);
            owner.emitTableEvent("SelectionChanged", gwidgets.table.TableEventData( ...
                Action="select", ...
                DisplayIndices=displayIdx, ...
                DataIndices=dataIdx, ...
                SelectionType=selectionType));

            if isempty(this.CellSelection)
                return
            end

            callbackData = gwidgets.internal.table.CellInteractionData(dataIdx, displayIdx);
            this.CellSelection(owner, callbackData);
        end

        function onCellEdit(this, source, eventData)
            arguments
                this (1,1) gwidgets.internal.table.CallbackController
                source
                eventData
            end

            gwidgets.internal.table.CallbackController.ignoreCallbackSource(source);
            owner = this.owner();
            displayIdx = eventData.Indices;
            owner.Data.editDisplayCell(displayIdx, eventData.NewData, owner.Selection);

            dataIdx = owner.eventDisplayToData(displayIdx, "cell");
            owner.emitTableEvent("CellEdited", gwidgets.table.TableEventData( ...
                Action="edit", ...
                DisplayIndices=displayIdx, ...
                DataIndices=dataIdx, ...
                PreviousData=eventData.PreviousData, ...
                NewData=eventData.NewData, ...
                EditData=eventData.EditData));

            if isempty(this.CellEdit)
                return
            end

            callbackData = gwidgets.internal.table.CellEditData(eventData, dataIdx);
            this.CellEdit(owner, callbackData);
        end

        function onDisplayDataChanged(this, source, eventData)
            arguments
                this (1,1) gwidgets.internal.table.CallbackController
                source
                eventData
            end

            if eventData.Interaction == "sort"
                this.applyDisplaySort(eventData);
            end

            owner = this.owner();
            owner.emitTableEvent("DisplayDataChanged", gwidgets.table.TableEventData( ...
                Action=string(eventData.Interaction), ...
                Payload=struct("InteractionVariable", string(eventData.InteractionVariable))));

            if ~isempty(this.DisplayDataChanged)
                this.DisplayDataChanged(source, eventData);
            end
        end

        function val = get.CellSelectionCallback(this)
            val = this.CellSelection;
        end

        function set.CellSelectionCallback(this, val)
            this.CellSelection = val;
        end

        function val = get.CellClickedCallback(this)
            val = this.CellClicked;
        end

        function set.CellClickedCallback(this, val)
            this.CellClicked = val;
        end

        function val = get.CellDoubleClickCallback(this)
            val = this.CellDoubleClick;
        end

        function set.CellDoubleClickCallback(this, val)
            this.CellDoubleClick = val;
        end

        function val = get.CellEditCallback(this)
            val = this.CellEdit;
        end

        function set.CellEditCallback(this, val)
            this.CellEdit = val;
        end

        function val = get.DisplayDataChangedCallback(this)
            val = this.DisplayDataChanged;
        end

        function set.DisplayDataChangedCallback(this, val)
            this.DisplayDataChanged = val;
        end
    end

    methods (Access = private)
        function applyDisplaySort(this, eventData)
            arguments
                this (1,1) gwidgets.internal.table.CallbackController
                eventData
            end

            owner = this.owner();
            newSortColumn = eventData.InteractionVariable;
            currentSortColumn = owner.Sort.By;

            owner.addControllerUpdateSuppression("SortDirection", Times=1);
            if newSortColumn == currentSortColumn
                if owner.Sort.Direction == "None"
                    owner.Sort.Direction = "Ascend";
                elseif owner.Sort.Direction == "Ascend"
                    owner.Sort.Direction = "Descend";
                else
                    owner.Sort.Direction = "None";
                end
            else
                owner.Sort.Direction = "Ascend";
            end

            owner.Sort.By = eventData.InteractionVariable;
        end

        function rowIdxs = groupHeaderRowsFromDisplay(this, displayIdx)
            arguments
                this (1,1) gwidgets.internal.table.CallbackController
                displayIdx (:,2) double
            end

            owner = this.owner();
            if owner.Display.Orientation == "Transposed"
                rowIdxs = unique(displayIdx(:, 2)) - 1;
                rowIdxs(rowIdxs < 1) = [];
                return
            end

            rowIdxs = unique(displayIdx(:, 1));
        end
    end

    methods (Static, Access = private)
        function displayIdx = interactionDisplayIndex(eventData)
            rowIdx = eventData.InteractionInformation.DisplayRow';
            colIdx = eventData.InteractionInformation.DisplayColumn';

            if isempty(rowIdx)
                displayIdx = zeros(0,2);
                return
            end

            displayIdx = [rowIdx, colIdx];
        end

        function ignoreCallbackSource(~)
            % UI callback source is intentionally not forwarded for these legacy callbacks.
        end
    end
end
