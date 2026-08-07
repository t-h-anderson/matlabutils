classdef tBaseWorkspaceManager < matlab.unittest.TestCase

    methods (Test)
        function tGuardClearsNewValue(testCase)
            variableName = "mlutWorkspaceNewValue";
            baseWorkspace = mlut.workspace.BaseWorkspaceManager();
            baseWorkspace.clear(variableName);
            cleanup = onCleanup(@() baseWorkspace.clear(variableName));

            guardCleanup = mlut.workspace.BaseWorkspaceManager.createGuard(baseWorkspace);
            baseWorkspace.assign(variableName, 42);

            testCase.verifyEqual(baseWorkspace.evaluate(variableName), 42);
            delete(guardCleanup);
            testCase.verifyFalse(baseWorkspace.exists(variableName));

            clear cleanup
        end

        function tGuardRestoresExistingValue(testCase)
            variableName = "mlutWorkspaceExistingValue";
            baseWorkspace = mlut.workspace.BaseWorkspaceManager();
            baseWorkspace.assign(variableName, "before");
            cleanup = onCleanup(@() baseWorkspace.clear(variableName));

            guardCleanup = mlut.workspace.BaseWorkspaceManager.createGuard(baseWorkspace);
            baseWorkspace.assign(variableName, "after");

            testCase.verifyEqual(baseWorkspace.evaluate(variableName), "after");
            delete(guardCleanup);
            testCase.verifyEqual(baseWorkspace.evaluate(variableName), "before");

            clear cleanup
        end

        function tGuardRestoresEvenAfterLaterMutation(testCase)
            variableName = "mlutWorkspaceLaterMutation";
            baseWorkspace = mlut.workspace.BaseWorkspaceManager();
            baseWorkspace.assign(variableName, 10);
            cleanup = onCleanup(@() baseWorkspace.clear(variableName));

            guardCleanup = mlut.workspace.BaseWorkspaceManager.createGuard(baseWorkspace);
            baseWorkspace.assign(variableName, 20);
            baseWorkspace.assign(variableName, 99);

            delete(guardCleanup);
            testCase.verifyEqual(baseWorkspace.evaluate(variableName), 10);

            clear cleanup
        end

        function tAssignCanPreserveCharInterop(testCase)
            variableName = "mlutWorkspaceCharValue";
            baseWorkspace = mlut.workspace.BaseWorkspaceManager();
            baseWorkspace.clear(variableName);
            cleanup = onCleanup(@() baseWorkspace.clear(variableName));

            guardCleanup = mlut.workspace.BaseWorkspaceManager.createGuard(baseWorkspace);
            baseWorkspace.assign(variableName, "legacy", StringAs="char");

            value = baseWorkspace.evaluate(variableName);
            testCase.verifyClass(value, "char");
            testCase.verifyEqual(value, 'legacy');

            delete(guardCleanup);
            clear cleanup
        end

        function tGuardRestoresClearedExistingValue(testCase)
            variableName = "mlutWorkspaceClearedValue";
            baseWorkspace = mlut.workspace.BaseWorkspaceManager();
            baseWorkspace.assign(variableName, 11);
            cleanup = onCleanup(@() baseWorkspace.clear(variableName));

            guardCleanup = mlut.workspace.BaseWorkspaceManager.createGuard(baseWorkspace);
            baseWorkspace.clear(variableName);

            testCase.verifyFalse(baseWorkspace.exists(variableName));
            delete(guardCleanup);
            testCase.verifyEqual(baseWorkspace.evaluate(variableName), 11);

            clear cleanup
        end

        function tStaticGuardCanCreateManager(testCase)
            variableName = "mlutWorkspaceStaticGuardValue";
            [guardCleanup, baseWorkspace] = mlut.workspace.BaseWorkspaceManager.createGuard();
            cleanup = onCleanup(@() baseWorkspace.clear(variableName));

            baseWorkspace.assign(variableName, 33);

            testCase.verifyEqual(baseWorkspace.evaluate(variableName), 33);
            delete(guardCleanup);
            testCase.verifyFalse(baseWorkspace.exists(variableName));

            clear cleanup
        end

        function tListsVariableNamesAndMetadata(testCase)
            variableName = "mlutWorkspaceMetadataValue";
            baseWorkspace = mlut.workspace.BaseWorkspaceManager();
            baseWorkspace.assign(variableName, uint16(7));
            cleanup = onCleanup(@() baseWorkspace.clear(variableName));

            testCase.verifyEqual(baseWorkspace.variableNames(variableName), variableName);

            info = baseWorkspace.variables(variableName);
            testCase.verifyEqual(info.Name, variableName);
            testCase.verifyEqual(info.Class, "uint16");

            clear cleanup
        end

        function tEvaluateDoesNotMutateBaseWorkspace(testCase)
            variableName = "mlutWorkspaceEvaluateValue";
            baseWorkspace = mlut.workspace.BaseWorkspaceManager();
            baseWorkspace.assign(variableName, 10);
            cleanup = onCleanup(@() baseWorkspace.clear(variableName));

            value = baseWorkspace.evaluate(variableName + " + 5");

            testCase.verifyEqual(value, 15);
            testCase.verifyEqual(baseWorkspace.evaluate(variableName), 10);

            clear cleanup
        end

        function tRunMutatesBaseWorkspace(testCase)
            variableName = "mlutWorkspaceRunValue";
            baseWorkspace = mlut.workspace.BaseWorkspaceManager();
            baseWorkspace.clear(variableName);
            cleanup = onCleanup(@() baseWorkspace.clear(variableName));

            baseWorkspace.run(variableName + " = 21;");

            testCase.verifyTrue(baseWorkspace.exists(variableName));
            testCase.verifyEqual(baseWorkspace.evaluate(variableName), 21);

            clear cleanup
        end

        function tNormalManagerDoesNotRestoreOnDelete(testCase)
            variableName = "mlutWorkspacePersistentValue";
            baseWorkspace = mlut.workspace.BaseWorkspaceManager();
            baseWorkspace.clear(variableName);
            cleanup = onCleanup(@() baseWorkspace.clear(variableName));

            temporaryManager = mlut.workspace.BaseWorkspaceManager();
            temporaryManager.assign(variableName, "kept");
            delete(temporaryManager);

            testCase.verifyTrue(baseWorkspace.exists(variableName));
            testCase.verifyEqual(baseWorkspace.evaluate(variableName), "kept");

            clear cleanup
        end

        function tRejectsNestedGuard(testCase)
            baseWorkspace = mlut.workspace.BaseWorkspaceManager();
            guardCleanup = mlut.workspace.BaseWorkspaceManager.createGuard(baseWorkspace);

            testCase.verifyError( ...
                @() mlut.workspace.BaseWorkspaceManager.createGuard(baseWorkspace), ...
                "mlut:workspace:guardAlreadyActive");

            delete(guardCleanup);
            nextGuardCleanup = mlut.workspace.BaseWorkspaceManager.createGuard(baseWorkspace);
            testCase.verifyInstanceOf(nextGuardCleanup, "onCleanup");
            delete(nextGuardCleanup);
        end
    end
end
