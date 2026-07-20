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

            this.setup(owner.Graphics.Grid, owner.Graphics.DisplayTable);
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

            blocks = this.owner().Tooltip.resolveBlocks(displayRow, displayColumn);
            if isempty(this.Bridge) || ~isvalid(this.Bridge)
                return
            end

            this.send("SetTooltip", struct("blocks", {blocks}));
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
                case "CellHover"
                    if this.hasTooltips()
                        this.applyTooltipPayload(double(d.row), double(d.col));
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
            if owner.Column.didBridgeWidthsChange(d.widths)
                owner.Column.updateStoresFromBridgeWidths(d.widths);
                owner.Display.applyColumnWidth();
            else
                this.restore();
            end
        end

        function tf = hasTooltips(this)
            tf = ~isempty(this.owner().Tooltip.Tooltips);
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
end

