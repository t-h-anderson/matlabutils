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
end
