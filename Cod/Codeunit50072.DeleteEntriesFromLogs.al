codeunit 50072 "Delete Entries From Logs"
{
    trigger OnRun()
    begin
        Execute();
    end;

    var
        integrationCRMLog: Record "Integration CRM Log";
        jobQueueLogEntry: Record "Job Queue Log Entry";

    local procedure Execute()
    begin
        integrationCRMLog.DeleteEntries(31);
        jobQueueLogEntry.DeleteEntries(31);
    end;

    [EventSubscriber(ObjectType::Table, 474, 'OnBeforeDeleteEntries', '', false, false)]
    local procedure OnBeforeDeleteEntries(var SkipConfirm: Boolean)
    begin
        SkipConfirm := true;
    end;

}