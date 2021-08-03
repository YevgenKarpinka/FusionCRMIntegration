page 50070 "Integration CRM Setup"
{
    PageType = List;
    ApplicationArea = All;
    UsageCategory = Administration;
    SourceTable = "Integration CRM Setup";
    SourceTableView = sorting(Code) order(descending);
    AccessByPermission = tabledata "Integration CRM Setup" = rimd;

    layout
    {
        area(Content)
        {
            repeater(RepeaterName)
            {
                field(Code; Rec.Code)
                {
                    ApplicationArea = All;

                }
                field(URL; Rec.URL)
                {
                    ApplicationArea = All;

                }
                field(Param; Rec.Param)
                {
                    ApplicationArea = All;

                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(EntitySetup)
            {
                CaptionML = ENU = 'Entity Setup',
                            RUS = 'Entity Setup';
                ApplicationArea = All;
                RunPageMode = View;
                RunObject = Page "Entity Setup";
            }
            action(IntegrationCRMLog)
            {
                CaptionML = ENU = 'Integration CRM',
                            RUS = 'Integration CRM';
                ApplicationArea = All;
                RunPageMode = View;
                RunObject = Page "Integration CRM Log List";
            }
            action(EntitiesCRM)
            {
                CaptionML = ENU = 'Entities CRM',
                            RUS = 'Entities CRM';
                ApplicationArea = All;
                RunPageMode = View;
                RunObject = Page "Entity CRM List";
            }
            action(SendEntities)
            {
                CaptionML = ENU = 'Send Entities',
                            RUS = 'Send Entities';
                ApplicationArea = All;

                trigger OnAction()
                begin
                    Codeunit.Run(Codeunit::"Integration CRM");
                    Message(lblProcessCompleted);
                end;
            }
            action(SendAllUoMs)
            {
                CaptionML = ENU = 'Send All UoMs',
                            RUS = 'Send All UoMs';
                ApplicationArea = All;

                trigger OnAction()
                begin
                    glUoM.Reset();
                    if glUoM.FindSet() then
                        repeat
                            IntegrationCRM.EntityCRMOnUpdateIdBeforeSend(lblUoM, glUoM.Code, '', glUoM.SystemId);
                        until glUoM.Next() = 0;
                    Message(lblProcessCompleted);
                end;
            }
            action(SendAllItems)
            {
                CaptionML = ENU = 'Send All Items',
                            RUS = 'Send All Items';
                ApplicationArea = All;

                trigger OnAction()
                begin
                    glItem.Reset();
                    if glItem.FindSet() then
                        repeat
                            IntegrationCRM.EntityCRMOnUpdateIdBeforeSend(lblItem, glItem."No.", '', glItem.SystemId);
                        until glItem.Next() = 0;
                    Message(lblProcessCompleted);
                end;
            }
            action(SendAllCustomers)
            {
                CaptionML = ENU = 'Send All Customers',
                            RUS = 'Send All Customers';
                ApplicationArea = All;

                trigger OnAction()
                begin
                    glCustomer.Reset();
                    if glCustomer.FindSet() then
                        repeat
                            IntegrationCRM.EntityCRMOnUpdateIdBeforeSend(lblCustomer, glCustomer."No.", '', glCustomer.SystemId);
                        until glCustomer.Next() = 0;
                    Message(lblProcessCompleted);
                end;
            }
            action(SendAllInvoices)
            {
                CaptionML = ENU = 'Send All Invoices',
                            RUS = 'Send All Invoices';
                ApplicationArea = All;

                trigger OnAction()
                begin
                    EntitySetup.Get(lblInvoice);
                    glSIH.Reset();

                    if glSIH.FindSet() then
                        repeat
                            if EntitySetup."Source CRM" then begin
                                if not IsNullGuid(glSIH."CRM ID") then
                                    IntegrationCRM.EntityCRMOnUpdateIdBeforeSend(lblInvoice, glSIH."No.", '', glSIH.SystemId)
                            end else
                                IntegrationCRM.EntityCRMOnUpdateIdBeforeSend(lblInvoice, glSIH."No.", '', glSIH.SystemId);
                        until glSIH.Next() = 0;
                    Message(lblProcessCompleted);
                end;
            }
        }
    }

    var
        EntitySetup: Record "Entity Setup";
        glUoM: Record "Unit of Measure";
        glItem: Record Item;
        glCustomer: Record Customer;
        glSIH: Record "Sales Invoice Header";
        IntegrationCRM: Codeunit "Integration CRM";
        lblUoM: Label 'UOM';
        lblItem: Label 'ITEM';
        lblCustomer: Label 'CUSTOMER';
        lblInvoice: Label 'INVOICE';
        lblPackage: Label 'PACKAGE';
        lblProcessCompleted: Label 'Process Completed';
        blankGuid: Guid;
}