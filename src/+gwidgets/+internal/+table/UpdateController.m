classdef UpdateController < gwidgets.internal.table.TableController
    % UpdateController owns update suppression and table update sequencing.

    properties (Access = private)
        UpdateManager (1,:) gwidgets.internal.UpdateManager {mustBeScalarOrEmpty} = gwidgets.internal.UpdateManager()
        GroupingController (1,:) gwidgets.internal.table.GroupingController {mustBeScalarOrEmpty}
        SortingController (1,:) gwidgets.internal.table.SortingController {mustBeScalarOrEmpty}
    end

    methods
        function this = UpdateController(owner)
            arguments
                owner (1,1) gwidgets.UITable
            end

            this@gwidgets.internal.table.TableController(owner);
            this.UpdateManager = gwidgets.internal.UpdateManager();
            this.GroupingController = gwidgets.internal.table.GroupingController();
            this.SortingController = gwidgets.internal.table.SortingController();
        end

        function delete(this)
            delete(this.GroupingController);
            delete(this.SortingController);
        end

        function addSuppression(this, propertyName, nvp)
            arguments
                this (1,1) gwidgets.internal.table.UpdateController
                propertyName (1,1) string
                nvp.Times (1,1) double = 1
            end

            this.UpdateManager.addSuppression(propertyName, Times=nvp.Times);
        end

        function tf = doRun(this, propertyName)
            arguments
                this (1,1) gwidgets.internal.table.UpdateController
                propertyName (1,1) string
            end

            tf = this.UpdateManager.doRun(propertyName);
        end

        function request(this, nvp)
            arguments
                this (1,1) gwidgets.internal.table.UpdateController
                nvp.StartFrom (1,1) string {mustBeMember(nvp.StartFrom, ...
                    ["Filtering", "Grouping", "Sorting", "Folding", "Display", "Style", "Interaction", "Skip"])}
            end

            this.run(StartFrom=nvp.StartFrom);
        end

        function run(this, nvp)
            arguments
                this (1,1) gwidgets.internal.table.UpdateController
                nvp.StartFrom (1,1) string {mustBeMember(nvp.StartFrom, ...
                    ["Filtering", "Grouping", "Sorting", "Folding", "Display", "Style", "Interaction", "Skip"])} = "Filtering"
            end

            owner = this.owner();
            updating = false;
            if nvp.StartFrom == "Filtering" || updating
                owner.Data.updateFiltering(owner.Filter, owner.Filter.FilterValue, owner.Column);
                updating = true;
            end

            if nvp.StartFrom == "Grouping" || updating
                owner.Data.updateGrouping(this.GroupingController, owner.Group);
                updating = true;
            end

            if nvp.StartFrom == "Sorting" || updating
                owner.Data.updateSorting(this.SortingController, owner.Sort, owner.Group, owner.Column);
                updating = true;
            end

            if nvp.StartFrom == "Folding" || updating
                owner.Data.updateFolding(this.GroupingController, owner.Group);
                owner.Group.updateLabel(owner.Graphics.GroupLabel, owner.Graphics.Grid, owner.Column, owner.Data);
                updating = true;
            end

            if nvp.StartFrom == "Display" || updating
                owner.Display.updateData();
                updating = true;
            end

            if nvp.StartFrom == "Style" || updating
                owner.Style.applyToDisplay();
                updating = true;
            end

            if nvp.StartFrom == "Interaction" || updating
                owner.Display.updateInteraction();
            end

            owner.forceRefresh();
        end
    end
end
