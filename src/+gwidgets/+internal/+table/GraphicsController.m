classdef GraphicsController < gwidgets.internal.table.TableController
    % GraphicsController owns table UI handle creation and layout state.

    properties (SetAccess = private)
        Grid (1,:) matlab.ui.container.GridLayout {mustBeScalarOrEmpty}
        GroupLabel (1,:) matlab.ui.control.Label {mustBeScalarOrEmpty}
        DisplayTable (1,:) matlab.ui.control.Table {mustBeScalarOrEmpty}
        HelpPanel (1,:) matlab.ui.container.Panel {mustBeScalarOrEmpty}
        FilterComponent (1,:) gwidgets.internal.FilterController {mustBeScalarOrEmpty}
    end

    properties (Access = private)
        FilterHelpListener (1,:) event.listener
    end

    methods
        function this = GraphicsController(owner)
            arguments
                owner (1,:) gwidgets.UITable = gwidgets.UITable.empty(1,0)
            end

            this@gwidgets.internal.table.TableController(owner);
        end

        function initialize(this)
            arguments
                this (1,1) gwidgets.internal.table.GraphicsController
            end

            owner = this.owner();
            if isempty(owner)
                return
            end

            this.FilterHelpListener = this.weaklistener(owner.Filter, ...
                ["FilterHelpRequested", "FilterHelpClosed"]);
        end

        function setup(this, owner)
            arguments
                this (1,1) gwidgets.internal.table.GraphicsController
                owner (1,1) gwidgets.UITable
            end

            this.Grid = uigridlayout(owner, ...
                RowHeight={"fit", 0, "1x", 2}, ColumnWidth={"1x", 0}, Padding=0);

            this.HelpPanel = uipanel(Parent=this.Grid);
            this.HelpPanel.Layout.Column = 2;
            this.HelpPanel.Layout.Row = [1 3];

            helpParent = uigridlayout(this.HelpPanel, [1,1], Padding=0);
            this.FilterComponent = gwidgets.internal.FilterController( ...
                Parent=this.Grid, ...
                HelpParent=helpParent);
            this.FilterComponent.Layout.Column = 1;
            this.FilterComponent.Layout.Row = 1;

            this.GroupLabel = uilabel(Parent=this.Grid);
            this.GroupLabel.Layout.Column = 1;
            this.GroupLabel.Layout.Row = 2;

            this.DisplayTable = uitable(this.Grid);
            this.DisplayTable.ClickedFcn = @(s, e)owner.Callback.onCellClicked(s, e);
            this.DisplayTable.DoubleClickedFcn = @(s, e)owner.Callback.onCellDoubleClicked(s, e);
            this.DisplayTable.CellSelectionCallback = @(s, e)owner.Callback.onSelection(s, e);
            this.DisplayTable.CellEditCallback = @(s, e)owner.Callback.onCellEdit(s, e);
            this.DisplayTable.DisplayDataChangedFcn = @(s, e)owner.Callback.onDisplayDataChanged(s, e);
            this.DisplayTable.Layout.Column = 1;
            this.DisplayTable.Layout.Row = 3;
        end

        function setRowFilterVisible(this, state)
            arguments
                this (1,1) gwidgets.internal.table.GraphicsController
                state (1,1) logical
            end

            if state
                this.Grid.RowHeight{1} = "fit";
            else
                this.Grid.RowHeight{1} = 0;
            end
        end

        function showFilterHelp(this)
            arguments
                this (1,1) gwidgets.internal.table.GraphicsController
            end

            this.Grid.ColumnWidth = {"1x", "1x"};
        end

        function hideFilterHelp(this)
            arguments
                this (1,1) gwidgets.internal.table.GraphicsController
            end

            this.Grid.ColumnWidth = {"1x", 0};
        end
    end

    methods (Access = {?gwidgets.internal.WithWeakListeners})
        function onFilterHelpRequested(this, ~, ~)
            this.showFilterHelp();
        end

        function onFilterHelpClosed(this, ~, ~)
            this.hideFilterHelp();
        end
    end
end
