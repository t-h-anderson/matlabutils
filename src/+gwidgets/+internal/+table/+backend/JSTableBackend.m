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
            this.Component.Layout.Column = 1;
            this.Component.Layout.Row = 3;
            this.configureThemeListener(owner);
        end

        function setupBridge(~, ~)
            % The JS backend owns its DOM directly; it does not need the
            % DOM-scraping bridge used by matlab.ui.control.Table.
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

            this.ContextMenuCustomItems_ = customItems;
            this.ContextMenuCallbacks_ = callbacks;
            this.ContextMenuItems_ = gwidgets.internal.table.backend.JSTableBackend.contextMenuItems( ...
                options, customItems);
            this.sendState();
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
            this.sendState();
        end

        function removeStyle(this)
            arguments
                this (1,1) gwidgets.internal.table.backend.JSTableBackend
            end

            this.StyleConfigurations_ = gwidgets.internal.table.backend.TableBackend.emptyStyleConfigurations();
            this.sendState();
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
                case "DisplayDataChanged"
                    this.onDisplayDataChanged(data);
                case "ColumnWidthChanged"
                    this.onColumnWidthChanged(data);
                case "CellHover"
                    this.onCellHover(data);
                case "CellLeave"
                    this.sendTooltipBlocks(cell(1,0));
                case "ContextMenuAction"
                    this.onContextMenuAction(data);
                case "ProbeResult"
                    this.ProbeResult = data;
                otherwise
                    % Unknown browser events are ignored for forward compatibility.
            end
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
            renderPayload = this.tablePayload();

            lastSendTime = -Inf;
            startTime = tic;
            while toc(startTime) < nvp.Timeout
                elapsedTime = toc(startTime);
                if elapsedTime - lastSendTime >= 0.1
                    try
                        sendEventToHTMLSource(this.Component, "Render", renderPayload);
                        sendEventToHTMLSource(this.Component, "Probe", request);
                        lastSendTime = elapsedTime;
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
            this.sendState();
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

            source = struct("SelectionType", char(this.SelectionType_));
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
            previousData = this.previousData(row, col);
            editData = string(data.value);
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

            owner.Display.handleBridgeColumnWidths(double(data.widths));
        end

        function onCellHover(this, data)
            owner = this.owner();
            if isempty(owner) || ~isfield(data, "row") || ~isfield(data, "col")
                this.sendTooltipBlocks(cell(1,0));
                return
            end

            if isempty(owner.Tooltip.Tooltips)
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

        function sendState(this)
            if ~this.isReady()
                return
            end

            payload = this.tablePayload();
            try
                sendEventToHTMLSource(this.Component, "Render", payload);
            catch
                % uihtml can be constructed before the browser side is ready.
            end
        end

        function payload = tablePayload(this)
            data = this.Data_;
            displayColumnNames = this.displayColumnNames();
            [cellRows, cellCols, cellValues] = ...
                gwidgets.internal.table.backend.JSTableBackend.displayCellPayload(data);
            payload = struct( ...
                "columns", {cellstr(displayColumnNames)}, ...
                "values", {this.displayValues(data)}, ...
                "rowCount", height(data), ...
                "cellRows", cellRows, ...
                "cellCols", cellCols, ...
                "cellValues", {cellstr(cellValues)}, ...
                "selectionType", char(this.SelectionType_), ...
                "multiselect", char(string(this.Multiselect_)), ...
                "selection", this.Selection_, ...
                "columnEditable", this.ColumnEditable_, ...
                "columnSortable", this.ColumnSortable_, ...
                "columnWidth", {this.columnWidthPayload()}, ...
                "groupHeaderRows", this.GroupHeaderRows_, ...
                "groupHeaderLevels", this.GroupHeaderLevels_, ...
                "tooltip", char(this.Tooltip_), ...
                "contextMenu", {this.ContextMenuItems_}, ...
                "theme", char(this.themePayload()), ...
                "styles", {this.stylePayload()});
        end

        function configureThemeListener(this, owner)
            delete(this.ThemeListener);
            this.ThemeListener = event.listener.empty(1,0);

            fig = ancestor(owner, "figure");
            if isempty(fig)
                return
            end

            try
                this.ThemeListener = addlistener(fig, "ThemeChanged", @(~, ~)this.sendState());
            catch
                try
                    this.ThemeListener = addlistener(fig, "Theme", "PostSet", @(~, ~)this.sendState());
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
                case "CustomItem"
                    this.invokeCustomMenuItem(value);
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

        function invokeCustomMenuItem(this, value)
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
            item.MenuSelectedFcn(item, []);
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
                customItems (1,:) matlab.ui.container.Menu
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

            for iItem = 1:numel(customItems)
                nItems = nItems + 1;
                itemCells{nItems} = gwidgets.internal.table.backend.JSTableBackend.menuItem( ...
                    string(customItems(iItem).Text), "CustomItem", string(iItem), ...
                    string(customItems(iItem).Enable) ~= "off", cell(1,0));
            end

            items = itemCells(1:nItems);
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

        function values = displayValues(data)
            values = cell(height(data), width(data));
            for iRow = 1:height(data)
                for iCol = 1:width(data)
                    values{iRow, iCol} = char(gwidgets.internal.table.backend.JSTableBackend.valueText( ...
                        data{iRow, iCol}));
                end
            end
        end

        function [cellRows, cellCols, cellValues] = displayCellPayload(data)
            nCells = height(data)*width(data);
            cellRows = zeros(1, nCells);
            cellCols = zeros(1, nCells);
            cellValues = strings(1, nCells);
            iCell = 0;
            for iRow = 1:height(data)
                for iCol = 1:width(data)
                    iCell = iCell + 1;
                    cellRows(iCell) = iRow;
                    cellCols(iCell) = iCol;
                    cellValues(iCell) = gwidgets.internal.table.backend.JSTableBackend.valueText( ...
                        data{iRow, iCol});
                end
            end
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
