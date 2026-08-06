classdef UpdateController < gwidgets.internal.table.TableController
    % UpdateController owns update suppression and table update sequencing.

    properties (Access = private)
        UpdateManager (1,:) gwidgets.internal.UpdateManager {mustBeScalarOrEmpty} = gwidgets.internal.UpdateManager()
    end

    methods
        function this = UpdateController(owner)
            arguments
                owner (1,1) gwidgets.UITable
            end

            this@gwidgets.internal.table.TableController(owner);
            this.UpdateManager = gwidgets.internal.UpdateManager();
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
            beforeState = owner.eventSnapshot();
            stateUpdateToken = owner.Graphics.beginStateUpdate();
            cleanupObj = onCleanup(@()owner.Graphics.cancelStateUpdate(stateUpdateToken));

            % Keep this controller as the phase sequencer. Phase-specific
            % implementation should move behind the owning controllers.
            updating = false;
            if nvp.StartFrom == "Filtering" || updating
                owner.Data.updateFiltering();
                updating = true;
            end

            if nvp.StartFrom == "Grouping" || updating
                owner.Data.updateGrouping();
                updating = true;
            end

            if nvp.StartFrom == "Sorting" || updating
                owner.Data.updateSorting();
                updating = true;
            end

            if nvp.StartFrom == "Folding" || updating
                owner.Data.updateFolding();
                owner.Group.updateLabel();
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

            delete(cleanupObj);
            owner.Graphics.endStateUpdate(stateUpdateToken);
            owner.emitStateChangeEvents(beforeState);
            owner.forceRefresh();
        end
    end
end
