classdef DragLinker < handle
    %DRAGLINKER  Link a single drag source to a single drop target.
    %
    %   dl = DragLinker(source, target, callback, Name=Value)
    %
    %   Registers SOURCE as a draggable object and TARGET as its sole valid
    %   drop destination. CALLBACK is fired when SOURCE is successfully
    %   dropped onto TARGET.
    %
    %   Supports App Designer figures (uifigure) with components like
    %   uibutton, uiaxes, uipanel, uilabel, uilistbox, and uitree.
    %
    %   Name-Value Arguments:
    %       DragKey       - Modifier key required for drag ("control", "alt", 
    %                       "shift", or "" for no modifier). Default: "control"
    %       UseItemGhost  - Show selected item text for ListBox/Tree sources.
    %                       Default: false
    %
    %   Callback signature:
    %       function myCallback(source, target, releasePoint)
    %           % releasePoint: [x,y] in target figure coordinates
    %       end
    %
    %   Events:
    %       DragStarted    - Fired when drag gesture begins
    %       DragSuccessful - Fired when drop is successful
    %       DragFailed     - Fired when drop fails validation
    %
    %   Example - Basic drag and drop:
    %       fig = uifigure();
    %       btn = uibutton(fig, "Position", [20 150 100 30]);
    %       pnl = uipanel(fig, "Position", [20 20 200 100]);
    %       dl  = DragLinker(btn, pnl, @(src,tgt,pt) disp("Dropped!"));
    %
    %   Example - ListBox with item-level ghost:
    %       lst = uilistbox(fig, "Items", ["A";"B";"C"], "Multiselect", "on");
    %       pnl = uipanel(fig, "Position", [150 20 200 200]);
    %       dl  = DragLinker(lst, pnl, @onDrop, "UseItemGhost", true);
    %
    %       function onDrop(src, tgt, pt)
    %           items = src.Value;  % Get selected items
    %           fprintf("Dropped %d items at [%.1f, %.1f]\n", ...
    %                   numel(items), pt(1), pt(2));
    %       end

    % ------------------------------------------------------------------ %
    properties (SetAccess = private)
        Source (1,:) matlab.graphics.Graphics {mustBeScalarOrEmpty}     % Draggable object handle
        Target (1,:) matlab.graphics.Graphics {mustBeScalarOrEmpty}     % Drop target handle
        Callback (1,:) function_handle {mustBeScalarOrEmpty}            % Drop callback function
    end

    properties (Access = private)
        SourceFigure         % Source figure handle
        TargetFigure         % Target figure handle

        % Drag configuration
        DragKey (1,1) string = "control"           % Required modifier key
        UseItemGhost (1,1) logical = false         % Show item-level ghost

        % Drag state
        KeyPressed (1,1) string = ""               % Currently pressed modifiers
        IsClicked (1,1) logical = false            % Mouse down on source
        IsDragging (1,1) logical = false           % Drag gesture active
        ClickPosition (1,2) double = [NaN NaN]     % Initial click position
        DragGhost matlab.ui.control.Label = ...    % Ghost element
            matlab.ui.control.Label.empty

        % Target highlighting
        OrigTargetBgColor

        % Event listeners
        KeyPressListener event.listener = event.listener.empty
        KeyReleaseListener event.listener = event.listener.empty
        MousePressListener event.listener = event.listener.empty
        MouseMotionListener event.listener = event.listener.empty
        MouseReleaseListener event.listener = event.listener.empty
    end

    properties (Dependent)
        AllFigures          % All visible figures (for cross-figure dragging)
    end

    properties (Hidden)
        IsDebugMode (1,1) logical = false          % Enable debug output
    end

    events
        DragStarted         % Fired when drag gesture begins
        DragSuccessful      % Fired when drop succeeds
        DragFailed          % Fired when drop fails
    end

    % ================================================================== %
    methods

        function obj = DragLinker(source, target, callback, nvp)
            arguments
                source (1,1) matlab.graphics.Graphics
                target (1,1) matlab.graphics.Graphics
                callback (1,1) function_handle
                nvp.DragKey (1,1) string {mustBeMember(nvp.DragKey, ...
                    ["control", "alt", "shift", ""])} = "control"
                nvp.UseItemGhost (1,1) logical = false
            end

            obj.Source = source;
            obj.Target = target;
            obj.Callback = callback;
            obj.DragKey = nvp.DragKey;
            obj.UseItemGhost = nvp.UseItemGhost;

            obj.SourceFigure = ancestor(source, "figure");
            obj.TargetFigure = ancestor(target, "figure");

            if isempty(obj.SourceFigure) || isempty(obj.TargetFigure)
                error("DragLinker:invalidParent", ...
                      "Source and target must belong to a figure.");
            end

            obj.attachSourceListeners();
        end

        function delete(obj)
            % Clean up listeners and ghost element
            delete(obj.KeyPressListener);
            delete(obj.KeyReleaseListener);
            delete(obj.MousePressListener);
            delete(obj.MouseMotionListener);
            delete(obj.MouseReleaseListener);
            obj.deleteGhost();
        end

        function disp(obj)
            fprintf("  DragLinker\n");
            fprintf("    Source     : %s\n", obj.componentLabel(obj.Source));
            fprintf("    Target     : %s\n", obj.componentLabel(obj.Target));
            fprintf("    Callback   : %s\n", func2str(obj.Callback));
            fprintf("    DragKey    : ""%s""\n", obj.DragKey);
            fprintf("    ItemGhost  : %s\n", string(obj.UseItemGhost));
        end

        function val = get.AllFigures(~)
            val = findall(groot, "Type", "figure", "Visible", "on");
        end

    end  % public methods

    % ================================================================== %
    methods (Access = private)

        % ---- Listener Setup ----------------------------------------- %

        function attachSourceListeners(obj)
            % Attach persistent listeners on the source figure
            obj.MousePressListener = event.listener(obj.SourceFigure, ...
                "WindowMousePress", @(src, evt) obj.onMousePress(src, evt));

            obj.KeyPressListener = event.listener(obj.SourceFigure, ...
                "WindowKeyPress", @(src, evt) obj.onKeyPress(src, evt));

            obj.KeyReleaseListener = event.listener(obj.SourceFigure, ...
                "WindowKeyRelease", @(src, evt) obj.onKeyRelease(src, evt));
        end

        function attachTargetListeners(obj)
            % Attach temporary motion/release listeners across all figures
            obj.deleteTargetListeners();  % Clear any existing

            allFigs = obj.AllFigures;
            obj.MouseMotionListener = event.listener.empty(1, 0);
            obj.MouseReleaseListener = event.listener.empty(1, 0);

            for i = 1:numel(allFigs)
                % Ensure WindowButtonMotionFcn exists to enable motion events
                if isempty(allFigs(i).WindowButtonMotionFcn)
                    allFigs(i).WindowButtonMotionFcn = @(~,~) [];
                end

                obj.MouseMotionListener(end+1) = event.listener(allFigs(i), ...
                    "WindowMouseMotion", @(src, evt) obj.onMouseMotion(src, evt));

                obj.MouseReleaseListener(end+1) = event.listener(allFigs(i), ...
                    "WindowMouseRelease", @(src, evt) obj.onMouseRelease(src, evt));
            end
        end

        function deleteTargetListeners(obj)
            delete(obj.MouseMotionListener);
            delete(obj.MouseReleaseListener);
            obj.MouseMotionListener = event.listener.empty;
            obj.MouseReleaseListener = event.listener.empty;
        end

        % ---- Event Handlers ----------------------------------------- %

        function onKeyPress(obj, ~, evt)
            obj.KeyPressed = strjoin(string(evt.Modifier), "+");
        end

        function onKeyRelease(obj, ~, ~)
            obj.KeyPressed = "";
        end

        function onMousePress(obj, ~, evt)
            % Only respond to clicks directly on our source component
            if ~isequal(evt.HitObject, obj.Source)
                return
            end

            obj.ClickPosition = obj.SourceFigure.CurrentPoint;
            obj.IsClicked = true;
            obj.attachTargetListeners();

            if obj.IsDebugMode
                fprintf("[DEBUG] Clicked on %s\n", obj.componentText(obj.Source));
            end
        end

        function onMouseMotion(obj, ~, ~)
            if ~obj.IsClicked
                return
            end

            % Determine which figure the cursor is over
            cursorFig = obj.figureAtCursor();
            if isempty(cursorFig)
                return
            end
            cursorFig = cursorFig(1);

            currentPoint = obj.cursorPositionForFigure(cursorFig);

            % Start drag if cursor moved enough AND correct key is pressed
            if ~obj.IsDragging
                % Always compute distance in source figure coordinates
                % to avoid mixed reference frames when crossing figures
                srcPoint = obj.cursorPositionForFigure(obj.SourceFigure);
                distance = norm(srcPoint - obj.ClickPosition);
                correctKey = obj.isDragKeyPressed();

                if distance < 5 || ~correctKey
                    return
                end

                obj.startDrag(currentPoint, cursorFig);
            end

            % Update ghost position
            if ~isempty(obj.DragGhost) && isvalid(obj.DragGhost)
                obj.updateGhost(currentPoint, cursorFig);
            else
                obj.createGhost(currentPoint, cursorFig);
            end
        end

        function onMouseRelease(obj, src, ~)
            if ~obj.IsClicked
                return
            end

            obj.deleteTargetListeners();

            if ~obj.IsDragging
                obj.IsClicked = false;
                return
            end

            obj.finalizeDrag(src);
        end

        % ---- Drag Lifecycle ----------------------------------------- %

        function startDrag(obj, currentPoint, cursorFig)
            obj.IsDragging = true;
            [obj.AllFigures.Pointer] = deal("hand");

            obj.createGhost(currentPoint, cursorFig);
            obj.highlightTarget(true);

            notify(obj, "DragStarted");

            if obj.IsDebugMode
                fprintf("[DEBUG] Started dragging %s\n", ...
                        obj.componentText(obj.Source));
            end
        end

        function finalizeDrag(obj, ~)
            obj.deleteGhost();
            [obj.AllFigures.Pointer] = deal("arrow");
            obj.highlightTarget(false);

            % Check if dropped on target
            cursorFig = obj.figureAtCursor();
            if ~isempty(cursorFig)
                cursorFig = cursorFig(1);
                releasePoint = obj.cursorPositionForFigure(cursorFig);
                targetPos = obj.getAbsolutePosition(obj.Target);

                isOnTarget = isequal(cursorFig, obj.TargetFigure) && ...
                             obj.pointInRect(releasePoint, targetPos);

                if isOnTarget
                    obj.invokeCallback(releasePoint);
                else
                    notify(obj, "DragFailed");
                    if obj.IsDebugMode
                        fprintf("[DEBUG] Drag failed - not on target\n");
                    end
                end
            end

            obj.IsDragging = false;
            obj.IsClicked = false;
        end

        % ---- Ghost Management --------------------------------------- %

        function createGhost(obj, position, parentFig)
            ghostPos = [position, obj.Source.Position(3:4)];

            if obj.UseItemGhost && (isa(obj.Source, "matlab.ui.control.ListBox") ...
                    || isa(obj.Source, "matlab.ui.container.Tree"))
                ghostPos(3) = max(ghostPos(3), 120);
                ghostPos(4) = 30;
            end

            ghostText = obj.componentText(obj.Source);

            obj.DragGhost = uilabel(parentFig, ...
                "Text", ghostText, ...
                "Position", ghostPos, ...
                "BackgroundColor", [0.75 0.88 1.0], ...
                "FontColor", [0.15 0.15 0.15], ...
                "FontWeight", "bold", ...
                "HorizontalAlignment", "center", ...
                "VerticalAlignment", "center");
        end

        function updateGhost(obj, position, parentFig)
            gp = obj.DragGhost.Position;
            gp(1:2) = position;
            obj.DragGhost.Position = gp;
            obj.DragGhost.Parent = parentFig;
        end

        function deleteGhost(obj)
            if ~isempty(obj.DragGhost) && isvalid(obj.DragGhost)
                delete(obj.DragGhost);
            end
            obj.DragGhost = matlab.ui.control.Label.empty;
        end

        % ---- Target Highlighting ------------------------------------ %

        function highlightTarget(obj, on)
            if ~isprop(obj.Target, "BackgroundColor")
                return
            end

            if on
                obj.OrigTargetBgColor = obj.Target.BackgroundColor;
                obj.Target.BackgroundColor = [0.78 1.0 0.78];  % Soft green
            elseif ~on
                obj.Target.BackgroundColor = obj.OrigTargetBgColor;
            end
        end

        % ---- Helpers ------------------------------------------------ %

        function tf = isDragKeyPressed(obj)
            % Check if the required drag key is pressed
            if obj.DragKey == ""
                tf = true;  % No key required
            else
                tf = isequal(obj.KeyPressed, obj.DragKey);
            end
        end

        function txt = componentText(obj, h)
            % Extract display text for ghost label
            if obj.UseItemGhost && isa(h, "matlab.ui.control.ListBox")
                if ~isempty(h.Value)
                    vals = h.Value;
                    if numel(vals) == 1
                        txt = string(vals{1});
                    else
                        txt = sprintf("%d items", numel(vals));
                    end
                else
                    txt = "List Items";
                end
            elseif obj.UseItemGhost && isa(h, "matlab.ui.container.Tree")
                if ~isempty(h.SelectedNodes)
                    nodes = {h.SelectedNodes.Text};
                    if numel(nodes) == 1
                        txt = string(nodes{1});
                    else
                        txt = sprintf("%d nodes", numel(nodes));
                    end
                else
                    txt = "Tree Nodes";
                end
            elseif isa(h, "matlab.ui.control.UIAxes")
                txt = string(h.Title.String);
                if txt == ""
                    txt = "UIAxes";
                end
            elseif isprop(h, "Text") && ~isempty(h.Text)
                txt = string(h.Text);
            elseif isprop(h, "String") && ~isempty(h.String)
                txt = string(h.String);
            elseif isprop(h, "Title") && ~isempty(h.Title)
                txt = string(h.Title);
            elseif isprop(h, "Tag") && ~isempty(h.Tag)
                txt = string(h.Tag);
            else
                txt = string(class(h));
            end
        end

        function invokeCallback(obj, releasePoint)
            if obj.IsDebugMode
                fprintf("[DEBUG] Dropped %s on %s at [%.1f, %.1f]\n", ...
                        obj.componentText(obj.Source), ...
                        obj.componentText(obj.Target), ...
                        releasePoint(1), releasePoint(2));
            end

            obj.Callback(obj.Source, obj.Target, releasePoint);
            notify(obj, "DragSuccessful");
        end

    end  % private methods

    % ================================================================== %
    methods (Static)

        function pos = getAbsolutePosition(h)
            % Get absolute position in figure coordinates
            if ~isvalid(h)
                pos = [NaN NaN NaN NaN];
                return
            end

            pos = h.Position;
            parent = h.Parent;

            % Walk up the parent chain accumulating offsets
            while ~isempty(parent) && ~isa(parent, "matlab.ui.Figure")
                if isprop(parent, "Position")
                    pos(1:2) = pos(1:2) + parent.Position(1:2);
                end
                parent = parent.Parent;
            end
        end

        function tf = pointInRect(cp, rect)
            % Test if point is inside rectangle
            tf = cp(1) >= rect(1) && cp(1) <= rect(1) + rect(3) && ...
                 cp(2) >= rect(2) && cp(2) <= rect(2) + rect(4);
        end

        function label = componentLabel(h)
            % Human-readable component description
            if isa(h, "matlab.ui.control.Button")
                label = sprintf("uibutton - ""%s""", h.Text);
            elseif isa(h, "matlab.ui.control.ListBox")
                label = sprintf("uilistbox - %d items", numel(h.Items));
            elseif isa(h, "matlab.ui.container.Tree")
                label = sprintf("uitree - %d children", numel(h.Children));
            elseif isa(h, "matlab.ui.container.Panel")
                label = sprintf("uipanel - ""%s""", h.Title);
            elseif isa(h, "matlab.ui.control.UIAxes")
                label = "uiaxes";
            elseif isprop(h, "Type")
                label = string(h.Type);
            else
                label = string(class(h));
            end
        end

        function figs = figureAtCursor()
            % Find figure(s) under the cursor
            g = groot();
            cursorPos = g.PointerLocation;
            allFigs = findall(groot, "Type", "figure", "Visible", "on");

            isNormal = strcmp({allFigs.WindowStyle}, "normal");
            positions = vertcat(allFigs.Position);

            inX = cursorPos(1) >= positions(:,1) & ...
                  cursorPos(1) <= positions(:,1) + positions(:,3);
            inY = cursorPos(2) >= positions(:,2) & ...
                  cursorPos(2) <= positions(:,2) + positions(:,4);

            figs = allFigs(isNormal(:) & inX & inY);
        end

        function pos = cursorPositionForFigure(fig)
            % Get cursor position in figure coordinates
            g = groot();
            screenPos = g.PointerLocation;
            figPos = fig.Position;
            pos = screenPos - figPos(1:2);
        end

    end  % static methods

end  % classdef