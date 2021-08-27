codeunit 50071 "Invoice Overdue"
{
    trigger OnRun()
    begin
        Code();
    end;

    var
        EntityCRM: Record "Entity CRM";
        UpdateEntityCRM: Record "Entity CRM";
        CustLedgEntry: Record "Cust. Ledger Entry";
        lblInvoiceStatus: Label 'INVOICESTATUS';

    local procedure Code()
    begin
        EntityCRM.Reset();
        EntityCRM.SetRange("Modify In CRM", true);
        EntityCRM.SetRange("Invoice Open", true);
        EntityCRM.SetRange(Code, lblInvoiceStatus);
        if EntityCRM.FindSet() then
            repeat
                CustLedgEntry.Reset();
                CustLedgEntry.SetCurrentKey("Document No.");
                CustLedgEntry.SetRange("Document No.", EntityCRM.Key1);
                CustLedgEntry.SetRange("Document Type", CustLedgEntry."Document Type"::Invoice);
                if CustLedgEntry.FindFirst()
                and (CustLedgEntry."Due Date" < DT2Date(CurrentDateTime)) then begin
                    UpdateEntityCRM.Get(EntityCRM.Code, EntityCRM.Key1, EntityCRM.Key2);
                    UpdateEntityCRM."Modify In CRM" := false;
                    UpdateEntityCRM.Modify(true);
                end;
            until EntityCRM.Next() = 0;
    end;
}