classdef WithFigureFixture < matlab.unittest.TestCase
    
    methods (Access = protected)
        
        function fh = figureFixture(this, nvp)
            arguments
                this 
                nvp.Type (1,1) string {mustBeMember(nvp.Type, ["figure", "uifigure"])} = "figure"
            end

            fx = this.applyFixture(fixtures.FigureFixture("Type", nvp.Type));
            fh = fx.FigureHandle;
            
        end
        
    end
    
end