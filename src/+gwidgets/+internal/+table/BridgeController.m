classdef BridgeController < gwidgets.internal.table.TableController
    % BridgeController owns uihtml bridge setup and browser event dispatch.

    properties (Dependent)
        DiagEnabled (1,1) logical
    end

    properties (Access = private)
        Bridge (1,:) matlab.ui.control.HTML {mustBeScalarOrEmpty}
        DisplayTableTag (1,1) string = ""
        DiagEnabled_ (1,1) logical = false
    end

    methods
        function this = BridgeController(owner)
            arguments
                owner (1,1) gwidgets.UITable
            end

            this@gwidgets.internal.table.TableController(owner);
        end

        function delete(this)
            delete(this.Bridge);
        end

        function initialize(this)
            arguments
                this (1,1) gwidgets.internal.table.BridgeController
            end

            owner = this.owner();
            if isempty(owner)
                return
            end

            owner.Graphics.setupBridge(this);
        end

        function setup(this, grid, displayTable)
            arguments
                this (1,1) gwidgets.internal.table.BridgeController
                grid (1,1) matlab.ui.container.GridLayout
                displayTable (1,1) matlab.ui.control.Table
            end

            if ~isempty(this.Bridge) && isvalid(this.Bridge)
                return
            end

            this.DisplayTableTag = "graphicscomponentsTable_" + mlut.uniqueID();
            displayTable.Tag = this.DisplayTableTag;

            internalFolder = fileparts(fileparts(mfilename("fullpath")));
            htmlFile = fullfile(internalFolder, "table_bridge.html");

            this.Bridge = uihtml( ...
                Parent=grid, ...
                HTMLSource=htmlFile, ...
                DataChangedFcn=@(src,~) this.onData(src), ...
                Visible="off");

            this.Bridge.Layout.Row = 4;
            this.Bridge.Layout.Column = 1;

            this.DiagEnabled = this.DiagEnabled_;
        end

        function val = get.DiagEnabled(this)
            val = this.DiagEnabled_;
        end

        function set.DiagEnabled(this, val)
            arguments
                this (1,1) gwidgets.internal.table.BridgeController
                val (1,1) logical
            end

            this.DiagEnabled_ = val;
            this.send("Diag", val);
        end

        function enableHover(this)
            arguments
                this (1,1) gwidgets.internal.table.BridgeController
            end

            this.send("HoverEnable", []);
        end

        function disableHover(this)
            arguments
                this (1,1) gwidgets.internal.table.BridgeController
            end

            this.send("HoverDisable", []);
        end

        function enableDragging(this, moveKey, copyKey)
            arguments
                this (1,1) gwidgets.internal.table.BridgeController
                moveKey (1,1) string
                copyKey (1,1) string
            end

            this.send("DragEnable", struct("moveKey", moveKey, "copyKey", copyKey));
        end

        function disableDragging(this)
            arguments
                this (1,1) gwidgets.internal.table.BridgeController
            end

            this.send("DragDisable", []);
        end

        function suppress(this)
            arguments
                this (1,1) gwidgets.internal.table.BridgeController
            end

            this.send("Suppress", []);
        end

        function restore(this)
            arguments
                this (1,1) gwidgets.internal.table.BridgeController
            end

            this.send("Restore", []);
        end

        function ready(this)
            arguments
                this (1,1) gwidgets.internal.table.BridgeController
            end

            this.send("Ready", []);
            this.applyGroupHeaderSpans();
        end

        function requestGroupSpanMeasurement(this)
            arguments
                this (1,1) gwidgets.internal.table.BridgeController
            end

            this.send("MeasureGroupSpans", []);
        end

        function reattach(this)
            arguments
                this (1,1) gwidgets.internal.table.BridgeController
            end

            this.ready();
        end

        function applyTooltipPayload(this, displayRow, displayColumn)
            arguments
                this (1,1) gwidgets.internal.table.BridgeController
                displayRow (1,1) double
                displayColumn (1,1) double
            end

            owner = this.owner();
            blocks = owner.Tooltip.resolveBlocks(displayRow, displayColumn);
            owner.emitTableEvent("TooltipRequested", gwidgets.table.TableEventData( ...
                Action="hover", ...
                DisplayIndices=[displayRow, displayColumn], ...
                DataIndices=owner.eventDisplayToData([displayRow, displayColumn], "cell"), ...
                TooltipBlocks={blocks}, ...
                TooltipText=gwidgets.table.TableEventData.tooltipTextFromBlocks(blocks)));
            if isempty(this.Bridge) || ~isvalid(this.Bridge)
                return
            end

            this.send("SetTooltip", struct("blocks", {blocks}));
        end

        function applyGroupHeaderSpans(this)
            arguments
                this (1,1) gwidgets.internal.table.BridgeController
            end

            owner = this.owner();
            if isempty(owner)
                backend = [];
            else
                backend = owner.Graphics.Backend;
            end
            if isempty(backend) || ~backend.isReady()
                this.send("SetGroupHeaderSpans", struct( ...
                    "rows", zeros(1,0), "labels", {cell(1,0)}, ...
                    "tooltips", {cell(1,0)}, "styles", {cell(1,0)}));
                this.send("SetGroupColumnSpans", struct( ...
                    "columns", zeros(1,0), "labels", {cell(1,0)}, ...
                    "tooltips", {cell(1,0)}, "styles", {cell(1,0)}));
                return
            end

            if owner.Display.Orientation == "Transposed"
                this.send("SetGroupHeaderSpans", struct( ...
                    "rows", zeros(1,0), "labels", {cell(1,0)}, ...
                    "tooltips", {cell(1,0)}, "styles", {cell(1,0)}));
                styleCss = owner.Style.groupHeaderOverlayCss(owner.Data.VisibleGroupHeaderRowIdx);
                payload = gwidgets.internal.table.BridgeController.groupColumnSpanPayload( ...
                    owner.Data.Display, owner.Data.VisibleGroupHeaderRowIdx, styleCss, ...
                    ShowTooltips=owner.ShowGroupHeaderTooltips);
                this.send("SetGroupColumnSpans", payload);
            else
                this.send("SetGroupColumnSpans", struct( ...
                    "columns", zeros(1,0), "labels", {cell(1,0)}, ...
                    "tooltips", {cell(1,0)}, "styles", {cell(1,0)}));
                styleCss = owner.Style.groupHeaderOverlayCss(owner.Data.VisibleGroupHeaderRowIdx);
                payload = gwidgets.internal.table.BridgeController.groupHeaderSpanPayload( ...
                    owner.Data.Display, owner.Data.VisibleGroupHeaderRowIdx, styleCss, ...
                    ShowTooltips=owner.ShowGroupHeaderTooltips);
                this.send("SetGroupHeaderSpans", payload);
            end
        end
    end

    methods (Static)
        function payload = groupHeaderSpanPayload(displayData, rowIdx, styleCss, nvp)
            arguments
                displayData (:,:) table
                rowIdx (1,:) double
                styleCss (1,:) string = strings(1,0)
                nvp.ShowTooltips (1,1) logical = true
            end

            if width(displayData) == 0 || isempty(rowIdx)
                payload = struct( ...
                    "rows", zeros(1,0), ...
                    "labels", {cell(1,0)}, ...
                    "tooltips", {cell(1,0)}, ...
                    "styles", {cell(1,0)});
                return
            end

            valid = rowIdx >= 1 & rowIdx <= height(displayData);
            rowIdx = rowIdx(valid);
            styleCss = gwidgets.internal.table.BridgeController.validSpanCss(styleCss, valid);
            labels = strings(1, numel(rowIdx));
            for iRow = 1:numel(rowIdx)
                labels(iRow) = gwidgets.internal.table.BridgeController.labelString(displayData{rowIdx(iRow), 1});
            end
            tooltips = gwidgets.internal.table.BridgeController.groupSpanTooltips(labels, nvp.ShowTooltips);

            payload = struct( ...
                "rows", rowIdx, ...
                "labels", {cellstr(labels)}, ...
                "tooltips", {cellstr(tooltips)}, ...
                "styles", {cellstr(styleCss)});
        end

        function payload = groupColumnSpanPayload(displayData, rowIdx, styleCss, nvp)
            arguments
                displayData (:,:) table
                rowIdx (1,:) double
                styleCss (1,:) string = strings(1,0)
                nvp.ShowTooltips (1,1) logical = true
            end

            columns = rowIdx + 1;
            if height(displayData) == 0 || width(displayData) == 0 || isempty(columns)
                payload = struct( ...
                    "columns", zeros(1,0), ...
                    "labels", {cell(1,0)}, ...
                    "tooltips", {cell(1,0)}, ...
                    "styles", {cell(1,0)});
                return
            end

            valid = columns >= 1 & columns <= width(displayData);
            columns = columns(valid);
            styleCss = gwidgets.internal.table.BridgeController.validSpanCss(styleCss, valid);
            labels = strings(1, numel(columns));
            for iColumn = 1:numel(columns)
                labels(iColumn) = gwidgets.internal.table.BridgeController.labelString( ...
                    displayData{1, columns(iColumn)});
            end
            tooltips = gwidgets.internal.table.BridgeController.groupSpanTooltips(labels, nvp.ShowTooltips);

            payload = struct( ...
                "columns", columns, ...
                "labels", {cellstr(labels)}, ...
                "tooltips", {cellstr(tooltips)}, ...
                "styles", {cellstr(styleCss)});
        end
    end

    methods (Access = private)
        function onData(this, src)
            d = src.Data;
            if ~isstruct(d) || ~isfield(d, "event")
                return
            end

            switch d.event
                case "BridgeReady"
                    this.onReady();
                case "ColumnWidthChanged"
                    this.onColumnWidthChanged(d);
                case "GroupSpanMeasure"
                    this.owner().Display.applyGroupSpanMeasurements(d);
                case "CellHover"
                    if this.hasTooltips()
                        row = double(d.row);
                        col = double(d.col);
                        if row == 0 && col == 0
                            owner = this.owner();
                            owner.emitTableEvent("TooltipCleared", gwidgets.table.TableEventData( ...
                                Action="leave", ...
                                DisplayIndices=[row, col], ...
                                DataIndices=owner.eventDisplayToData([row, col], "cell")));
                            this.send("SetTooltip", struct("blocks", {cell(1,0)}));
                            return
                        end
                        this.applyTooltipPayload(row, col);
                    end
                case "TableDragStart"
                    this.owner().Drag.onBridgeDragStart(d);
                case "TableDrop"
                    this.owner().Drag.onBridgeDrop(d);
                case "BridgeDiag"
                    fprintf("%s\n", d.msg);
                otherwise
                    % Unknown browser events are ignored for forward compatibility.
            end
        end

        function onReady(this)
            this.send("Init", struct("tableTag", this.DisplayTableTag));
            this.send("Diag", this.DiagEnabled_);
            this.ready();
            if this.hasTooltips()
                this.enableHover();
            end
        end

        function onColumnWidthChanged(this, d)
            if isfield(d, "moving") && d.moving
                return
            end

            owner = this.owner();
            owner.Display.handleBridgeColumnWidths(d.widths);
        end

        function tf = hasTooltips(this)
            owner = this.owner();
            tf = owner.Tooltip.Text ~= "" || ~isempty(owner.Tooltip.Tooltips) || owner.Metric.Enabled;
        end

        function send(this, eventName, payload)
            arguments
                this (1,1) gwidgets.internal.table.BridgeController
                eventName (1,1) string
                payload
            end

            if isempty(this.Bridge) || ~isvalid(this.Bridge)
                return
            end

            sendEventToHTMLSource(this.Bridge, eventName, payload);
        end
    end

    methods (Static, Access = private)
        function label = labelString(value)
            if iscell(value)
                if isempty(value)
                    label = "";
                    return
                end
                value = value{1};
            end

            if isstring(value)
                if isempty(value)
                    label = "";
                else
                    label = value(1);
                end
            elseif ischar(value)
                label = string(value);
            else
                label = string(value);
            end
        end

        function styleCss = validSpanCss(styleCss, valid)
            styleCss = reshape(string(styleCss), 1, []);
            if isempty(styleCss)
                styleCss = strings(1, nnz(valid));
                return
            end

            if numel(styleCss) == numel(valid)
                styleCss = styleCss(valid);
            elseif numel(styleCss) ~= nnz(valid)
                nStyles = min(numel(styleCss), nnz(valid));
                styleCss = [styleCss(1:nStyles), strings(1, nnz(valid) - nStyles)];
            end
        end

        function tooltips = groupSpanTooltips(labels, showTooltips)
            arguments
                labels (1,:) string
                showTooltips (1,1) logical
            end

            if showTooltips
                tooltips = labels;
            else
                tooltips = strings(1, numel(labels));
            end
        end
    end
end
