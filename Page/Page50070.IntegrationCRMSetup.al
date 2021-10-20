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
                field(Production; Rec.Production)
                {
                    ApplicationArea = All;

                }
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
                    IntegrationCRM.PostAllUoM();
                    Message(lblProcessCompleted);
                end;
            }
            action(SendAllItemCategories)
            {
                CaptionML = ENU = 'Send All Item Categories',
                            RUS = 'Send All Item Categories';
                ApplicationArea = All;

                trigger OnAction()
                begin
                    IntegrationCRM.PostAllItemCategories();
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
                    IntegrationCRM.PostAllItems();
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
                    IntegrationCRM.PostAllCustomers();
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
                    IntegrationCRM.PostAllInvoices();
                    Message(lblProcessCompleted);
                end;
            }
            action(SendAllPackages)
            {
                CaptionML = ENU = 'Send All Packages',
                            RUS = 'Send All Packages';
                ApplicationArea = All;

                trigger OnAction()
                begin
                    IntegrationCRM.PostAllPackages();
                    Message(lblProcessCompleted);
                end;
            }
            action(SendAllEntities)
            {
                CaptionML = ENU = 'Send All Entities',
                            RUS = 'Send All Entities';
                ApplicationArea = All;

                trigger OnAction()
                begin
                    IntegrationCRM.PostAllEntities();
                    Message(lblProcessCompleted);
                end;
            }
        }
    }

    var
        IntegrationCRM: Codeunit "Integration CRM";
        lblProcessCompleted: Label 'Process Completed';
}