classdef JSTableBackend < gwidgets.internal.table.backend.TableBackend
    % JSTableBackend is the uihtml-backed renderer prototype.

    properties (Access = private)
        OwnerRef (1,:) matlab.lang.WeakReference {mustBeScalarOrEmpty}
        Data_ (:,:) table = table.empty(0,0)
        ColumnName_ = {}
        ColumnEditable_ (1,:) logical = false(1,0)
        ColumnSortable_ (1,:) logical = false(1,0)
        SelectionType_ (1,1) string = "cell"
        Multiselect_ (1,1) matlab.lang.OnOffSwitchState = "on"
        Selection_ (:,:) double = zeros(0,2)
        ColumnWidth_ (1,:) cell = {}
        GroupHeaderRows_ (1,:) double = zeros(1,0)
        GroupHeaderLevels_ (1,:) double = zeros(1,0)
        StyleConfigurations_ (:,3) table = gwidgets.internal.table.backend.TableBackend.emptyStyleConfigurations()
        Tooltip_ (1,1) string = ""
        ContextMenu_
        ContextMenuItems_ (1,:) cell = cell(1,0)
        ContextMenuCallbacks_ (1,1) struct = struct()
        ContextMenuCustomItems_ (1,:) matlab.ui.container.Menu = matlab.ui.container.Menu.empty(1,0)
        ThemeListener (1,:) event.listener = event.listener.empty(1,0)
        ProbeCounter (1,1) double = 0
        ProbeResult (1,1) struct = struct("id", -1)
        RenderResult (1,1) struct = struct("stateRevision", -1)
        HasSentState (1,1) logical = false
        StateDirty (1,1) logical = true
        StateSendSuppressionDepth (1,1) double = 0
        StateRevision (1,1) double = 0
    end

    methods
        function setup(this, owner, grid)
            arguments
                this (1,1) gwidgets.internal.table.backend.JSTableBackend
                owner (1,1) gwidgets.UITable
                grid (1,1) matlab.ui.container.GridLayout
            end

            if this.isReady()
                return
            end

            this.OwnerRef = matlab.lang.WeakReference(owner);
            internalFolder = fileparts(fileparts(fileparts(mfilename("fullpath"))));
            htmlFile = fullfile(internalFolder, "js_table_backend.html");
            this.Component = uihtml( ...
                Parent=grid, ...
                HTMLSource=htmlFile, ...
                DataChangedFcn=@(src, ~)this.onData(src));
            this.Component.Layout.Row = 3;
            this.Component.Layout.Column = 1;
            this.configureThemeListener(owner);
        end

        function setupBridge(~, ~)
            % The JS backend owns its DOM directly; it does not need the
            % DOM-scraping bridge used by matlab.ui.control.Table.
        end

        function setProperties(this, propertyValues)
            arguments
                this (1,1) gwidgets.internal.table.backend.JSTableBackend
                propertyValues (1,:) cell
            end

            stateUpdateToken = this.beginStateUpdate();
            cleanupObj = onCleanup(@()this.cancelStateUpdate(stateUpdateToken));

            for iProperty = 1:2:numel(propertyValues)
                this.setBackendProperty(string(propertyValues{iProperty}), propertyValues{iProperty+1});
            end

            delete(cleanupObj);
            this.endStateUpdate(stateUpdateToken);
        end

        function token = beginStateUpdate(this)
            arguments
                this (1,1) gwidgets.internal.table.backend.JSTableBackend
            end

            token = this.StateSendSuppressionDepth;
            this.StateSendSuppressionDepth = this.StateSendSuppressionDepth + 1;
        end

        function cancelStateUpdate(this, token)
            arguments
                this (1,1) gwidgets.internal.table.backend.JSTableBackend
                token (1,1) double
            end

            this.StateSendSuppressionDepth = token;
        end

        function endStateUpdate(this, token)
            arguments
                this (1,1) gwidgets.internal.table.backend.JSTableBackend
                token (1,1) double
            end

            this.StateSendSuppressionDepth = token;
            if this.StateSendSuppressionDepth == 0 && this.StateDirty
                this.sendState();
            end
        end

        function contextMenu = buildContextMenu(this, contextMenu, customItems, options, callbacks)
            arguments
                this (1,1) gwidgets.internal.table.backend.JSTableBackend
                contextMenu
                customItems (1,:) matlab.ui.container.Menu
                options (1,1) struct
                callbacks (1,1) struct
            end

            if ~isempty(customItems)
                [customItems.Parent] = deal([]);
                [customItems.Tag] = deal("graphicscomponentsTableContextMenu");
            end

            [customMenuItems, customLeafItems] = ...
                gwidgets.internal.table.backend.JSTableBackend.customMenuItems(customItems);
            this.ContextMenuCustomItems_ = customLeafItems;
            this.ContextMenuCallbacks_ = callbacks;
            this.ContextMenuItems_ = gwidgets.internal.table.backend.JSTableBackend.contextMenuItems( ...
                options, customMenuItems);
            this.requestStateSend();
        end

        function addStyle(this, style, target, index)
            arguments
                this (1,1) gwidgets.internal.table.backend.JSTableBackend
                style (1,1) matlab.ui.style.Style
                target (1,1) string {mustBeMember(target, ["table", "row", "column", "cell"])}
                index = []
            end

            newConfig = table(categorical(target), {index}, style, ...
                VariableNames=["Target", "TargetIndex", "Style"]);
            this.StyleConfigurations_ = [this.StyleConfigurations_; newConfig];
            this.requestStateSend();
        end

        function removeStyle(this)
            arguments
                this (1,1) gwidgets.internal.table.backend.JSTableBackend
            end

            this.StyleConfigurations_ = gwidgets.internal.table.backend.TableBackend.emptyStyleConfigurations();
            this.requestStateSend();
        end

        function refresh(this)
            arguments
                this (1,1) gwidgets.internal.table.backend.JSTableBackend
            end

            this.requestStateSend();
        end

        function requestAutoResizeColumns(this)
            arguments
                this (1,1) gwidgets.internal.table.backend.JSTableBackend
            end

            if ~this.isReady()
                this.StateDirty = true;
                return
            end

            if this.StateDirty || ~this.HasSentState
                this.sendState();
            end

            try
                sendEventToHTMLSource(this.Component, "AutoResizeColumns", struct());
            catch
                % uihtml can be constructed before the browser side is ready.
                this.StateDirty = true;
            end
        end
    end

    methods (Access = ?matlab.unittest.TestCase)
        function handleBrowserEvent(this, data)
            arguments
                this (1,1) gwidgets.internal.table.backend.JSTableBackend
                data (1,1) struct
            end

            if ~isfield(data, "event")
                return
            end

            switch string(data.event)
                case "BackendReady"
                    this.sendState();
                case "CellClicked"
                    this.onCellClicked(data);
                case "CellDoubleClicked"
                    this.onCellDoubleClicked(data);
                case "SelectionChanged"
                    this.onSelectionChanged(data);
                case "CellEdited"
                    this.onCellEdited(data);
                case "CellsPasted"
                    this.onCellsPasted(data);
                case "DisplayDataChanged"
                    this.onDisplayDataChanged(data);
                case "ColumnWidthChanged"
                    this.onColumnWidthChanged(data);
                case "AutoResizeColumnWidths"
                    this.onAutoResizeColumnWidths(data);
                case "CellHover"
                    this.onCellHover(data);
                case "CellLeave"
                    this.sendTooltipBlocks(cell(1,0));
                case "ContextMenuAction"
                    this.onContextMenuAction(data);
                case "TableDragStart"
                    this.onTableDragStart(data);
                case "TableDrop"
                    this.onTableDrop(data);
                case "ProbeResult"
                    this.ProbeResult = data;
                case "RenderComplete"
                    this.RenderResult = data;
                otherwise
                    % Unknown browser events are ignored for forward compatibility.
            end
        end

        function result = waitForBrowserRender(this, nvp)
            arguments
                this (1,1) gwidgets.internal.table.backend.JSTableBackend
                nvp.Timeout (1,1) double {mustBePositive} = 10
            end

            if ~this.isReady()
                error("GraphicsWidgets:Table:RenderUnavailable", ...
                    "The JavaScript table backend is not ready for render synchronization.");
            end

            if this.StateDirty || ~this.HasSentState
                this.sendState();
            end

            targetRevision = this.StateRevision;
            startTime = tic;
            while toc(startTime) < nvp.Timeout
                drawnow();
                result = this.RenderResult;
                if isstruct(result) && isfield(result, "stateRevision") && ...
                        double(result.stateRevision) >= targetRevision
                    return
                end
            end

            error("GraphicsWidgets:Table:RenderTimeout", ...
                "Timed out waiting for JavaScript table render revision %d.", targetRevision);
        end

        function result = probeBrowser(this, probeName, payload, nvp)
            arguments
                this (1,1) gwidgets.internal.table.backend.JSTableBackend
                probeName (1,1) string
                payload (1,1) struct = struct()
                nvp.Timeout (1,1) double {mustBePositive} = 10
            end

            if ~this.isReady()
                error("GraphicsWidgets:Table:ProbeUnavailable", ...
                    "The JavaScript table backend is not ready for browser probes.");
            end

            this.ProbeCounter = this.ProbeCounter + 1;
            probeId = this.ProbeCounter;
            this.ProbeResult = struct("id", -1);
            request = struct( ...
                "id", probeId, ...
                "probe", char(probeName), ...
                "payload", payload);

            renderPayload = [];
            hasRenderPayload = false;
            renderRequired = this.StateDirty || ~this.HasSentState;
            renderSent = false;
            lastRenderTime = -Inf;
            lastProbeTime = -Inf;
            startTime = tic;
            while toc(startTime) < nvp.Timeout
                elapsedTime = toc(startTime);
                shouldSendRender = renderRequired || (~renderSent && elapsedTime >= 0.25) || ...
                    (renderSent && elapsedTime - lastRenderTime >= 1);
                if shouldSendRender
                    if ~hasRenderPayload
                        renderPayload = this.tablePayload();
                        hasRenderPayload = true;
                    end
                    try
                        sendEventToHTMLSource(this.Component, "Render", renderPayload);
                        this.HasSentState = true;
                        this.StateDirty = false;
                        renderSent = true;
                        renderRequired = false;
                        lastRenderTime = elapsedTime;
                    catch
                        % uihtml can exist before its browser document is accepting events.
                        renderSent = false;
                        renderRequired = true;
                        this.StateDirty = true;
                    end
                end
                if this.isRenderCurrent() && elapsedTime - lastProbeTime >= 0.1
                    try
                        sendEventToHTMLSource(this.Component, "Probe", request);
                        lastProbeTime = elapsedTime;
                    catch
                        % uihtml can exist before its browser document is accepting events.
                    end
                end

                drawnow();
                result = this.ProbeResult;
                if isstruct(result) && isfield(result, "id") && double(result.id) == probeId
                    if isfield(result, "error")
                        error("GraphicsWidgets:Table:ProbeError", ...
                            "JavaScript table probe failed: %s", string(result.error));
                    end
                    if this.isStaleProbeResult(result, probeName)
                        renderRequired = true;
                        renderSent = false;
                        this.ProbeResult = struct("id", -1);
                        continue
                    end
                    return
                end
            end

            error("GraphicsWidgets:Table:ProbeTimeout", ...
                "Timed out waiting for JavaScript table probe '%s'.", probeName);
        end
    end

    methods (Access = protected)
        function value = getBackendProperty(this, propertyName)
            arguments
                this (1,1) gwidgets.internal.table.backend.JSTableBackend
                propertyName (1,1) string
            end

            switch propertyName
                case {"Data", "DisplayData"}
                    value = this.Data_;
                case "ColumnName"
                    value = this.ColumnName_;
                case "ColumnEditable"
                    value = this.ColumnEditable_;
                case "ColumnSortable"
                    value = this.ColumnSortable_;
                case "SelectionType"
                    value = char(this.SelectionType_);
                case "Multiselect"
                    value = this.Multiselect_;
                case "Selection"
                    value = this.Selection_;
                case "ColumnWidth"
                    value = this.ColumnWidth_;
                case "GroupHeaderRows"
                    value = this.GroupHeaderRows_;
                case "GroupHeaderLevels"
                    value = this.GroupHeaderLevels_;
                case "StyleConfigurations"
                    value = this.StyleConfigurations_;
                case "Tooltip"
                    value = this.Tooltip_;
                case "ContextMenu"
                    value = this.ContextMenu_;
                otherwise
                    error("GraphicsWidgets:Table:BackendProperty", ...
                        "Unsupported JS backend property: %s", propertyName);
            end
        end

        function setBackendProperty(this, propertyName, value)
            arguments
                this (1,1) gwidgets.internal.table.backend.JSTableBackend
                propertyName (1,1) string
                value
            end

            switch propertyName
                case {"Data", "DisplayData"}
                    this.Data_ = value;
                case "ColumnName"
                    this.ColumnName_ = value;
                case "ColumnEditable"
                    this.ColumnEditable_ = value;
                case "ColumnSortable"
                    this.ColumnSortable_ = value;
                case "SelectionType"
                    this.SelectionType_ = string(value);
                case "Multiselect"
                    this.Multiselect_ = value;
                case "Selection"
                    this.Selection_ = value;
                case "ColumnWidth"
                    this.ColumnWidth_ = gwidgets.internal.table.ColumnWidthController.normalizeColumnWidths(value);
                case "GroupHeaderRows"
                    this.GroupHeaderRows_ = reshape(double(value), 1, []);
                case "GroupHeaderLevels"
                    this.GroupHeaderLevels_ = reshape(double(value), 1, []);
                case "StyleConfigurations"
                    this.StyleConfigurations_ = value;
                case "Tooltip"
                    this.Tooltip_ = string(value);
                case "ContextMenu"
                    this.ContextMenu_ = value;
                otherwise
                    error("GraphicsWidgets:Table:BackendProperty", ...
                        "Unsupported JS backend property: %s", propertyName);
            end
            this.requestStateSend();
        end
    end

    methods (Access = private)
        function owner = owner(this)
            owner = gwidgets.UITable.empty(1,0);
            if isempty(this.OwnerRef)
                return
            end

            owner = this.OwnerRef.Handle;
            if isempty(owner) || ~isvalid(owner)
                owner = gwidgets.UITable.empty(1,0);
            end
        end

        function onData(this, src)
            data = src.Data;
            if ~isstruct(data) || ~isfield(data, "event")
                return
            end

            this.handleBrowserEvent(data);
        end

        function onCellClicked(this, data)
            owner = this.owner();
            if isempty(owner)
                return
            end

            owner.Callback.onCellClicked([], this.interactionEvent(data));
        end

        function onCellDoubleClicked(this, data)
            owner = this.owner();
            if isempty(owner)
                return
            end

            owner.Callback.onCellDoubleClicked([], this.interactionEvent(data));
        end

        function onSelectionChanged(this, data)
            owner = this.owner();
            if isempty(owner) || ~isfield(data, "indices")
                return
            end

            selectionType = this.SelectionType_;
            if isfield(data, "selectionType")
                selectionType = string(data.selectionType);
                if any(selectionType == ["cell", "row", "column"]) && selectionType ~= this.SelectionType_
                    owner.Selection.Type = selectionType;
                end
            end

            source = struct( ...
                "SelectionType", char(selectionType), ...
                "ViewId", char(this.Name), ...
                "ViewKind", char(this.Kind));
            eventData = struct("Indices", double(data.indices));
            owner.Callback.onSelection(source, eventData);
        end

        function onCellEdited(this, data)
            owner = this.owner();
            if isempty(owner)
                return
            end

            row = double(data.row);
            col = double(data.col);
            this.applyCellEdit(owner, row, col, string(data.value));
        end

        function onCellsPasted(this, data)
            owner = this.owner();
            if isempty(owner) || ~isfield(data, "rows") || ~isfield(data, "cols") || ~isfield(data, "values")
                return
            end

            rows = reshape(double(data.rows), 1, []);
            cols = reshape(double(data.cols), 1, []);
            values = reshape(string(data.values), 1, []);
            nValues = min([numel(rows), numel(cols), numel(values)]);
            for iValue = 1:nValues
                this.applyCellEdit(owner, rows(iValue), cols(iValue), values(iValue));
            end
        end

        function applyCellEdit(this, owner, row, col, editData)
            arguments
                this (1,1) gwidgets.internal.table.backend.JSTableBackend
                owner (1,1) gwidgets.UITable
                row (1,1) double
                col (1,1) double
                editData (1,1) string
            end

            previousData = this.previousData(row, col);
            newData = gwidgets.internal.table.backend.JSTableBackend.coerceEditData(editData, previousData);

            eventData = struct( ...
                "Indices", [row, col], ...
                "DisplayIndices", [row, col], ...
                "PreviousData", previousData, ...
                "EditData", editData, ...
                "NewData", newData);
            owner.Callback.onCellEdit([], eventData);
        end

        function onDisplayDataChanged(this, data)
            owner = this.owner();
            if isempty(owner)
                return
            end

            eventData = struct( ...
                "Interaction", string(data.interaction), ...
                "InteractionVariable", string(data.variable));
            owner.Callback.onDisplayDataChanged(this.Component, eventData);
        end

        function onColumnWidthChanged(this, data)
            owner = this.owner();
            if isempty(owner) || ~isfield(data, "widths")
                return
            end

            if isfield(data, "column")
                startWidth = NaN;
                if isfield(data, "startWidth")
                    startWidth = double(data.startWidth);
                end
                owner.Display.handleBridgeColumnResize( ...
                    double(data.column), double(data.widths), startWidth);
                return
            end

            owner.Display.handleBridgeColumnWidths(double(data.widths));
        end

        function onAutoResizeColumnWidths(this, data)
            owner = this.owner();
            if isempty(owner) || ~isfield(data, "widths")
                return
            end

            owner.Display.handleAutoResizeColumnWidths(double(data.widths));
        end

        function onTableDragStart(this, data)
            owner = this.owner();
            if isempty(owner)
                return
            end

            owner.Drag.onBridgeDragStart(data);
        end

        function onTableDrop(this, data)
            owner = this.owner();
            if isempty(owner)
                return
            end

            owner.Drag.onBridgeDrop(data);
        end

        function onCellHover(this, data)
            owner = this.owner();
            if isempty(owner) || ~isfield(data, "row") || ~isfield(data, "col")
                this.sendTooltipBlocks(cell(1,0));
                return
            end

            if isempty(owner.Tooltip.Tooltips) && ~owner.Metric.Enabled
                this.sendTooltipBlocks(cell(1,0));
                return
            end

            blocks = owner.Tooltip.resolveBlocks(double(data.row), double(data.col));
            this.sendTooltipBlocks(blocks);
        end

        function sendTooltipBlocks(this, blocks)
            if ~this.isReady()
                return
            end

            try
                sendEventToHTMLSource(this.Component, "SetTooltip", struct("blocks", {blocks}));
            catch
                % uihtml can be constructed before the browser side is ready.
            end
        end

        function eventData = interactionEvent(~, data)
            eventData = struct("InteractionInformation", struct( ...
                "DisplayRow", double(data.row), ...
                "DisplayColumn", double(data.col)));
        end

        function requestStateSend(this)
            if ~this.StateDirty
                this.StateRevision = this.StateRevision + 1;
            end
            this.StateDirty = true;
            if this.StateSendSuppressionDepth > 0
                return
            end

            this.sendState();
        end

        function sendState(this)
            if ~this.isReady()
                this.StateDirty = true;
                return
            end

            payload = this.tablePayload();
            try
                sendEventToHTMLSource(this.Component, "Render", payload);
                this.HasSentState = true;
                this.StateDirty = false;
            catch
                % uihtml can be constructed before the browser side is ready.
                this.StateDirty = true;
            end
        end

        function payload = tablePayload(this)
            data = this.Data_;
            displayColumnNames = this.displayColumnNames();
            cellValues = gwidgets.internal.table.backend.JSTableBackend.displayCellValues(data);
            cellRows = zeros(1,0);
            cellCols = zeros(1,0);
            values = cell(0,0);
            payload = struct( ...
                "columns", {cellstr(displayColumnNames)}, ...
                "values", {values}, ...
                "stateRevision", this.StateRevision, ...
                "rowCount", height(data), ...
                "cellRows", cellRows, ...
                "cellCols", cellCols, ...
                "cellValues", {cellstr(cellValues)}, ...
                "cellLayout", "rowMajor", ...
                "selectionType", char(this.SelectionType_), ...
                "multiselect", char(string(this.Multiselect_)), ...
                "selection", this.Selection_, ...
                "columnEditable", this.ColumnEditable_, ...
                "columnSortable", this.ColumnSortable_, ...
                "displayOrientation", char(this.displayOrientationPayload()), ...
                "rowSortVariables", {cellstr(this.rowSortVariablesPayload())}, ...
                "rowSortable", this.rowSortablePayload(), ...
                "sortByColumn", {cellstr(this.sortByColumnPayload())}, ...
                "sortDirection", char(this.sortDirectionPayload()), ...
                "columnWidth", {this.columnWidthPayload()}, ...
                "columnWidthType", {cellstr(this.columnWidthTypesPayload())}, ...
                "columnPixelWidth", this.columnPixelWidthPayload(), ...
                "columnMinWidth", this.columnMinWidthPayload(), ...
                "columnMaxWidth", this.columnMaxWidthPayload(), ...
                "tableMinWidth", this.tableMinWidthPayload(), ...
                "tableMaxWidth", this.tableMaxWidthPayload(), ...
                "groupHeaderRows", this.GroupHeaderRows_, ...
                "groupHeaderLevels", this.GroupHeaderLevels_, ...
                "groupHeaderColumns", this.groupHeaderColumnsPayload(), ...
                "groupHeaderColumnLevels", this.groupHeaderColumnLevelsPayload(), ...
                "tooltip", char(this.Tooltip_), ...
                "hasCustomTooltip", this.hasCustomTooltipPayload(), ...
                "showGroupHeaderTooltips", this.showGroupHeaderTooltipsPayload(), ...
                "contextMenu", {this.ContextMenuItems_}, ...
                "dragEnabled", this.dragEnabledPayload(), ...
                "dragMoveKey", char(this.dragMoveKeyPayload()), ...
                "dragCopyKey", char(this.dragCopyKeyPayload()), ...
                "theme", char(this.themePayload()), ...
                "styles", {this.stylePayload()});
        end

        function tf = isStaleProbeResult(this, result, probeName)
            if probeName ~= "Snapshot"
                tf = false;
                return
            end

            if ~isfield(result, "stateRevision")
                tf = this.StateRevision > 0;
                return
            end

            resultRevision = double(result.stateRevision);
            tf = resultRevision < this.StateRevision;
        end

        function tf = isRenderCurrent(this)
            tf = isstruct(this.RenderResult) && isfield(this.RenderResult, "stateRevision") && ...
                double(this.RenderResult.stateRevision) >= this.StateRevision;
        end

        function configureThemeListener(this, owner)
            delete(this.ThemeListener);
            this.ThemeListener = event.listener.empty(1,0);

            fig = ancestor(owner, "figure");
            if isempty(fig)
                return
            end

            try
                this.ThemeListener = addlistener(fig, "ThemeChanged", @(~, ~)this.requestStateSend());
            catch
                try
                    this.ThemeListener = addlistener(fig, "Theme", "PostSet", @(~, ~)this.requestStateSend());
                catch
                    % Older MATLAB releases do not expose figure theme notifications.
                end
            end
        end

        function theme = themePayload(this)
            theme = "light";
            owner = this.owner();
            if isempty(owner)
                return
            end

            fig = ancestor(owner, "figure");
            if isempty(fig) || ~isprop(fig, "Theme")
                return
            end

            try
                theme = string(fig.Theme.BaseColorStyle);
            catch
                theme = this.themeFromFigureColor(fig);
            end

            if theme ~= "dark"
                theme = "light";
            end
        end

        function theme = themeFromFigureColor(~, fig)
            theme = "light";
            try
                color = double(fig.Color);
            catch
                % Some parent figures may not expose a numeric Color fallback.
                return
            end

            if numel(color) == 3 && mean(color) < 0.5
                theme = "dark";
            end
        end

        function enabled = dragEnabledPayload(this)
            enabled = false;
            owner = this.owner();
            if ~isempty(owner)
                enabled = owner.Drag.Enabled;
            end
        end

        function key = dragMoveKeyPayload(this)
            key = "";
            owner = this.owner();
            if ~isempty(owner)
                key = owner.Drag.MoveDragKey;
            end
        end

        function key = dragCopyKeyPayload(this)
            key = "";
            owner = this.owner();
            if ~isempty(owner)
                key = owner.Drag.CopyDragKey;
            end
        end

        function tf = hasCustomTooltipPayload(this)
            tf = false;
            owner = this.owner();
            if ~isempty(owner)
                tf = ~isempty(owner.Tooltip.Tooltips) || owner.Metric.Enabled;
            end
        end

        function tf = showGroupHeaderTooltipsPayload(this)
            tf = true;
            owner = this.owner();
            if ~isempty(owner)
                tf = owner.ShowGroupHeaderTooltips;
            end
        end

        function orientation = displayOrientationPayload(this)
            orientation = "Normal";
            owner = this.owner();
            if ~isempty(owner)
                orientation = owner.Display.Orientation;
            end
        end

        function variables = rowSortVariablesPayload(this)
            variables = strings(1,0);
            owner = this.owner();
            if isempty(owner) || owner.Display.Orientation ~= "Transposed" || width(this.Data_) < 1
                return
            end

            variables = reshape(string(this.Data_{:, 1}), 1, []);
        end

        function sortable = rowSortablePayload(this)
            sortable = false(1,0);
            owner = this.owner();
            variables = this.rowSortVariablesPayload();
            if isempty(owner) || isempty(variables)
                return
            end

            dataNames = owner.Column.aliasesToData(variables);
            allDataNames = owner.Column.DataNames;
            dataSortable = owner.Column.DataSortable;
            sortable = false(1, numel(dataNames));
            for iName = 1:numel(dataNames)
                idx = find(allDataNames == dataNames(iName), 1);
                if ~isempty(idx)
                    sortable(iName) = dataSortable(idx);
                end
            end
        end

        function columns = sortByColumnPayload(this)
            columns = strings(1,0);
            owner = this.owner();
            if ~isempty(owner)
                columns = reshape(owner.Sort.By, 1, []);
            end
        end

        function direction = sortDirectionPayload(this)
            direction = "None";
            owner = this.owner();
            if ~isempty(owner)
                direction = owner.Sort.Direction;
            end
        end

        function columns = groupHeaderColumnsPayload(this)
            columns = zeros(1,0);
            owner = this.owner();
            if isempty(owner) || owner.Display.Orientation ~= "Transposed"
                return
            end

            columns = reshape(owner.Data.VisibleGroupHeaderRowIdx, 1, []) + 1;
        end

        function levels = groupHeaderColumnLevelsPayload(this)
            levels = zeros(1,0);
            owner = this.owner();
            if isempty(owner) || owner.Display.Orientation ~= "Transposed"
                return
            end

            levels = reshape(owner.Data.VisibleGroupHeaderLevels, 1, []);
            if isempty(levels)
                return
            end

            columns = this.groupHeaderColumnsPayload();
            if numel(levels) ~= numel(columns)
                levels = ones(1, numel(columns));
            elseif all(levels == 0)
                levels = ones(1, numel(columns));
            end
        end

        function onContextMenuAction(this, data)
            if ~isfield(data, "action") || isempty(fieldnames(this.ContextMenuCallbacks_))
                return
            end

            callbacks = this.ContextMenuCallbacks_;
            action = string(data.action);
            eventData = this.contextMenuEventData(data);
            value = this.contextMenuValue(data);

            switch action
                case "SetGroups"
                    callbacks.SetGroups(value);
                case "AddGroups"
                    callbacks.AddGroups(value);
                case "RemoveGroups"
                    callbacks.RemoveGroups(value);
                case "ToggleGroupingMode"
                    callbacks.ToggleGroupingMode([], []);
                case "ToggleShowEmptyGroups"
                    callbacks.ToggleShowEmptyGroups([], []);
                case "SortAscend"
                    callbacks.SortAscend([], eventData);
                case "SortDescend"
                    callbacks.SortDescend([], eventData);
                case "SortNone"
                    callbacks.SortNone([], eventData);
                case "CellSelection"
                    callbacks.CellSelection([], []);
                case "RowSelection"
                    callbacks.RowSelection([], []);
                case "ColumnSelection"
                    callbacks.ColumnSelection([], []);
                case "ToggleRowFilter"
                    callbacks.ToggleRowFilter([], []);
                case "AutoResizeColumns"
                    callbacks.AutoResizeColumns([], []);
                case "ToggleDragging"
                    callbacks.ToggleDragging([], []);
                case "ToggleGroupHeaderTooltips"
                    callbacks.ToggleGroupHeaderTooltips([], []);
                case "ToggleTableMetrics"
                    callbacks.ToggleTableMetrics([], []);
                case "ToggleDisplayOrientation"
                    callbacks.ToggleDisplayOrientation([], []);
                case "CustomItem"
                    this.invokeCustomMenuItem(value, eventData);
                otherwise
                    % Unknown menu actions are ignored for forward compatibility.
            end
        end

        function eventData = contextMenuEventData(~, data)
            row = 0;
            col = 0;
            if isfield(data, "row")
                row = double(data.row);
            end
            if isfield(data, "col")
                col = double(data.col);
            end

            eventData = struct("InteractionInformation", struct( ...
                "DisplayRow", row, ...
                "DisplayColumn", col));
        end

        function value = contextMenuValue(~, data)
            value = strings(1,0);
            if ~isfield(data, "value") || isempty(data.value)
                return
            end

            rawValue = data.value;
            value = string(rawValue);
            value = reshape(value, 1, []);
        end

        function invokeCustomMenuItem(this, value, eventData)
            if isempty(value)
                return
            end

            itemIndex = str2double(value(1));
            if isnan(itemIndex) || itemIndex < 1 || itemIndex > numel(this.ContextMenuCustomItems_)
                return
            end

            item = this.ContextMenuCustomItems_(itemIndex);
            if isempty(item.MenuSelectedFcn)
                return
            end
            item.MenuSelectedFcn(item, eventData);
        end

        function names = displayColumnNames(this)
            dataNames = string(this.Data_.Properties.VariableNames);
            names = string(this.ColumnName_);
            names = reshape(names, 1, []);
            if isempty(names) || numel(names) ~= numel(dataNames)
                names = dataNames;
            end
        end

        function widths = columnWidthPayload(this)
            widths = cell(1, numel(this.ColumnWidth_));
            for iWidth = 1:numel(this.ColumnWidth_)
                value = this.ColumnWidth_{iWidth};
                if isnumeric(value) && isscalar(value)
                    widths{iWidth} = string(value) + "px";
                else
                    widths{iWidth} = string(value);
                end
            end
            widths = cellstr(string(widths));
        end

        function types = columnWidthTypesPayload(this)
            nWidths = numel(this.ColumnWidth_);
            types = strings(1, nWidths);
            owner = this.owner();
            if ~isempty(owner) && numel(owner.Column.WidthTypes) == nWidths
                types = owner.Column.WidthTypes;
                return
            end

            for iWidth = 1:nWidths
                types(iWidth) = gwidgets.internal.table.backend.JSTableBackend.widthType(this.ColumnWidth_{iWidth});
            end
        end

        function widths = columnPixelWidthPayload(this)
            nWidths = numel(this.ColumnWidth_);
            widths = nan(1, nWidths);
            owner = this.owner();
            if ~isempty(owner) && numel(owner.Column.PixelWidths) == nWidths
                widths = owner.Column.PixelWidths;
                return
            end

            for iWidth = 1:nWidths
                widths(iWidth) = gwidgets.internal.table.backend.JSTableBackend.pixelWidth(this.ColumnWidth_{iWidth});
            end
        end

        function widths = columnMinWidthPayload(this)
            nWidths = numel(this.ColumnWidth_);
            widths = repelem(24, 1, nWidths);
            owner = this.owner();
            if ~isempty(owner) && numel(owner.Column.MinWidth) == nWidths
                widths = owner.Column.MinWidth;
            end
        end

        function widths = columnMaxWidthPayload(this)
            nWidths = numel(this.ColumnWidth_);
            widths = nan(1, nWidths);
            owner = this.owner();
            if ~isempty(owner) && numel(owner.Column.MaxWidth) == nWidths
                widths = owner.Column.MaxWidth;
                widths(isinf(widths)) = NaN;
            end
        end

        function width = tableMinWidthPayload(this)
            width = NaN;
            owner = this.owner();
            if ~isempty(owner)
                width = owner.Column.TableMinWidth;
            end
        end

        function width = tableMaxWidthPayload(this)
            width = NaN;
            owner = this.owner();
            if ~isempty(owner) && isfinite(owner.Column.TableMaxWidth)
                width = owner.Column.TableMaxWidth;
            end
        end

        function value = previousData(this, row, col)
            arguments
                this (1,1) gwidgets.internal.table.backend.JSTableBackend
                row (1,1) double
                col (1,1) double
            end

            if row < 1 || col < 1 || row > height(this.Data_) || col > width(this.Data_)
                value = [];
                return
            end

            value = this.Data_{row, col};
        end

        function styles = stylePayload(this)
            configs = this.StyleConfigurations_;
            styles = struct("target", {}, "index", {}, "css", {});
            if isempty(configs)
                return
            end

            nextStyle = 0;
            styles(1, height(configs)) = struct("target", "", "index", [], "css", "");
            for iStyle = 1:height(configs)
                css = gwidgets.internal.table.backend.JSTableBackend.styleCss(configs.Style(iStyle));
                if css == ""
                    continue
                end

                nextStyle = nextStyle + 1;
                styles(nextStyle) = struct( ...
                    "target", char(string(configs.Target(iStyle))), ...
                    "index", configs.TargetIndex{iStyle}, ...
                    "css", char(css));
            end

            styles = styles(1:nextStyle);
        end
    end

    methods (Static, Access = private)
        function items = contextMenuItems(options, customItems)
            arguments
                options (1,1) struct
                customItems (1,:) cell
            end

            toggleItems = gwidgets.internal.table.backend.JSTableBackend.toggleMenuItems(options);
            itemCells = cell(1, 3 + numel(toggleItems) + numel(customItems));
            nItems = 0;
            groupingItem = gwidgets.internal.table.backend.JSTableBackend.groupingMenuItem(options);
            if ~isempty(groupingItem)
                nItems = nItems + 1;
                itemCells{nItems} = groupingItem;
            end

            sortItem = gwidgets.internal.table.backend.JSTableBackend.sortMenuItem(options);
            if ~isempty(sortItem)
                nItems = nItems + 1;
                itemCells{nItems} = sortItem;
            end

            selectionItem = gwidgets.internal.table.backend.JSTableBackend.selectionMenuItem(options);
            if ~isempty(selectionItem)
                nItems = nItems + 1;
                itemCells{nItems} = selectionItem;
            end

            nToggleItems = numel(toggleItems);
            itemCells(nItems+1:nItems+nToggleItems) = toggleItems;
            nItems = nItems + nToggleItems;

            nCustomItems = numel(customItems);
            itemCells(nItems+1:nItems+nCustomItems) = customItems;
            nItems = nItems + nCustomItems;

            items = itemCells(1:nItems);
        end

        function [items, leafItems] = customMenuItems(customItems)
            arguments
                customItems (1,:) matlab.ui.container.Menu
            end

            items = cell(1, numel(customItems));
            leafItems = matlab.ui.container.Menu.empty(1,0);
            for iItem = 1:numel(customItems)
                [items{iItem}, leafItems] = gwidgets.internal.table.backend.JSTableBackend.customMenuItem( ...
                    customItems(iItem), leafItems);
            end
        end

        function [item, leafItems] = customMenuItem(menuItem, leafItems)
            arguments
                menuItem (1,1) matlab.ui.container.Menu
                leafItems (1,:) matlab.ui.container.Menu
            end

            childMenus = reshape(menuItem.Children, 1, []);
            children = cell(1, numel(childMenus));
            for iChild = 1:numel(childMenus)
                [children{iChild}, leafItems] = gwidgets.internal.table.backend.JSTableBackend.customMenuItem( ...
                    childMenus(iChild), leafItems);
            end

            action = "";
            value = strings(1,0);
            if isempty(children)
                leafItems(end+1) = menuItem;
                action = "CustomItem";
                value = string(numel(leafItems));
            end

            item = gwidgets.internal.table.backend.JSTableBackend.menuItem( ...
                string(menuItem.Text), action, value, string(menuItem.Enable) ~= "off", children);
        end

        function item = groupingMenuItem(options)
            item = [];
            if ~(options.HasChangeGroupingVariable || options.HasToggleShowEmptyGroups)
                return
            end

            children = cell(1,0);
            if options.HasChangeGroupingVariable
                children{end+1} = gwidgets.internal.table.backend.JSTableBackend.variableMenuItem( ...
                    "Set", "SetGroups", options.DataVariables, options.DataVariableNames, ...
                    options.SelectedGroupingVariables, options.SelectedGroupingVariableNames, "All");
                children{end+1} = gwidgets.internal.table.backend.JSTableBackend.variableMenuItem( ...
                    "Add", "AddGroups", options.DataVariables, options.DataVariableNames, ...
                    options.SelectedGroupingVariables, options.SelectedGroupingVariableNames, "All");

                [removeVariables, removeNames] = gwidgets.internal.table.backend.JSTableBackend.selectedRemoveItems( ...
                    options);
                children{end+1} = gwidgets.internal.table.backend.JSTableBackend.variableMenuItem( ...
                    "Remove", "RemoveGroups", options.GroupingVariables, options.GroupingVariableNames, ...
                    removeVariables, removeNames, "All");

                modeText = "Use nested groups";
                if options.GroupingMode == "Nested"
                    modeText = "Use flat groups";
                end
                children{end+1} = gwidgets.internal.table.backend.JSTableBackend.menuItem( ...
                    modeText, "ToggleGroupingMode", strings(1,0), true, cell(1,0));
            end

            if options.HasToggleShowEmptyGroups
                children{end+1} = gwidgets.internal.table.backend.JSTableBackend.menuItem( ...
                    "Show/hide empty groups", "ToggleShowEmptyGroups", strings(1,0), true, cell(1,0));
            end

            item = gwidgets.internal.table.backend.JSTableBackend.menuItem( ...
                "Grouping", "", strings(1,0), true, children);
        end

        function item = sortMenuItem(options)
            item = [];
            if ~(options.HasColumnSorting && any(options.ColumnSortable))
                return
            end

            children = { ...
                gwidgets.internal.table.backend.JSTableBackend.menuItem( ...
                    "Ascending", "SortAscend", strings(1,0), true, cell(1,0)), ...
                gwidgets.internal.table.backend.JSTableBackend.menuItem( ...
                    "Descending", "SortDescend", strings(1,0), true, cell(1,0)), ...
                gwidgets.internal.table.backend.JSTableBackend.menuItem( ...
                    "None", "SortNone", strings(1,0), true, cell(1,0))};
            item = gwidgets.internal.table.backend.JSTableBackend.menuItem( ...
                "Sort", "", strings(1,0), true, children);
        end

        function item = selectionMenuItem(options)
            item = [];
            if numel(options.SupportedSelectionTypes) <= 1
                return
            end

            children = cell(1,0);
            if any(options.SupportedSelectionTypes == "cell")
                children{end+1} = gwidgets.internal.table.backend.JSTableBackend.menuItem( ...
                    "Cell", "CellSelection", strings(1,0), true, cell(1,0));
            end
            if any(options.SupportedSelectionTypes == "row")
                children{end+1} = gwidgets.internal.table.backend.JSTableBackend.menuItem( ...
                    "Row", "RowSelection", strings(1,0), true, cell(1,0));
            end
            if any(options.SupportedSelectionTypes == "column")
                children{end+1} = gwidgets.internal.table.backend.JSTableBackend.menuItem( ...
                    "Column", "ColumnSelection", strings(1,0), true, cell(1,0));
            end

            item = gwidgets.internal.table.backend.JSTableBackend.menuItem( ...
                "Selection Mode", "", strings(1,0), true, children);
        end

        function items = toggleMenuItems(options)
            items = cell(1,0);
            if options.HasToggleFilter
                items{end+1} = gwidgets.internal.table.backend.JSTableBackend.menuItem( ...
                    "Show/hide row filter", "ToggleRowFilter", strings(1,0), true, cell(1,0));
            end

            if options.HasChangeDisplayOrientation
                items{end+1} = gwidgets.internal.table.backend.JSTableBackend.menuItem( ...
                    gwidgets.internal.table.backend.JSTableBackend.displayOrientationMenuText(options), ...
                    "ToggleDisplayOrientation", strings(1,0), true, cell(1,0));
            end

            if options.HasToggleGroupHeaderTooltips
                items{end+1} = gwidgets.internal.table.backend.JSTableBackend.menuItem( ...
                    gwidgets.internal.table.backend.JSTableBackend.groupHeaderTooltipMenuText(options), ...
                    "ToggleGroupHeaderTooltips", strings(1,0), true, cell(1,0));
            end

            if options.HasToggleTableMetrics
                items{end+1} = gwidgets.internal.table.backend.JSTableBackend.menuItem( ...
                    gwidgets.internal.table.backend.JSTableBackend.tableMetricsMenuText(options), ...
                    "ToggleTableMetrics", strings(1,0), true, cell(1,0));
            end

            if options.HasAutoResizeColumns
                items{end+1} = gwidgets.internal.table.backend.JSTableBackend.menuItem( ...
                    "Auto-resize columns", "AutoResizeColumns", strings(1,0), true, cell(1,0));
            end

            if options.HasToggleDragging
                menuText = "Enable row dragging";
                if options.DragEnabled
                    menuText = "Disable row dragging";
                end
                items{end+1} = gwidgets.internal.table.backend.JSTableBackend.menuItem( ...
                    menuText, "ToggleDragging", strings(1,0), true, cell(1,0));
            end
        end

        function text = displayOrientationMenuText(options)
            arguments
                options (1,1) struct
            end

            text = "Transpose table";
            if options.DisplayOrientation == "Transposed"
                text = "Untranspose table";
            end
        end

        function text = groupHeaderTooltipMenuText(options)
            arguments
                options (1,1) struct
            end

            text = "Show group header tooltips";
            if options.ShowGroupHeaderTooltips
                text = "Hide group header tooltips";
            end
        end

        function text = tableMetricsMenuText(options)
            arguments
                options (1,1) struct
            end

            text = "Show table metrics";
            if options.ShowMetrics
                text = "Hide table metrics";
            end
        end

        function item = variableMenuItem(label, action, variables, names, selectedVariables, selectedNames, allText)
            children = cell(1, 2 + numel(variables));
            children{1} = gwidgets.internal.table.backend.JSTableBackend.menuItem( ...
                allText, action, variables, true, cell(1,0));

            selectedEnabled = ~isempty(selectedVariables);
            children{2} = gwidgets.internal.table.backend.JSTableBackend.menuItem( ...
                gwidgets.internal.table.backend.JSTableBackend.selectedActionText(selectedNames), ...
                action, selectedVariables, selectedEnabled, cell(1,0));

            for iVariable = 1:numel(variables)
                children{2+iVariable} = gwidgets.internal.table.backend.JSTableBackend.menuItem( ...
                    names(iVariable), action, variables(iVariable), true, cell(1,0));
            end

            item = gwidgets.internal.table.backend.JSTableBackend.menuItem( ...
                label, "", strings(1,0), true, children);
        end

        function [variables, names] = selectedRemoveItems(options)
            isSelected = ismember(options.SelectedGroupingVariables, options.GroupingVariables);
            variables = options.SelectedGroupingVariables(isSelected);
            names = options.SelectedGroupingVariableNames(isSelected);
        end

        function text = selectedActionText(selectedNames)
            text = "Selected";
            if ~isempty(selectedNames)
                text = "Selected (" + strjoin(selectedNames, ", ") + ")";
            end
        end

        function item = menuItem(text, action, value, enabled, children)
            arguments
                text (1,1) string
                action (1,1) string
                value (1,:) string
                enabled (1,1) logical
                children (1,:) cell
            end

            item = struct( ...
                "text", char(text), ...
                "action", char(action), ...
                "value", {cellstr(value)}, ...
                "enabled", enabled, ...
                "children", {children});
        end

        function type = widthType(value)
            if isnumeric(value) && isscalar(value)
                type = "Pixel";
                return
            end

            value = lower(string(value));
            if value == "fit"
                type = "Fit";
            elseif endsWith(value, "px")
                type = "Pixel";
            else
                type = "Relative";
            end
        end

        function width = pixelWidth(value)
            width = NaN;
            if isnumeric(value) && isscalar(value)
                width = double(value);
                return
            end

            value = lower(string(value));
            if ~endsWith(value, "px")
                return
            end

            width = str2double(extractBefore(value, strlength(value) - 1));
        end

        function values = displayValues(data)
            values = cell(height(data), width(data));
            for iRow = 1:height(data)
                for iCol = 1:width(data)
                    values{iRow, iCol} = char(gwidgets.internal.table.backend.JSTableBackend.valueText( ...
                        data{iRow, iCol}));
                end
            end
        end

        function cellValues = displayCellValues(data)
            nRows = height(data);
            nCols = width(data);
            if nRows == 0 || nCols == 0
                cellValues = strings(1,0);
                return
            end

            valueMatrix = strings(nRows, nCols);
            for iCol = 1:nCols
                valueMatrix(:, iCol) = gwidgets.internal.table.backend.JSTableBackend.displayColumnValues( ...
                    data, iCol);
            end
            cellValues = reshape(valueMatrix.', 1, []);
        end

        function values = displayColumnValues(data, iCol)
            nRows = height(data);
            columnData = data{:, iCol};
            if gwidgets.internal.table.backend.JSTableBackend.isScalarDisplayColumn(columnData, nRows)
                values = reshape(string(columnData), [], 1);
                return
            end

            values = strings(nRows, 1);
            for iRow = 1:nRows
                values(iRow) = gwidgets.internal.table.backend.JSTableBackend.valueText(data{iRow, iCol});
            end
        end

        function tf = isScalarDisplayColumn(columnData, nRows)
            tf = ismatrix(columnData) && size(columnData, 1) == nRows && size(columnData, 2) == 1 && ...
                (isstring(columnData) || isnumeric(columnData) || islogical(columnData) || ...
                iscategorical(columnData) || isdatetime(columnData) || isduration(columnData));
        end

        function text = valueText(value)
            if iscell(value) && isscalar(value)
                value = value{1};
            end

            if isstring(value)
                if isempty(value)
                    text = "";
                else
                    text = value(1);
                end
            elseif ischar(value)
                text = string(value);
            elseif isnumeric(value) || islogical(value)
                if isscalar(value)
                    text = string(value);
                else
                    text = string(mat2str(value));
                end
            elseif iscategorical(value) || isdatetime(value) || isduration(value)
                text = string(value);
            elseif ismissing(value)
                text = "";
            else
                try
                    text = string(value);
                catch
                    text = "<" + string(class(value)) + ">";
                end
            end
        end

        function newData = coerceEditData(editData, previousData)
            editText = string(editData);
            if iscell(previousData)
                if isempty(previousData)
                    newData = {char(editText)};
                else
                    newData = {gwidgets.internal.table.backend.JSTableBackend.coerceEditData( ...
                        editText, previousData{1})};
                end
                return
            end

            if isstring(previousData)
                newData = editText;
            elseif ischar(previousData)
                newData = char(editText);
            elseif isnumeric(previousData)
                newData = gwidgets.internal.table.backend.JSTableBackend.numericEditData(editText, previousData);
            elseif islogical(previousData)
                newData = gwidgets.internal.table.backend.JSTableBackend.logicalEditData(editText);
            elseif iscategorical(previousData)
                newData = categorical(editText, categories(previousData));
            elseif isdatetime(previousData)
                newData = datetime(editText);
            elseif isduration(previousData)
                newData = duration(editText);
            else
                newData = editText;
            end
        end

        function newData = numericEditData(editText, previousData)
            numericValue = str2double(editText);
            if isnan(numericValue) && strlength(strtrim(editText)) > 0
                newData = editText;
                return
            end

            if isa(previousData, "double")
                newData = numericValue;
            else
                newData = cast(numericValue, class(previousData));
            end
        end

        function newData = logicalEditData(editText)
            normalised = lower(strtrim(editText));
            newData = ismember(normalised, ["true", "1", "yes", "on"]);
        end

        function css = styleCss(style)
            arguments
                style (1,1) matlab.ui.style.Style
            end

            parts = strings(1,0);
            if ~isempty(style.BackgroundColor)
                parts(end+1) = "background-color:" + gwidgets.table.TooltipStyle.cssColor(style.BackgroundColor);
            end
            if ~isempty(style.FontColor)
                parts(end+1) = "color:" + gwidgets.table.TooltipStyle.cssColor(style.FontColor);
            end
            if gwidgets.internal.table.backend.JSTableBackend.hasTextValue(style.FontWeight)
                parts(end+1) = "font-weight:" + string(style.FontWeight);
            end
            if gwidgets.internal.table.backend.JSTableBackend.hasTextValue(style.FontAngle)
                parts(end+1) = "font-style:" + string(style.FontAngle);
            end
            if gwidgets.internal.table.backend.JSTableBackend.hasTextValue(style.FontName)
                parts(end+1) = "font-family:" + string(style.FontName);
            end
            if gwidgets.internal.table.backend.JSTableBackend.hasTextValue(style.HorizontalAlignment)
                parts(end+1) = "text-align:" + string(style.HorizontalAlignment);
            end

            if isempty(parts)
                css = "";
            else
                css = strjoin(parts, ";") + ";";
            end
        end

        function tf = hasTextValue(value)
            tf = ~isempty(value) && strlength(string(value)) > 0;
        end
    end
end
