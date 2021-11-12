page 50075 "Payment CRM"
{
    PageType = List;
    ApplicationArea = All;
    UsageCategory = Administration;
    SourceTable = "Payment CRM";
    SourceTableView = sorting("Create Date Time") order(descending);
    // Editable = false;
    CaptionML = ENU = 'Payment CRM',
                RUS = 'Платежи CRM';

    layout
    {
        area(Content)
        {
            repeater(PaymentCRM)
            {
                field(Apply; Rec.Apply)
                {
                    ApplicationArea = All;
                }
                field("Modify In CRM"; Rec."Modify In CRM")
                {
                    ApplicationArea = All;
                }
                field("No. of Attempts to Run"; Rec."No. of Attempts to Run")
                {
                    ApplicationArea = All;
                }
                field("Payment No."; Rec."Payment No.")
                {
                    ApplicationArea = All;
                }
                field(Amount; Rec.Amount)
                {
                    ApplicationArea = All;
                }
                field("Invoice Date"; Rec."Invoice Date")
                {
                    ApplicationArea = All;
                }
                field("Payment Date"; Rec."Payment Date")
                {
                    ApplicationArea = All;
                }
                field("Id CRM"; Rec."Id CRM")
                {
                    ApplicationArea = All;
                }
                field("Id BC"; Rec."Id BC")
                {
                    ApplicationArea = All;
                }
                field("Create User Name"; Rec."Create User ID")
                {
                    ApplicationArea = All;
                }
                field("Create Date Time"; Rec."Create Date Time")
                {
                    ApplicationArea = All;
                }
                field("Modify User Name"; Rec."Modify User ID")
                {
                    ApplicationArea = All;
                }
                field("Modify Date Time"; Rec."Modify Date Time")
                {
                    ApplicationArea = All;
                }
                field("Invoice Entry No."; Rec."Invoice Entry No.")
                {
                    ApplicationArea = All;
                }
                field("Payment Entry No."; Rec."Payment Entry No.")
                {
                    ApplicationArea = All;
                }
                field("Invoice No."; Rec."Invoice No.")
                {
                    ApplicationArea = All;
                }
            }
        }
    }
}