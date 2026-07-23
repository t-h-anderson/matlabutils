classdef GraphicsController < gwidgets.internal.table.TableController
    % GraphicsController owns table UI handle creation and layout state.

    properties (SetAccess = private)
        Grid (1,:) matlab.ui.container.GridLayout {mustBeScalarOrEmpty}
        GroupLabel (1,:) matlab.ui.control.Label {mustBeScalarOrEmpty}
        HelpPanel (1,:) matlab.ui.container.Panel {mustBeScalarOrEmpty}
        FilterComponent (1,:) gwidgets.internal.FilterController {mustBeScalarOrEmpty}
        Backend (1,:) gwidgets.internal.table.backend.TableBackend {mustBeScalarOrEmpty} = ...
            gwidgets.internal.table.backend.UITableBackend.empty(1,0)
    end

    properties (Dependent, SetAccess = private)
        DisplayTable
    end

    properties (Access = private)
        BackendName (1,1) string {mustBeMember(BackendName, ["UITable", "JavaScript"])} = "UITable"
        FilterHelpListener (1,:) event.listener
    end

    methods
        function this = GraphicsController(owner, nvp)
            arguments
                owner (1,:) gwidgets.UITable = gwidgets.UITable.empty(1,0)
                nvp.Backend (1,1) string {mustBeMember(nvp.Backend, ["UITable", "JavaScript"])} = "UITable"
            end

            this@gwidgets.internal.table.TableController(owner);
            this.BackendName = nvp.Backend;
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

        function configureBackend(this, backendName, owner)
            arguments
                this (1,1) gwidgets.internal.table.GraphicsController
                backendName (1,1) string {mustBeMember(backendName, ["UITable", "JavaScript"])}
                owner (1,:) gwidgets.UITable = gwidgets.UITable.empty(1,0)
            end

            this.BackendName = backendName;
            if isempty(owner)
                owner = this.owner();
            end
            if isempty(owner) || isempty(this.Grid)
                return
            end

            this.ensureBackend(owner);
        end

        function setup(this, owner)
            arguments
                this (1,1) gwidgets.internal.table.GraphicsController
                owner (1,1) gwidgets.UITable
            end

            if isempty(this.Grid) || ~isvalid(this.Grid)
                this.Grid = uigridlayout(owner, ...
                    RowHeight={"fit", 0, "1x", 2}, ColumnWidth={"1x", 0}, Padding=0);
            end

            this.HelpPanel = uipanel(Parent=this.Grid);
            this.HelpPanel.Layout.Column = 2;
            this.HelpPanel.Layout.Row = [1 3];

            helpParent = uigridlayout(this.HelpPanel, [1,1], Padding=0);
            % The reusable filter component owns its internal graphics; this
            % controller only places it inside the table layout.
            this.FilterComponent = gwidgets.internal.FilterController( ...
                Parent=this.Grid, ...
                HelpParent=helpParent);
            this.FilterComponent.Layout.Column = 1;
            this.FilterComponent.Layout.Row = 1;

            this.GroupLabel = uilabel(Parent=this.Grid);
            this.GroupLabel.Layout.Column = 1;
            this.GroupLabel.Layout.Row = 2;

            this.ensureBackend(owner);
        end

        function val = get.DisplayTable(this)
            if isempty(this.Backend)
                val = [];
            else
                val = this.Backend.Component;
            end
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

    methods (Access = private)
        function ensureBackend(this, owner)
            if isempty(this.Backend) || ~this.isCurrentBackend()
                delete(this.Backend);
                this.Backend = gwidgets.internal.table.GraphicsController.createBackend(this.BackendName);
            end
            this.Backend.setup(owner, this.Grid);
        end

        function tf = isCurrentBackend(this)
            if isempty(this.Backend)
                tf = false;
                return
            end

            switch this.BackendName
                case "UITable"
                    tf = isa(this.Backend, "gwidgets.internal.table.backend.UITableBackend");
                case "JavaScript"
                    tf = isa(this.Backend, "gwidgets.internal.table.backend.JSTableBackend");
                otherwise
                    tf = false;
            end
        end
    end

    methods (Static, Access = private)
        function backend = createBackend(backendName)
            arguments
                backendName (1,1) string {mustBeMember(backendName, ["UITable", "JavaScript"])}
            end

            switch backendName
                case "JavaScript"
                    backend = gwidgets.internal.table.backend.JSTableBackend();
                otherwise
                    backend = gwidgets.internal.table.backend.UITableBackend();
            end
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
