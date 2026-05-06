classdef tIsEmptyOrMissing < matlab.unittest.TestCase

    methods (Test)

        function tEmptyInputIsTrue(testCase)
            testCase.verifyTrue(mlut.isEmptyOrMissing([]))
            testCase.verifyTrue(mlut.isEmptyOrMissing(""))
            testCase.verifyTrue(mlut.isEmptyOrMissing(string.empty))
            testCase.verifyTrue(mlut.isEmptyOrMissing(double.empty))
        end

        function tNonEmptyScalarNonMissingIsFalse(testCase)
            testCase.verifyFalse(mlut.isEmptyOrMissing(1))
            testCase.verifyFalse(mlut.isEmptyOrMissing("a"))
            testCase.verifyFalse(mlut.isEmptyOrMissing(false))
        end

        function tScalarMissingIsTrue(testCase)
            testCase.verifyTrue(mlut.isEmptyOrMissing(NaN))
            testCase.verifyTrue(mlut.isEmptyOrMissing(missing))
            testCase.verifyTrue(mlut.isEmptyOrMissing(string(missing)))
        end

        function tNonScalarWithoutVectorMissingFallsThroughAsFalse(testCase)
            % VectorMissing defaults to false, so a non-empty, non-scalar
            % input takes no missingness branch and returns false.
            testCase.verifyFalse(mlut.isEmptyOrMissing([NaN NaN]))
            testCase.verifyFalse(mlut.isEmptyOrMissing([1 2 3]))
        end

        function tVectorMissingAllMissingIsTrue(testCase)
            testCase.verifyTrue(mlut.isEmptyOrMissing([NaN NaN], VectorMissing=true))
            testCase.verifyTrue(mlut.isEmptyOrMissing([missing, missing], VectorMissing=true))
        end

        function tVectorMissingPartiallyMissingIsFalse(testCase)
            testCase.verifyFalse(mlut.isEmptyOrMissing([1 NaN], VectorMissing=true))
        end

        function tIndicatorTreatedAsMissing(testCase)
            testCase.verifyTrue(mlut.isEmptyOrMissing(-1, Indicator=-1))
            testCase.verifyFalse(mlut.isEmptyOrMissing(0, Indicator=-1))
        end

        function tVectorMissingWithIndicator(testCase)
            testCase.verifyTrue(mlut.isEmptyOrMissing([-1 -1], ...
                VectorMissing=true, Indicator=-1))
            testCase.verifyFalse(mlut.isEmptyOrMissing([-1 0], ...
                VectorMissing=true, Indicator=-1))
        end

        function tMissingFuncOnScalarTreatsTrueAsMissing(testCase)
            isNeg = @(x) x < 0;
            testCase.verifyTrue(mlut.isEmptyOrMissing(-1, MissingFunc=isNeg))
            testCase.verifyFalse(mlut.isEmptyOrMissing(1, MissingFunc=isNeg))
        end

        function tMissingFuncWithVectorMissing(testCase)
            isNeg = @(x) x < 0;
            testCase.verifyTrue(mlut.isEmptyOrMissing([-1 -2], ...
                VectorMissing=true, MissingFunc=isNeg))
            testCase.verifyFalse(mlut.isEmptyOrMissing([-1 1], ...
                VectorMissing=true, MissingFunc=isNeg))
        end

    end

end
