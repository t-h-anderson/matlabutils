classdef TooltipStyle
    % TooltipStyle holds the visual properties of a tooltip popup.
    %
    % Mirrors the shape of matlab.ui.style.Style but with the subset of
    % properties that map onto the bridge-rendered popup div. Each
    % property has an "unset" sentinel (missing/NaN) so partial overrides
    % can stack on top of a base style without specifying everything.

    properties
        BackgroundColor = missing % MATLAB color spec (RGB triplet, name, or hex string)
        FontColor       = missing
        FontWeight (1,1) string = "normal" % "normal" | "bold"
        FontSize        = NaN              % pixels
        FontFamily (1,1) string = ""       % "" leaves the browser default
        Padding         = NaN              % pixels
        BorderColor     = missing
        BorderRadius    = NaN              % pixels
    end

    methods
        function this = TooltipStyle(nvp)
            arguments
                nvp.BackgroundColor = missing
                nvp.FontColor       = missing
                nvp.FontWeight (1,1) string = "normal"
                nvp.FontSize        = NaN
                nvp.FontFamily (1,1) string = ""
                nvp.Padding         = NaN
                nvp.BorderColor     = missing
                nvp.BorderRadius    = NaN
            end
            this.BackgroundColor = nvp.BackgroundColor;
            this.FontColor       = nvp.FontColor;
            this.FontWeight      = nvp.FontWeight;
            this.FontSize        = nvp.FontSize;
            this.FontFamily      = nvp.FontFamily;
            this.Padding         = nvp.Padding;
            this.BorderColor     = nvp.BorderColor;
            this.BorderRadius    = nvp.BorderRadius;
        end

        function merged = merge(this, override)
            % merge layers `override` on top of `this`. Any unset property
            % on `override` falls through to `this`. Used to compose a
            % per-tooltip style on top of the widget DefaultTooltipStyle
            % on top of TooltipStyle.default().
            arguments
                this
                override (1,1) gwidgets.table.TooltipStyle
            end
            merged = this;
            if ~ismissing(override.BackgroundColor); merged.BackgroundColor = override.BackgroundColor; end
            if ~ismissing(override.FontColor);       merged.FontColor       = override.FontColor;       end
            if override.FontWeight ~= "normal";      merged.FontWeight      = override.FontWeight;      end
            if ~isnan(override.FontSize);            merged.FontSize        = override.FontSize;        end
            if override.FontFamily ~= "";            merged.FontFamily      = override.FontFamily;      end
            if ~isnan(override.Padding);             merged.Padding         = override.Padding;         end
            if ~ismissing(override.BorderColor);     merged.BorderColor     = override.BorderColor;     end
            if ~isnan(override.BorderRadius);        merged.BorderRadius    = override.BorderRadius;    end
        end

        function css = containerCss(this)
            % CSS subset that draws the block container (background,
            % padding, border, border-radius). Tooltips that agree on
            % these properties share a block.
            parts = strings(0, 1);
            if ~ismissing(this.BackgroundColor)
                parts(end+1, 1) = "background-color:" + gwidgets.table.TooltipStyle.cssColor(this.BackgroundColor);
            end
            if ~isnan(this.Padding)
                parts(end+1, 1) = "padding:" + this.Padding + "px";
            end
            if ~ismissing(this.BorderColor)
                parts(end+1, 1) = "border:1px solid " + gwidgets.table.TooltipStyle.cssColor(this.BorderColor);
            end
            if ~isnan(this.BorderRadius)
                parts(end+1, 1) = "border-radius:" + this.BorderRadius + "px";
            end
            css = strjoin(parts, ";");
            if css ~= ""
                css = css + ";";
            end
        end

        function css = lineCss(this)
            % CSS subset that draws a single line within a block (font
            % color, weight, size, family). Lines within the same block
            % can each carry their own line style.
            parts = strings(0, 1);
            if ~ismissing(this.FontColor)
                parts(end+1, 1) = "color:" + gwidgets.table.TooltipStyle.cssColor(this.FontColor);
            end
            if this.FontWeight ~= "normal"
                parts(end+1, 1) = "font-weight:" + this.FontWeight;
            end
            if ~isnan(this.FontSize)
                parts(end+1, 1) = "font-size:" + this.FontSize + "px";
            end
            if this.FontFamily ~= ""
                parts(end+1, 1) = "font-family:" + this.FontFamily;
            end
            css = strjoin(parts, ";");
            if css ~= ""
                css = css + ";";
            end
        end

        function key = containerKey(this)
            % Struct of container-only properties for grouping comparison.
            % isequaln on two containerKeys treats NaN/missing sentinels
            % as equal so tooltips with no explicit overrides group
            % together.
            key = struct( ...
                "BackgroundColor", this.BackgroundColor, ...
                "Padding",         this.Padding, ...
                "BorderColor",     this.BorderColor, ...
                "BorderRadius",    this.BorderRadius);
        end

        function css = toCss(this)
            % Concatenation of containerCss + lineCss — convenient when
            % rendering a single-line block (e.g. the table-wide
            % fallback tooltip).
            css = this.containerCss() + this.lineCss();
        end
    end

    methods (Static)
        function s = default()
            % Library-wide baseline. Approximates the browser-native
            % yellow tooltip so existing usage looks unchanged.
            s = gwidgets.table.TooltipStyle( ...
                BackgroundColor="#ffffe1", ...
                FontColor="#000000", ...
                FontSize=12, ...
                Padding=4, ...
                BorderColor="#a0a0a0", ...
                BorderRadius=3);
        end

        function s = cssColor(c)
            % Convert a MATLAB color spec (RGB triplet, color name, or
            % hex string) into a CSS color string.
            if isstring(c) || ischar(c)
                s = string(c);
                return
            end
            if isnumeric(c) && numel(c) == 3
                rgb = round(c(:).' .* 255);
                s = sprintf("rgb(%d,%d,%d)", rgb(1), rgb(2), rgb(3));
                return
            end
            s = "inherit";
        end
    end

end
