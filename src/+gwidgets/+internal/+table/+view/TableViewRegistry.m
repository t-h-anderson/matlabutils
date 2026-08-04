classdef TableViewRegistry < handle
    % TableViewRegistry stores named internal table views.

    properties (Access = private)
        Names_ (1,:) string = string.empty(1,0)
        Views_ (1,:) cell = cell.empty(1,0)
        PrimaryName_ (1,1) string = ""
    end

    methods
        function delete(this)
            this.deleteViews();
        end

        function attach(this, name, view, nvp)
            arguments
                this (1,1) gwidgets.internal.table.view.TableViewRegistry
                name (1,1) string
                view (1,1) gwidgets.internal.table.view.TableView
                nvp.Primary (1,1) logical = false
            end

            name = this.normalizeName(name);
            this.deleteView(name);
            this.Names_(end+1) = name;
            this.Views_{end+1} = view;

            if nvp.Primary || this.PrimaryName_ == ""
                this.PrimaryName_ = name;
            end
        end

        function view = detach(this, name)
            arguments
                this (1,1) gwidgets.internal.table.view.TableViewRegistry
                name (1,1) string
            end

            name = this.normalizeName(name);
            view = [];
            idx = this.indexOf(name);
            if isempty(idx)
                return
            end

            view = this.Views_{idx};
            this.Names_(idx) = [];
            this.Views_(idx) = [];
            if this.PrimaryName_ == name
                if isempty(this.Names_)
                    this.PrimaryName_ = "";
                else
                    this.PrimaryName_ = this.Names_(1);
                end
            end
        end

        function deleteView(this, name)
            arguments
                this (1,1) gwidgets.internal.table.view.TableViewRegistry
                name (1,1) string
            end

            view = this.detach(name);
            if ~isempty(view) && isvalid(view)
                delete(view);
            end
        end

        function deleteViews(this)
            arguments
                this (1,1) gwidgets.internal.table.view.TableViewRegistry
            end

            for iView = numel(this.Views_):-1:1
                view = this.Views_{iView};
                if ~isempty(view) && isvalid(view)
                    delete(view);
                end
            end

            this.Names_ = string.empty(1,0);
            this.Views_ = cell.empty(1,0);
            this.PrimaryName_ = "";
        end

        function names = names(this)
            arguments
                this (1,1) gwidgets.internal.table.view.TableViewRegistry
            end

            names = this.Names_;
        end

        function viewList = views(this)
            arguments
                this (1,1) gwidgets.internal.table.view.TableViewRegistry
            end

            viewList = this.Views_;
        end

        function view = primaryView(this)
            arguments
                this (1,1) gwidgets.internal.table.view.TableViewRegistry
            end

            view = [];
            if this.PrimaryName_ == ""
                return
            end

            view = this.view(this.PrimaryName_);
        end

        function view = view(this, name)
            arguments
                this (1,1) gwidgets.internal.table.view.TableViewRegistry
                name (1,1) string
            end

            view = [];
            idx = this.indexOf(name);
            if isempty(idx)
                return
            end

            view = this.Views_{idx};
        end

        function tf = has(this, name)
            arguments
                this (1,1) gwidgets.internal.table.view.TableViewRegistry
                name (1,1) string
            end

            tf = ~isempty(this.indexOf(name));
        end

        function setPrimary(this, name)
            arguments
                this (1,1) gwidgets.internal.table.view.TableViewRegistry
                name (1,1) string
            end

            name = this.normalizeName(name);
            if ~this.has(name)
                error("GraphicsWidgets:Table:UnknownView", ...
                    "No table view named ""%s"" is attached.", name);
            end

            this.PrimaryName_ = name;
        end

        function apply(this, fcn)
            arguments
                this (1,1) gwidgets.internal.table.view.TableViewRegistry
                fcn (1,1) function_handle
            end

            for iView = 1:numel(this.Views_)
                view = this.Views_{iView};
                if ~isempty(view) && isvalid(view)
                    fcn(view, this.Names_(iView));
                end
            end
        end
    end

    methods (Access = private)
        function idx = indexOf(this, name)
            arguments
                this (1,1) gwidgets.internal.table.view.TableViewRegistry
                name (1,1) string
            end

            name = this.normalizeName(name);
            idx = find(this.Names_ == name, 1);
        end
    end

    methods (Static, Access = private)
        function name = normalizeName(name)
            arguments
                name (1,1) string
            end

            name = strtrim(name);
            if name == ""
                error("GraphicsWidgets:Table:ViewName", "Table view name must be nonempty.");
            end
        end
    end
end
